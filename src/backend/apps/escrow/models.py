from django.contrib.auth import get_user_model
from django.db import models
from django.utils import timezone
from decimal import Decimal

User = get_user_model()


class Escrow(models.Model):
    """Escrow model to hold funds for errands until completion"""
    
    class Status(models.TextChoices):
        PENDING = "PENDING"  # Funds held, errand in progress
        RELEASED = "RELEASED"  # Funds released to runner
        REFUNDED = "REFUNDED"  # Funds refunded to buyer
        CANCELLED = "CANCELLED"  # Escrow cancelled
    
    errand = models.OneToOneField(
        'errands.Errand',
        on_delete=models.CASCADE,
        related_name='escrow'
    )
    buyer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='escrows_as_buyer'
    )
    runner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='escrows_as_runner',
        null=True,
        blank=True
    )
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Amount held in escrow"
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    released_at = models.DateTimeField(null=True, blank=True)
    refunded_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Transaction reference (for payment gateway integration)
    transaction_id = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="External payment transaction ID"
    )
    
    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['buyer', 'status']),
            models.Index(fields=['runner', 'status']),
            models.Index(fields=['errand']),
        ]
    
    def __str__(self):
        return f"Escrow #{self.id} - {self.errand.id} - {self.status} - ${self.amount}"
    
    def can_release(self):
        """Check if escrow can be released"""
        return self.status == self.Status.PENDING and self.runner is not None
    
    def can_refund(self):
        """Check if escrow can be refunded"""
        return self.status == self.Status.PENDING
    
    def can_cancel(self):
        """Check if escrow can be cancelled"""
        return self.status == self.Status.PENDING
    
    def release(self, transaction_id=None):
        """
        Release funds to runner.
        
        Args:
            transaction_id: Optional external transaction ID from payment gateway
        
        Raises:
            ValueError: If escrow cannot be released
        """
        if not self.can_release():
            raise ValueError(
                f"Cannot release escrow with status {self.status}. "
                f"Escrow must be PENDING and have a runner assigned."
            )
        
        self.status = self.Status.RELEASED
        self.released_at = timezone.now()
        if transaction_id:
            self.transaction_id = transaction_id
        self.save(update_fields=['status', 'released_at', 'transaction_id', 'updated_at'])
    
    def refund(self, transaction_id=None):
        """
        Refund funds to buyer.
        
        Args:
            transaction_id: Optional external transaction ID from payment gateway
        
        Raises:
            ValueError: If escrow cannot be refunded
        """
        if not self.can_refund():
            raise ValueError(
                f"Cannot refund escrow with status {self.status}. "
                f"Only PENDING escrows can be refunded."
            )
        
        self.status = self.Status.REFUNDED
        self.refunded_at = timezone.now()
        if transaction_id:
            self.transaction_id = transaction_id
        self.save(update_fields=['status', 'refunded_at', 'transaction_id', 'updated_at'])
    
    def cancel(self):
        """
        Cancel escrow (marks as cancelled without refunding).
        Use refund() if you want to refund funds to buyer.
        
        Raises:
            ValueError: If escrow cannot be cancelled
        """
        if not self.can_cancel():
            raise ValueError(
                f"Cannot cancel escrow with status {self.status}. "
                f"Only PENDING escrows can be cancelled."
            )
        
        self.status = self.Status.CANCELLED
        self.save(update_fields=['status', 'updated_at'])
