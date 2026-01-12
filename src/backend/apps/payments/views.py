"""
Flutterwave Webhook Handler

Handles payment callbacks from Flutterwave to update escrow status automatically.
"""

import json
import hmac
import hashlib
import logging
from django.http import HttpResponse, HttpResponseBadRequest, HttpResponseForbidden
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django.conf import settings
from apps.escrow.models import Escrow

logger = logging.getLogger(__name__)


def verify_flutterwave_signature(payload, signature):
    """
    Verify Flutterwave webhook signature.
    
    Args:
        payload: Raw request body
        signature: X-Flutterwave-Signature header value
    
    Returns:
        bool: True if signature is valid
    """
    secret_hash = getattr(settings, 'FLUTTERWAVE_SECRET_HASH', '')
    if not secret_hash:
        logger.warning("FLUTTERWAVE_SECRET_HASH not configured. Skipping signature verification.")
        return True  # Allow if not configured (for testing)
    
    expected_signature = hmac.new(
        secret_hash.encode('utf-8'),
        payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected_signature, signature)


@csrf_exempt
@require_POST
def flutterwave_webhook(request):
    """
    Handle Flutterwave webhook callbacks for payment events.
    
    Expected events:
    - charge.completed: Payment completed
    - transfer.completed: Transfer completed
    - transfer.reversed: Transfer reversed
    """
    try:
        # Get signature from header
        signature = request.headers.get('X-Flutterwave-Signature', '')
        
        # Get raw payload
        payload = request.body.decode('utf-8')
        
        # Verify signature
        if not verify_flutterwave_signature(payload, signature):
            logger.warning("Invalid Flutterwave webhook signature")
            return HttpResponseForbidden("Invalid signature")
        
        # Parse JSON payload
        data = json.loads(payload)
        event_type = data.get('event')
        event_data = data.get('data', {})
        
        logger.info(f"Received Flutterwave webhook: event={event_type}, data={event_data}")
        
        # Handle different event types
        if event_type == 'charge.completed':
            # Payment completed
            transaction_id = event_data.get('id')
            tx_ref = event_data.get('tx_ref')
            status = event_data.get('status')
            
            if status == 'successful':
                # Find escrow by transaction reference
                try:
                    # Extract escrow ID from tx_ref (format: ESCROW_{id}_{hash})
                    if tx_ref and tx_ref.startswith('ESCROW_'):
                        escrow_id = tx_ref.split('_')[1]
                        escrow = Escrow.objects.get(pk=escrow_id)
                        
                        # Update escrow transaction ID if not set
                        if not escrow.transaction_id:
                            escrow.transaction_id = str(transaction_id)
                            escrow.save(update_fields=['transaction_id'])
                        
                        logger.info(f"Payment confirmed for escrow {escrow.id}: transaction_id={transaction_id}")
                    else:
                        logger.warning(f"Could not extract escrow ID from tx_ref: {tx_ref}")
                except Escrow.DoesNotExist:
                    logger.warning(f"Escrow not found for transaction: {transaction_id}")
                except Exception as e:
                    logger.error(f"Error processing payment webhook: {e}", exc_info=True)
        
        elif event_type == 'transfer.completed':
            # Transfer completed
            transfer_id = event_data.get('id')
            status = event_data.get('status')
            
            if status == 'SUCCESSFUL':
                logger.info(f"Transfer completed successfully: transfer_id={transfer_id}")
            elif status == 'FAILED':
                logger.warning(f"Transfer failed: transfer_id={transfer_id}, reason={event_data.get('complete_message')}")
        
        elif event_type == 'transfer.reversed':
            # Transfer reversed
            transfer_id = event_data.get('id')
            logger.info(f"Transfer reversed: transfer_id={transfer_id}")
        
        # Return success response
        return HttpResponse(json.dumps({'status': 'success'}), content_type='application/json')
        
    except json.JSONDecodeError:
        logger.error("Invalid JSON in Flutterwave webhook payload")
        return HttpResponseBadRequest("Invalid JSON")
    except Exception as e:
        logger.error(f"Error processing Flutterwave webhook: {e}", exc_info=True)
        return HttpResponseBadRequest(f"Error: {str(e)}")
