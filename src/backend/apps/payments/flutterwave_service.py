"""
Flutterwave Payment Gateway Service

This module handles all Flutterwave payment operations including:
- Payment initialization
- Payment verification
- Transfer to recipients (runners)
- Refunds
"""

import requests
import logging
import time
from decimal import Decimal
from typing import Dict, Optional, Any
from django.conf import settings
from django.contrib.auth import get_user_model

User = get_user_model()
logger = logging.getLogger(__name__)


class FlutterwaveService:
    """Service for interacting with Flutterwave API"""
    
    BASE_URL = "https://api.flutterwave.com/v3"
    
    def __init__(self):
        self.secret_key = getattr(settings, 'FLUTTERWAVE_SECRET_KEY', '')
        self.public_key = getattr(settings, 'FLUTTERWAVE_PUBLIC_KEY', '')
        self.encryption_key = getattr(settings, 'FLUTTERWAVE_ENCRYPTION_KEY', '')
        self.currency = getattr(settings, 'FLUTTERWAVE_CURRENCY', 'NGN')
        self.is_test_mode = getattr(settings, 'FLUTTERWAVE_TEST_MODE', True)
        
        if not self.secret_key:
            logger.warning("Flutterwave secret key not configured. Payment operations will fail.")
    
    def _get_headers(self) -> Dict[str, str]:
        """Get headers for Flutterwave API requests"""
        return {
            'Authorization': f'Bearer {self.secret_key}',
            'Content-Type': 'application/json'
        }
    
    def initialize_payment(
        self,
        amount: Decimal,
        email: str,
        tx_ref: str,
        customer_name: str = None,
        phone_number: str = None,
        redirect_url: str = None,
        meta: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Initialize a payment transaction with Flutterwave.
        
        Args:
            amount: Payment amount
            email: Customer email
            tx_ref: Unique transaction reference
            customer_name: Customer name (optional)
            phone_number: Customer phone number (optional)
            redirect_url: URL to redirect after payment (optional)
            meta: Additional metadata (optional)
        
        Returns:
            Dict containing payment link and transaction details
        
        Raises:
            Exception: If payment initialization fails
        """
        if not self.secret_key:
            raise ValueError("Flutterwave secret key not configured")
        
        url = f"{self.BASE_URL}/payments"
        
        payload = {
            "tx_ref": tx_ref,
            "amount": str(float(amount)),
            "currency": self.currency,
            "payment_options": "card,account,ussd,mpesa,mobilemoney,credit",
            "redirect_url": redirect_url or f"{getattr(settings, 'FRONTEND_URL', 'http://localhost:3000')}/payment/callback",
            "customer": {
                "email": email,
                "name": customer_name or email.split('@')[0],
                "phone_number": phone_number or "",
            },
            "customizations": {
                "title": "RunAm Errand Payment",
                "description": f"Payment for errand transaction {tx_ref}",
                "logo": getattr(settings, 'FLUTTERWAVE_LOGO_URL', '')
            }
        }
        
        if meta:
            payload["meta"] = meta
        
        try:
            response = requests.post(url, json=payload, headers=self._get_headers(), timeout=30)
            response.raise_for_status()
            data = response.json()
            
            if data.get('status') == 'success':
                logger.info(f"Payment initialized successfully: tx_ref={tx_ref}, amount={amount}")
                return {
                    'status': 'success',
                    'payment_link': data['data']['link'],
                    'tx_ref': tx_ref,
                    'transaction_id': data['data'].get('id'),
                    'amount': amount,
                    'currency': self.currency
                }
            else:
                error_msg = data.get('message', 'Payment initialization failed')
                logger.error(f"Flutterwave payment initialization failed: {error_msg}")
                raise Exception(f"Payment initialization failed: {error_msg}")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Flutterwave API request failed: {e}", exc_info=True)
            raise Exception(f"Failed to initialize payment: {str(e)}")
    
    def verify_payment(self, transaction_id: str) -> Dict[str, Any]:
        """
        Verify a payment transaction.
        
        Args:
            transaction_id: Flutterwave transaction ID
        
        Returns:
            Dict containing payment verification details
        
        Raises:
            Exception: If payment verification fails
        """
        if not self.secret_key:
            raise ValueError("Flutterwave secret key not configured")
        
        url = f"{self.BASE_URL}/transactions/{transaction_id}/verify"
        
        try:
            response = requests.get(url, headers=self._get_headers(), timeout=30)
            response.raise_for_status()
            data = response.json()
            
            if data.get('status') == 'success':
                transaction_data = data['data']
                logger.info(f"Payment verified: transaction_id={transaction_id}, status={transaction_data.get('status')}")
                return {
                    'status': 'success',
                    'transaction_id': transaction_id,
                    'tx_ref': transaction_data.get('tx_ref'),
                    'amount': Decimal(str(transaction_data.get('amount', 0))),
                    'currency': transaction_data.get('currency'),
                    'payment_status': transaction_data.get('status'),
                    'customer': transaction_data.get('customer'),
                    'created_at': transaction_data.get('created_at')
                }
            else:
                error_msg = data.get('message', 'Payment verification failed')
                logger.error(f"Flutterwave payment verification failed: {error_msg}")
                raise Exception(f"Payment verification failed: {error_msg}")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Flutterwave API request failed: {e}", exc_info=True)
            raise Exception(f"Failed to verify payment: {str(e)}")
    
    def transfer_funds(
        self,
        amount: Decimal,
        recipient_account_number: str,
        recipient_bank_code: str,
        recipient_name: str,
        narration: str = None,
        reference: str = None
    ) -> Dict[str, Any]:
        """
        Transfer funds to a recipient (runner) account.
        
        Args:
            amount: Amount to transfer
            recipient_account_number: Recipient account number
            recipient_bank_code: Recipient bank code (Flutterwave bank code)
            recipient_name: Recipient account name
            narration: Transfer narration (optional)
            reference: Unique transfer reference (optional)
        
        Returns:
            Dict containing transfer details
        
        Raises:
            Exception: If transfer fails
        """
        if not self.secret_key:
            raise ValueError("Flutterwave secret key not configured")
        
        url = f"{self.BASE_URL}/transfers"
        
        payload = {
            "account_bank": recipient_bank_code,
            "account_number": recipient_account_number,
            "amount": float(amount),
            "narration": narration or f"Payment for errand completion",
            "currency": self.currency,
            "reference": reference or f"TRF_{int(time.time())}",
            "beneficiary_name": recipient_name
        }
        
        try:
            response = requests.post(url, json=payload, headers=self._get_headers(), timeout=30)
            response.raise_for_status()
            data = response.json()
            
            if data.get('status') == 'success':
                transfer_data = data['data']
                logger.info(f"Funds transferred successfully: reference={reference}, amount={amount}")
                return {
                    'status': 'success',
                    'transfer_id': transfer_data.get('id'),
                    'reference': reference,
                    'amount': amount,
                    'currency': self.currency,
                    'status': transfer_data.get('status'),
                    'created_at': transfer_data.get('created_at')
                }
            else:
                error_msg = data.get('message', 'Transfer failed')
                logger.error(f"Flutterwave transfer failed: {error_msg}")
                raise Exception(f"Transfer failed: {error_msg}")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Flutterwave API request failed: {e}", exc_info=True)
            raise Exception(f"Failed to transfer funds: {str(e)}")
    
    def refund_payment(
        self,
        transaction_id: str,
        amount: Decimal = None,
        comments: str = None
    ) -> Dict[str, Any]:
        """
        Refund a payment transaction.
        
        Args:
            transaction_id: Original Flutterwave transaction ID
            amount: Partial refund amount (optional, defaults to full refund)
            comments: Refund reason/comments (optional)
        
        Returns:
            Dict containing refund details
        
        Raises:
            Exception: If refund fails
        """
        if not self.secret_key:
            raise ValueError("Flutterwave secret key not configured")
        
        url = f"{self.BASE_URL}/transactions/{transaction_id}/refund"
        
        payload = {}
        if amount:
            payload['amount'] = float(amount)
        if comments:
            payload['comments'] = comments
        
        try:
            response = requests.post(url, json=payload, headers=self._get_headers(), timeout=30)
            response.raise_for_status()
            data = response.json()
            
            if data.get('status') == 'success':
                refund_data = data['data']
                logger.info(f"Refund processed successfully: transaction_id={transaction_id}, amount={amount}")
                return {
                    'status': 'success',
                    'refund_id': refund_data.get('id'),
                    'transaction_id': transaction_id,
                    'amount': Decimal(str(refund_data.get('amount', amount or 0))),
                    'currency': refund_data.get('currency', self.currency),
                    'status': refund_data.get('status'),
                    'created_at': refund_data.get('created_at')
                }
            else:
                error_msg = data.get('message', 'Refund failed')
                logger.error(f"Flutterwave refund failed: {error_msg}")
                raise Exception(f"Refund failed: {error_msg}")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Flutterwave API request failed: {e}", exc_info=True)
            raise Exception(f"Failed to process refund: {str(e)}")
    
    def get_banks(self, country: str = 'NG') -> Dict[str, Any]:
        """
        Get list of banks for a country (useful for transfers).
        
        Args:
            country: Country code (default: NG for Nigeria)
        
        Returns:
            Dict containing list of banks
        """
        if not self.secret_key:
            raise ValueError("Flutterwave secret key not configured")
        
        url = f"{self.BASE_URL}/banks/{country}"
        
        try:
            response = requests.get(url, headers=self._get_headers(), timeout=30)
            response.raise_for_status()
            data = response.json()
            
            if data.get('status') == 'success':
                return {
                    'status': 'success',
                    'banks': data['data']
                }
            else:
                raise Exception("Failed to fetch banks")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Flutterwave API request failed: {e}", exc_info=True)
            raise Exception(f"Failed to fetch banks: {str(e)}")


# Singleton instance
flutterwave_service = FlutterwaveService()
