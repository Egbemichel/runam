"""
Cache Utilities

Provides helper functions and decorators for caching throughout the application.
"""

import hashlib
import json
import logging
from functools import wraps
from typing import Any, Callable, Optional
from django.core.cache import cache
from django.conf import settings

logger = logging.getLogger(__name__)


def get_cache_key(prefix: str, *args, **kwargs) -> str:
    """
    Generate a cache key from prefix and arguments.
    
    Args:
        prefix: Cache key prefix
        *args: Positional arguments to include in key
        **kwargs: Keyword arguments to include in key
    
    Returns:
        str: Cache key
    """
    # Create a hash of arguments
    key_parts = [prefix]
    
    if args:
        key_parts.append(str(hash(tuple(args))))
    
    if kwargs:
        # Sort kwargs for consistent hashing
        sorted_kwargs = sorted(kwargs.items())
        key_parts.append(str(hash(tuple(sorted_kwargs))))
    
    key_string = ':'.join(key_parts)
    # Create MD5 hash if key is too long
    if len(key_string) > 200:
        key_string = hashlib.md5(key_string.encode()).hexdigest()
        key_parts = [prefix, key_string]
        key_string = ':'.join(key_parts)
    
    return key_string


def cache_result(
    timeout: int = 300,
    key_prefix: Optional[str] = None,
    key_func: Optional[Callable] = None,
    version: Optional[int] = None
):
    """
    Decorator to cache function results.
    
    Args:
        timeout: Cache timeout in seconds (default: 300 = 5 minutes)
        key_prefix: Prefix for cache key (default: function name)
        key_func: Custom function to generate cache key from args/kwargs
        version: Cache version (for invalidation)
    
    Usage:
        @cache_result(timeout=600, key_prefix='user_profile')
        def get_user_profile(user_id):
            return UserProfile.objects.get(user_id=user_id)
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Generate cache key
            if key_func:
                cache_key = key_func(*args, **kwargs)
            else:
                prefix = key_prefix or f"{func.__module__}.{func.__name__}"
                cache_key = get_cache_key(prefix, *args, **kwargs)
            
            if version:
                cache_key = f"{cache_key}:v{version}"
            
            # Try to get from cache
            try:
                cached_value = cache.get(cache_key)
                if cached_value is not None:
                    logger.debug(f"Cache hit: {cache_key}")
                    return cached_value
                
                logger.debug(f"Cache miss: {cache_key}")
            except Exception as e:
                logger.warning(f"Cache get error for {cache_key}: {e}")
                cached_value = None
            
            # Execute function
            result = func(*args, **kwargs)
            
            # Store in cache
            try:
                cache.set(cache_key, result, timeout)
                logger.debug(f"Cached result: {cache_key} (timeout={timeout}s)")
            except Exception as e:
                logger.warning(f"Cache set error for {cache_key}: {e}")
            
            return result
        
        # Add cache invalidation method
        def invalidate(*args, **kwargs):
            """Invalidate cache for this function with given arguments."""
            if key_func:
                cache_key = key_func(*args, **kwargs)
            else:
                prefix = key_prefix or f"{func.__module__}.{func.__name__}"
                cache_key = get_cache_key(prefix, *args, **kwargs)
            
            if version:
                cache_key = f"{cache_key}:v{version}"
            
            cache.delete(cache_key)
            logger.info(f"Cache invalidated: {cache_key}")
        
        wrapper.invalidate = invalidate
        wrapper.cache_key = lambda *a, **kw: get_cache_key(
            key_prefix or f"{func.__module__}.{func.__name__}", *a, **kw
        )
        
        return wrapper
    return decorator


def invalidate_cache_pattern(pattern: str):
    """
    Invalidate all cache keys matching a pattern.
    
    Note: This requires Redis or a cache backend that supports pattern matching.
    For local memory cache, this will not work.
    
    Args:
        pattern: Cache key pattern (e.g., 'user:*')
    """
    try:
        # Try to use cache's delete_pattern if available (Redis)
        if hasattr(cache, 'delete_pattern'):
            cache.delete_pattern(pattern)
            logger.info(f"Invalidated cache pattern: {pattern}")
        else:
            logger.warning(f"Cache backend does not support pattern deletion: {pattern}")
    except Exception as e:
        logger.error(f"Error invalidating cache pattern {pattern}: {e}", exc_info=True)


def cache_user_data(user_id: int, data: Any, timeout: int = 3600):
    """
    Cache user-specific data.
    
    Args:
        user_id: User ID
        data: Data to cache
        timeout: Cache timeout in seconds (default: 1 hour)
    """
    cache_key = f"user:{user_id}:data"
    try:
        cache.set(cache_key, data, timeout)
    except Exception as e:
        logger.warning(f"Error caching user data for user {user_id}: {e}")


def get_cached_user_data(user_id: int) -> Optional[Any]:
    """
    Get cached user-specific data.
    
    Args:
        user_id: User ID
    
    Returns:
        Cached data or None
    """
    cache_key = f"user:{user_id}:data"
    try:
        return cache.get(cache_key)
    except Exception as e:
        logger.warning(f"Error getting cached user data for user {user_id}: {e}")
        return None


def invalidate_user_cache(user_id: int):
    """
    Invalidate all cache entries for a user.
    
    Args:
        user_id: User ID
    """
    patterns = [
        f"user:{user_id}:*",
        f"user_profile:{user_id}",
        f"user_errands:{user_id}",
        f"user_escrows:{user_id}",
    ]
    
    for pattern in patterns:
        invalidate_cache_pattern(pattern)
    
    logger.info(f"Invalidated cache for user {user_id}")


def cache_queryset(queryset, timeout: int = 300, key_prefix: str = 'queryset'):
    """
    Cache a queryset result.
    
    Args:
        queryset: Django queryset
        timeout: Cache timeout in seconds
        key_prefix: Cache key prefix
    
    Returns:
        Cached queryset or None
    """
    # Generate cache key from queryset
    cache_key = get_cache_key(key_prefix, str(queryset.query))
    
    try:
        cached = cache.get(cache_key)
        if cached is not None:
            return cached
        
        # Evaluate queryset and cache
        result = list(queryset)
        cache.set(cache_key, result, timeout)
        return result
    except Exception as e:
        logger.warning(f"Error caching queryset: {e}")
        return list(queryset)


class CacheManager:
    """Centralized cache management."""
    
    @staticmethod
    def clear_all():
        """Clear all cache (use with caution)."""
        try:
            cache.clear()
            logger.info("All cache cleared")
        except Exception as e:
            logger.error(f"Error clearing cache: {e}", exc_info=True)
    
    @staticmethod
    def get_stats():
        """Get cache statistics (if supported by backend)."""
        try:
            if hasattr(cache, 'get_stats'):
                return cache.get_stats()
            return {"backend": cache.__class__.__name__, "stats_available": False}
        except Exception as e:
            logger.warning(f"Error getting cache stats: {e}")
            return {"error": str(e)}
    
    @staticmethod
    def warm_up():
        """Warm up cache with common queries."""
        logger.info("Warming up cache...")
        # This can be customized based on your needs
        # Example: pre-load frequently accessed data
        pass
