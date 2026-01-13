"""
GraphQL-specific Rate Limiting

Provides granular rate limiting for GraphQL operations based on operation type and name.
"""

import time
import hashlib
import json
import logging
from django.core.cache import cache
from django.conf import settings

logger = logging.getLogger(__name__)


class GraphQLRateLimiter:
    """
    Rate limiter for GraphQL operations.
    
    Allows different rate limits for:
    - Queries vs Mutations
    - Specific operation names (e.g., 'createErrand', 'initializePayment')
    - Authenticated vs anonymous users
    """
    
    def __init__(self):
        self.enabled = getattr(settings, 'RATE_LIMIT_ENABLED', True)
        self.cache_prefix = getattr(settings, 'RATE_LIMIT_CACHE_PREFIX', 'ratelimit')
        
        # Default rate limits
        self.default_query_limit = self._parse_rate_limit(
            getattr(settings, 'RATE_LIMIT_GRAPHQL_QUERY', '300/h')
        )
        self.default_mutation_limit = self._parse_rate_limit(
            getattr(settings, 'RATE_LIMIT_GRAPHQL_MUTATION', '50/h')
        )
        
        # Operation-specific limits
        self.operation_limits = getattr(settings, 'RATE_LIMIT_GRAPHQL_OPERATIONS', {})
    
    def _parse_rate_limit(self, rate_str):
        """Parse rate limit string (e.g., '100/h', '10/m')."""
        try:
            parts = rate_str.split('/')
            if len(parts) != 2:
                raise ValueError("Invalid rate limit format")
            
            max_requests = int(parts[0])
            period = parts[1].lower()
            
            period_map = {
                's': 1,
                'm': 60,
                'h': 3600,
                'd': 86400,
            }
            
            if period not in period_map:
                raise ValueError(f"Invalid period: {period}")
            
            period_seconds = period_map[period]
            return (max_requests, period_seconds)
        except (ValueError, IndexError) as e:
            logger.warning(f"Invalid rate limit format '{rate_str}': {e}")
            return (50, 3600)  # Default: 50 requests per hour
    
    def _get_operation_limit(self, operation_name, operation_type):
        """
        Get rate limit for a specific operation.
        
        Args:
            operation_name: Name of the GraphQL operation
            operation_type: 'query' or 'mutation'
        
        Returns:
            tuple: (max_requests, period_seconds)
        """
        # Check for operation-specific limit
        if operation_name in self.operation_limits:
            return self._parse_rate_limit(self.operation_limits[operation_name])
        
        # Use default based on operation type
        if operation_type == 'mutation':
            return self.default_mutation_limit
        else:
            return self.default_query_limit
    
    def _get_cache_key(self, user_id, operation_name, operation_type):
        """Generate cache key for GraphQL operation."""
        identifier = f"user:{user_id}" if user_id else "anonymous"
        return f"{self.cache_prefix}:graphql:{identifier}:{operation_type}:{operation_name}"
    
    def check_rate_limit(self, request, operation_name, operation_type):
        """
        Check if GraphQL operation should be rate limited.
        
        Args:
            request: Django request object
            operation_name: Name of the GraphQL operation
            operation_type: 'query' or 'mutation'
        
        Returns:
            tuple: (is_limited, remaining_requests, reset_time, error_message)
        """
        if not self.enabled:
            return (False, None, None, None)
        
        # Get user ID
        user_id = None
        if hasattr(request, 'user') and request.user.is_authenticated:
            user_id = request.user.id
        
        # Get rate limit for this operation
        max_requests, period_seconds = self._get_operation_limit(operation_name, operation_type)
        
        # Get cache key
        cache_key = self._get_cache_key(user_id, operation_name, operation_type)
        
        # Get current count
        current_count = cache.get(cache_key, 0)
        
        # Check if limit exceeded
        if current_count >= max_requests:
            reset_time = cache.get(f"{cache_key}:reset", time.time() + period_seconds)
            error_message = (
                f"Rate limit exceeded for {operation_type} '{operation_name}'. "
                f"Limit: {max_requests} requests per {period_seconds}s. "
                f"Try again after {int(reset_time - time.time())} seconds."
            )
            return (True, 0, reset_time, error_message)
        
        # Increment counter
        new_count = current_count + 1
        cache.set(cache_key, new_count, period_seconds)
        
        # Set reset time if not exists
        reset_key = f"{cache_key}:reset"
        if not cache.get(reset_key):
            cache.set(reset_key, time.time() + period_seconds, period_seconds)
        
        remaining = max(0, max_requests - new_count)
        reset_time = cache.get(reset_key, time.time() + period_seconds)
        
        return (False, remaining, reset_time, None)


# Singleton instance
graphql_rate_limiter = GraphQLRateLimiter()
