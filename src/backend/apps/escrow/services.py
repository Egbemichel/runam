from django.contrib.auth import get_user_model
from django.db import transaction
from decimal import Decimal
import logging
import uuid
from apps.escrow.models import Escrow
from apps.errands.models import Errand

User = get_user_model()
logger = logging.getLogger(__name__)

# Import Flutterwave service
try:
    from apps.payments.flutterwave_service import flutterwave_service
    FLUTTERWAVE_AVAILABLE = True
except ImportError:
    logger.warning("Flutterwave service not available. Payment operations will be skipped.")
    FLUTTERWAVE_AVAILABLE = False
    flutterwave_service = None


@transaction.atomic
def create_escrow(errand: Errand, amount: Decimal, runner: User = None) -> Escrow:
    """
    Create an escrow for an errand.
    
    Args:
        errand: The errand instance
        amount: The amount to hold in escrow
        runner: Optional runner who accepted the errand
    
    Returns:
        Escrow instance
    
    Raises:
        ValueError: If escrow cannot be created (invalid amount, already exists, etc.)
    """
    if amount <= 0:
        raise ValueError("Escrow amount must be greater than 0")
    
    # Validate errand state
    if errand.status != Errand.Status.IN_PROGRESS:
        raise ValueError(f"Cannot create escrow for errand with status {errand.status}. Errand must be IN_PROGRESS.")
    
    # Check if escrow already exists
    if Escrow.objects.filter(errand=errand).exists():
        raise ValueError("Escrow already exists for this errand")
    
    # Ensure runner is set if provided
    if runner and errand.runner != runner:
        logger.warning(f"Runner mismatch: provided runner {runner.id} != errand.runner {errand.runner.id if errand.runner else None}")
    
    # Use errand.runner if available, otherwise use provided runner
    final_runner = errand.runner or runner
    
    escrow = Escrow.objects.create(
        errand=errand,
        buyer=errand.user,
        runner=final_runner,
        amount=amount,
        status=Escrow.Status.PENDING
    )
    
    logger.info(f"Created escrow {escrow.id} for errand {errand.id} with amount {amount}")
    
    # Initialize payment with Flutterwave
    if FLUTTERWAVE_AVAILABLE and flutterwave_service:
        try:
            tx_ref = f"ESCROW_{escrow.id}_{uuid.uuid4().hex[:8]}"
            buyer_email = errand.user.email
            buyer_name = getattr(errand.user, 'first_name', '') or buyer_email.split('@')[0]
            
            payment_result = flutterwave_service.initialize_payment(
                amount=amount,
                email=buyer_email,
                tx_ref=tx_ref,
                customer_name=buyer_name,
                meta={
                    'escrow_id': str(escrow.id),
                    'errand_id': str(errand.id),
                    'buyer_id': str(errand.user.id),
                    'runner_id': str(final_runner.id) if final_runner else None
                }
            )
            
            # Store payment transaction reference
            escrow.transaction_id = payment_result.get('transaction_id') or tx_ref
            escrow.save(update_fields=['transaction_id'])
            
            logger.info(f"Payment initialized for escrow {escrow.id}: tx_ref={tx_ref}")
            
        except Exception as e:
            logger.error(f"Failed to initialize Flutterwave payment for escrow {escrow.id}: {e}", exc_info=True)
            # Don't fail escrow creation if payment initialization fails
            # Payment can be initialized later via GraphQL mutation
    
    return escrow


@transaction.atomic
def release_escrow(errand: Errand, transaction_id: str = None) -> Escrow:
    """
    Release escrow funds to the runner when errand is completed.
    
    Args:
        errand: The errand instance
        transaction_id: Optional external transaction ID
    
    Returns:
        Escrow instance
    
    Raises:
        ValueError: If escrow cannot be released (doesn't exist, wrong status, etc.)
    """
    try:
        escrow = errand.escrow
    except Escrow.DoesNotExist:
        raise ValueError("No escrow found for this errand")
    
    if escrow.status != Escrow.Status.PENDING:
        raise ValueError(f"Cannot release escrow with status {escrow.status}. Only PENDING escrows can be released.")
    
    # Validate errand is completed
    if errand.status != Errand.Status.COMPLETED:
        logger.warning(f"Releasing escrow for errand {errand.id} with status {errand.status} (expected COMPLETED)")
    
    # Ensure runner is set
    if not escrow.runner:
        raise ValueError("Cannot release escrow: no runner assigned")
    
    # Transfer funds to runner via Flutterwave (if runner has bank account set up)
    transfer_id = transaction_id
    if FLUTTERWAVE_AVAILABLE and flutterwave_service and escrow.transaction_id and escrow.runner:
        try:
            # Check if runner has bank account details saved
            runner_profile = getattr(escrow.runner, 'profile', None)
            if runner_profile and all([
                runner_profile.bank_account_number,
                runner_profile.bank_code,
                runner_profile.bank_account_name
            ]):
                # Automatically transfer to runner's saved bank account
                transfer_result = flutterwave_service.transfer_funds(
                    amount=escrow.amount,
                    recipient_account_number=runner_profile.bank_account_number,
                    recipient_bank_code=runner_profile.bank_code,
                    recipient_name=runner_profile.bank_account_name,
                    narration=f"Payment for errand {errand.id}",
                    reference=f"TRF_{escrow.id}_{uuid.uuid4().hex[:8]}"
                )
                transfer_id = transfer_result.get('transfer_id')
                logger.info(f"Automatically transferred funds to runner {escrow.runner.id} for escrow {escrow.id}")
            else:
                logger.info(f"Escrow {escrow.id} marked for release. Runner {escrow.runner.id} needs to set up bank account for automatic transfer.")
            
        except Exception as e:
            logger.error(f"Failed to transfer funds via Flutterwave for escrow {escrow.id}: {e}", exc_info=True)
            # Still mark escrow as released - transfer can be retried later via GraphQL mutation
    
    escrow.release(transaction_id=transfer_id)
    
    logger.info(f"Released escrow {escrow.id} for errand {errand.id} to runner {escrow.runner.id}")
    
    return escrow


