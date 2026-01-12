from django.contrib.auth import get_user_model
from django.db import transaction
from decimal import Decimal
import logging
from apps.escrow.models import Escrow
from apps.errands.models import Errand

User = get_user_model()
logger = logging.getLogger(__name__)


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
    
    # TODO: Integrate with payment gateway to actually hold funds
    # For now, this is a placeholder for the escrow logic
    
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
    
    escrow.release(transaction_id=transaction_id)
    
    logger.info(f"Released escrow {escrow.id} for errand {errand.id} to runner {escrow.runner.id}")
    
    # TODO: Integrate with payment gateway to actually transfer funds to runner
    # Example: payment_gateway.transfer(escrow.amount, escrow.runner.payment_account)
    
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
    
    escrow.refund(transaction_id=transaction_id)
    
    logger.info(f"Refunded escrow {escrow.id} for errand {errand.id} to buyer {escrow.buyer.id}")
    
    # TODO: Integrate with payment gateway to actually refund funds to buyer
    # Example: payment_gateway.refund(escrow.amount, escrow.buyer.payment_account, escrow.transaction_id)
    
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
