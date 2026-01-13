"""
Cache Invalidation Signals

Automatically invalidates cache when models are created, updated, or deleted.
"""

import logging
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.contrib.auth import get_user_model
from apps.users.models import UserProfile
from apps.errands.models import Errand
from apps.escrow.models import Escrow
from core.cache_utils import invalidate_user_cache, invalidate_cache_pattern

User = get_user_model()
logger = logging.getLogger(__name__)


@receiver(post_save, sender=User)
@receiver(post_delete, sender=User)
def invalidate_user_cache_signal(sender, instance, **kwargs):
    """Invalidate cache when user is saved or deleted."""
    try:
        invalidate_user_cache(instance.id)
        logger.debug(f"Invalidated cache for user {instance.id}")
    except Exception as e:
        logger.warning(f"Error invalidating user cache: {e}")


@receiver(post_save, sender=UserProfile)
@receiver(post_delete, sender=UserProfile)
def invalidate_user_profile_cache_signal(sender, instance, **kwargs):
    """Invalidate cache when user profile is saved or deleted."""
    try:
        if hasattr(instance, 'user') and instance.user:
            invalidate_user_cache(instance.user.id)
            # Also invalidate profile-specific cache
            invalidate_cache_pattern(f"user_profile:{instance.user.id}*")
            logger.debug(f"Invalidated cache for user profile {instance.user.id}")
    except Exception as e:
        logger.warning(f"Error invalidating user profile cache: {e}")


@receiver(post_save, sender=Errand)
@receiver(post_delete, sender=Errand)
def invalidate_errand_cache_signal(sender, instance, **kwargs):
    """Invalidate cache when errand is saved or deleted."""
    try:
        # Invalidate errand-specific cache
        invalidate_cache_pattern(f"errand:{instance.id}*")
        invalidate_cache_pattern(f"errand_detail:{instance.id}*")
        
        # Invalidate user's errands cache
        if hasattr(instance, 'user') and instance.user:
            invalidate_cache_pattern(f"user_errands:{instance.user.id}*")
        
        # Invalidate runner's errands cache
        if hasattr(instance, 'runner') and instance.runner:
            invalidate_cache_pattern(f"user_errands:{instance.runner.id}*")
        
        # Invalidate errand list cache
        invalidate_cache_pattern("errand_list:*")
        
        logger.debug(f"Invalidated cache for errand {instance.id}")
    except Exception as e:
        logger.warning(f"Error invalidating errand cache: {e}")


@receiver(post_save, sender=Escrow)
@receiver(post_delete, sender=Escrow)
def invalidate_escrow_cache_signal(sender, instance, **kwargs):
    """Invalidate cache when escrow is saved or deleted."""
    try:
        # Invalidate escrow-specific cache
        invalidate_cache_pattern(f"escrow:{instance.id}*")
        
        # Invalidate buyer's escrows cache
        if hasattr(instance, 'buyer') and instance.buyer:
            invalidate_cache_pattern(f"user_escrows:{instance.buyer.id}*")
        
        # Invalidate runner's escrows cache
        if hasattr(instance, 'runner') and instance.runner:
            invalidate_cache_pattern(f"user_escrows:{instance.runner.id}*")
        
        # Invalidate errand's escrow cache
        if hasattr(instance, 'errand') and instance.errand:
            invalidate_cache_pattern(f"errand:{instance.errand.id}:escrow*")
        
        logger.debug(f"Invalidated cache for escrow {instance.id}")
    except Exception as e:
        logger.warning(f"Error invalidating escrow cache: {e}")