@transaction.atomic
def refund_escrow(errand: Errand, transaction_id: str = None) -> Escrow:
    """
    Refund escrow funds to the buyer when errand is cancelled or expired.
    
    Args:
        errand: The errand instance
        transaction_id: Optional external transaction ID
    
    Returns:
        Escrow instance or None if no escrow exists
    
    Raises:
        ValueError: If escrow exists but cannot be refunded
    """
    try:
        escrow = errand.escrow
    except Escrow.DoesNotExist:
        # No escrow exists, nothing to refund
        logger.debug(f"No escrow found for errand {errand.id}, skipping refund")
        return None
    
    if escrow.status != Escrow.Status.PENDING:
        # Already processed, log and return existing escrow
        logger.info(f"Escrow {escrow.id} for errand {errand.id} already processed with status {escrow.status}, skipping refund")
        return escrow
    
    # Process refund via Flutterwave
    refund_id = transaction_id
    if FLUTTERWAVE_AVAILABLE and flutterwave_service and escrow.transaction_id:
        try:
            refund_result = flutterwave_service.refund_payment(
                transaction_id=escrow.transaction_id,
                amount=escrow.amount,
                comments=f"Refund for errand {errand.id} - {errand.status}"
            )
            refund_id = refund_result.get('refund_id') or escrow.transaction_id
            logger.info(f"Refund processed via Flutterwave for escrow {escrow.id}: refund_id={refund_id}")
            
        except Exception as e:
            logger.error(f"Failed to process Flutterwave refund for escrow {escrow.id}: {e}", exc_info=True)
            # Still mark escrow as refunded - refund can be retried later
    
    escrow.refund(transaction_id=refund_id)
    
    logger.info(f"Refunded escrow {escrow.id} for errand {errand.id} to buyer {escrow.buyer.id}")
    
    return escrow


def handle_errand_status_change(errand: Errand, old_status: str, new_status: str, runner: User = None):
    """
    Handle escrow logic when errand status changes.
    
    This function automatically manages escrow based on errand status transitions:
    - PENDING -> IN_PROGRESS: Creates escrow if price exists
    - IN_PROGRESS -> COMPLETED: Releases escrow to runner
    - IN_PROGRESS -> CANCELLED/EXPIRED: Refunds escrow to buyer
    
    Args:
        errand: The errand instance
        old_status: Previous status
        new_status: New status
        runner: Optional runner (used when status changes to IN_PROGRESS)
    
    Note:
        Errors are logged but do not raise exceptions to avoid breaking the main operation.
    """
    # When errand is accepted (IN_PROGRESS), create escrow if price exists
    if new_status == Errand.Status.IN_PROGRESS and old_status == Errand.Status.PENDING:
        if hasattr(errand, 'price') and errand.price:
            try:
                # Use errand.runner if available, otherwise use provided runner
                final_runner = errand.runner or runner
                create_escrow(errand, Decimal(str(errand.price)), runner=final_runner)
                logger.info(f"Created escrow for errand {errand.id} when status changed to IN_PROGRESS")
            except ValueError as e:
                # Escrow already exists or invalid amount - log but don't fail
                logger.warning(f"Could not create escrow for errand {errand.id}: {e}")
            except Exception as e:
                logger.error(f"Unexpected error creating escrow for errand {errand.id}: {e}", exc_info=True)
    
    # When errand is completed, release escrow
    elif new_status == Errand.Status.COMPLETED:
        try:
            release_escrow(errand)
            logger.info(f"Released escrow for errand {errand.id} when status changed to COMPLETED")
        except ValueError as e:
            # No escrow exists or cannot be released - log but don't fail
            logger.warning(f"Could not release escrow for errand {errand.id}: {e}")
        except Exception as e:
            logger.error(f"Unexpected error releasing escrow for errand {errand.id}: {e}", exc_info=True)
    
    # When errand is cancelled or expired, refund escrow
    elif new_status in [Errand.Status.CANCELLED, Errand.Status.EXPIRED]:
        try:
            result = refund_escrow(errand)
            if result:
                logger.info(f"Refunded escrow for errand {errand.id} when status changed to {new_status}")
            else:
                logger.debug(f"No escrow to refund for errand {errand.id}")
        except ValueError as e:
            # Escrow cannot be refunded - log but don't fail
            logger.warning(f"Could not refund escrow for errand {errand.id}: {e}")
        except Exception as e:
            logger.error(f"Unexpected error refunding escrow for errand {errand.id}: {e}", exc_info=True)
