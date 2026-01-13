"""
Rate Limiting Middleware

Provides rate limiting for API requests based on IP address and user authentication.
Supports different rate limits for different endpoints and operations.
"""

import time
import hashlib
import logging
from django.core.cache import cache
from django.http import JsonResponse, HttpResponse
from django.utils.deprecation import MiddlewareMixin
from django.conf import settings

logger = logging.getLogger(__name__)


class RateLimitMiddleware(MiddlewareMixin):
    """
    Rate limiting middleware that limits requests per IP/user.
    
    Configuration in settings:
    - RATE_LIMIT_ENABLED: Enable/disable rate limiting (default: True)
    - RATE_LIMIT_CACHE_PREFIX: Cache key prefix (default: 'ratelimit')
    - RATE_LIMIT_DEFAULT: Default rate limit (default: '100/h')
    - RATE_LIMIT_RULES: Dict of path patterns to rate limits
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.enabled = getattr(settings, 'RATE_LIMIT_ENABLED', True)
        self.cache_prefix = getattr(settings, 'RATE_LIMIT_CACHE_PREFIX', 'ratelimit')
        self.default_limit = self._parse_rate_limit(
            getattr(settings, 'RATE_LIMIT_DEFAULT', '100/h')
        )
        self.rules = getattr(settings, 'RATE_LIMIT_RULES', {})
        super().__init__(get_response)
    
    def _parse_rate_limit(self, rate_str):
        """
        Parse rate limit string (e.g., '100/h', '10/m', '1000/d').
        
        Returns:
            tuple: (max_requests, period_seconds)
        """
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
            return (100, 3600)  # Default: 100 requests per hour
    
    def _get_rate_limit_for_path(self, path):
        """
        Get rate limit for a specific path based on rules.
        
        Returns:
            tuple: (max_requests, period_seconds)
        """
        # Check if path matches any rule
        for pattern, rate_limit in self.rules.items():
            if pattern in path or path.startswith(pattern):
                return self._parse_rate_limit(rate_limit)
        
        return self.default_limit
    
    def _get_client_identifier(self, request):
        """
        Get unique identifier for the client (IP address or user ID).
        
        Returns:
            str: Client identifier
        """
        # Use authenticated user ID if available
        if hasattr(request, 'user') and request.user.is_authenticated:
            return f"user:{request.user.id}"
        
        # Fall back to IP address
        # Get real IP from X-Forwarded-For header if behind proxy
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR', 'unknown')
        
        return f"ip:{ip}"
    
    def _get_cache_key(self, identifier, path):
        """
        Generate cache key for rate limiting.
        
        Returns:
            str: Cache key
        """
        # Create a hash of the path to keep keys short
        path_hash = hashlib.md5(path.encode()).hexdigest()[:8]
        return f"{self.cache_prefix}:{identifier}:{path_hash}"
    
    def _is_rate_limited(self, request):
        """
        Check if request should be rate limited.
        
        Returns:
            tuple: (is_limited, remaining_requests, reset_time)
        """
        if not self.enabled:
            return (False, None, None)
        
        # Skip rate limiting for admin and static files
        path = request.path
        if path.startswith('/admin/') or path.startswith('/static/') or path.startswith('/media/'):
            return (False, None, None)
        
        # Get rate limit for this path
        max_requests, period_seconds = self._get_rate_limit_for_path(path)
        
        # Get client identifier
        identifier = self._get_client_identifier(request)
        
        # Get cache key
        cache_key = self._get_cache_key(identifier, path)
        
        # Get current count from cache
        current_count = cache.get(cache_key, 0)
        
        # Check if limit exceeded
        if current_count >= max_requests:
            # Calculate reset time
            reset_time = cache.get(f"{cache_key}:reset", time.time() + period_seconds)
            return (True, 0, reset_time)
        
        # Increment counter
        new_count = current_count + 1
        cache.set(cache_key, new_count, period_seconds)
        
        # Set reset time if not exists
        reset_key = f"{cache_key}:reset"
        if not cache.get(reset_key):
            cache.set(reset_key, time.time() + period_seconds, period_seconds)
        
        remaining = max(0, max_requests - new_count)
        reset_time = cache.get(reset_key, time.time() + period_seconds)
        
        return (False, remaining, reset_time)
    
    def process_request(self, request):
        """Process request and check rate limits."""
        is_limited, remaining, reset_time = self._is_rate_limited(request)
        
        if is_limited:
            # Add rate limit headers
            reset_timestamp = int(reset_time) if reset_time else None
            
            # Check if it's a GraphQL request
            content_type = request.META.get('CONTENT_TYPE', '')
            if 'application/json' in content_type or request.path == '/graphql/':
                # Return JSON response for GraphQL
                response = JsonResponse(
                    {
                        'errors': [{
                            'message': 'Rate limit exceeded. Please try again later.',
                            'extensions': {
                                'code': 'RATE_LIMIT_EXCEEDED',
                                'resetAt': reset_timestamp
                            }
                        }]
                    },
                    status=429
                )
            else:
                # Return plain text response
                response = HttpResponse(
                    'Rate limit exceeded. Please try again later.',
                    status=429
                )
            
            # Add rate limit headers
            response['X-RateLimit-Limit'] = str(self._get_rate_limit_for_path(request.path)[0])
            response['X-RateLimit-Remaining'] = '0'
            if reset_timestamp:
                response['X-RateLimit-Reset'] = str(reset_timestamp)
            response['Retry-After'] = str(int(reset_time - time.time())) if reset_time else '60'
            
            return response
        
        # Add rate limit info to request for logging
        if remaining is not None:
            request.rate_limit_remaining = remaining
            request.rate_limit_reset = reset_time
        
        return None
    
    def process_response(self, request, response):
        """Add rate limit headers to response."""
        if hasattr(request, 'rate_limit_remaining'):
            max_requests, _ = self._get_rate_limit_for_path(request.path)
            response['X-RateLimit-Limit'] = str(max_requests)
            response['X-RateLimit-Remaining'] = str(request.rate_limit_remaining)
            if hasattr(request, 'rate_limit_reset') and request.rate_limit_reset:
                response['X-RateLimit-Reset'] = str(int(request.rate_limit_reset))
        
        return response
