# Rate Limiting Documentation

This document describes the rate limiting implementation for the RunAm API.

## Overview

Rate limiting protects the API from abuse and ensures fair usage. The implementation includes:

1. **HTTP-level rate limiting**: Limits requests per IP/user per endpoint
2. **GraphQL operation-level rate limiting**: Limits specific GraphQL operations

## Configuration

### Environment Variables

Add these to your `.env` file:

```bash
# Enable/disable rate limiting (default: True)
RATE_LIMIT_ENABLED=True

# Cache key prefix (default: 'ratelimit')
RATE_LIMIT_CACHE_PREFIX=ratelimit

# Default rate limit for all endpoints (default: '100/h')
RATE_LIMIT_DEFAULT=100/h

# GraphQL query rate limit (default: '300/h')
RATE_LIMIT_GRAPHQL_QUERY=300/h

# GraphQL mutation rate limit (default: '50/h')
RATE_LIMIT_GRAPHQL_MUTATION=50/h
```

### Rate Limit Format

Rate limits use the format: `max_requests/period`

- **Periods**: `s` (second), `m` (minute), `h` (hour), `d` (day)
- **Examples**: 
  - `100/h` = 100 requests per hour
  - `10/m` = 10 requests per minute
  - `1000/d` = 1000 requests per day

## HTTP-Level Rate Limiting

The `RateLimitMiddleware` limits requests based on:
- **IP address** (for anonymous users)
- **User ID** (for authenticated users)

### Default Limits

- **Default**: 100 requests per hour per IP/user
- **GraphQL endpoint**: 200 requests per hour
- **Webhooks**: 1000 requests per day
- **Admin**: 1000 requests per hour

### Custom Path Rules

Configure custom limits in `settings.py`:

```python
RATE_LIMIT_RULES = {
    '/graphql/': '200/h',
    '/webhooks/flutterwave/': '1000/d',
    '/admin/': '1000/h',
}
```

## GraphQL Operation-Level Rate Limiting

The `RateLimitGraphQLMiddleware` provides granular control over GraphQL operations.

### Default Limits

- **Queries**: 300 per hour
- **Mutations**: 50 per hour

### Operation-Specific Limits

Configure in `settings.py`:

```python
RATE_LIMIT_GRAPHQL_OPERATIONS = {
    'tokenAuth': '20/m',  # 20 login attempts per minute
    'initializePayment': '10/h',  # 10 payment initializations per hour
    'createErrand': '20/h',  # 20 errands per hour
    'transferToRunner': '5/h',  # 5 transfers per hour
}
```

### Current Operation Limits

| Operation | Limit | Reason |
|-----------|-------|--------|
| `tokenAuth` | 20/m | Prevent brute force attacks |
| `verifyGoogleToken` | 20/m | Prevent abuse |
| `initializePayment` | 10/h | Prevent payment spam |
| `transferToRunner` | 5/h | Prevent transfer abuse |
| `createErrand` | 20/h | Prevent spam errands |
| `acceptErrand` | 30/h | Reasonable acceptance rate |
| `updateBankAccount` | 5/h | Prevent frequent changes |
| `registerFCMToken` | 10/h | Prevent token spam |

## Response Headers

Rate limit information is included in response headers:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
Retry-After: 3600  # Only present when rate limited
```

## Rate Limit Exceeded Response

When rate limit is exceeded, the API returns:

**HTTP Status**: `429 Too Many Requests`

**GraphQL Response**:
```json
{
  "errors": [{
    "message": "Rate limit exceeded for mutation 'createErrand'. Limit: 20 requests per 3600s. Try again after 1800 seconds.",
    "extensions": {
      "code": "RATE_LIMIT_EXCEEDED",
      "operation": "createErrand",
      "type": "mutation",
      "resetAt": 1640995200
    }
  }]
}
```

## Caching Backend

Rate limiting uses Django's cache framework. By default, it uses in-memory cache (`LocMemCache`).

### Production Recommendation: Redis

For production, use Redis for better performance and distributed rate limiting:

```python
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': os.getenv('REDIS_URL', 'redis://127.0.0.1:6379/1'),
    }
}
```

Install Redis:
```bash
pip install django-redis
```

## Testing Rate Limits

### Test with cURL

```bash
# Make multiple requests quickly
for i in {1..10}; do
  curl -X POST http://localhost:8000/graphql/ \
    -H "Content-Type: application/json" \
    -d '{"query": "{ me { id } }"}'
done
```

### Test Specific Operation

```bash
# Test mutation rate limit
for i in {1..10}; do
  curl -X POST http://localhost:8000/graphql/ \
    -H "Content-Type: application/json" \
    -H "Authorization: JWT your_token" \
    -d '{"query": "mutation { createErrand(...) { id } }"}'
done
```

## Bypassing Rate Limits

Rate limiting is automatically bypassed for:
- `/admin/` paths (admin interface)
- `/static/` paths (static files)
- `/media/` paths (media files)

To disable rate limiting entirely (not recommended):

```python
RATE_LIMIT_ENABLED = False
```

## Monitoring

Rate limit violations are logged:

```
WARNING: Rate limit exceeded: user=123, operation=createErrand, type=mutation
```

Monitor these logs to identify:
- Abusive users
- Operations that need rate limit adjustments
- Potential DDoS attacks

## Best Practices

1. **Set appropriate limits**: Balance between preventing abuse and allowing legitimate use
2. **Use Redis in production**: Better performance and distributed rate limiting
3. **Monitor violations**: Track rate limit hits to identify issues
4. **Adjust limits based on usage**: Monitor and adjust limits as needed
5. **Document limits**: Inform users about rate limits in API documentation

## Troubleshooting

### Rate limits too strict

Increase limits in `settings.py`:
```python
RATE_LIMIT_DEFAULT = '200/h'  # Increase from 100/h
RATE_LIMIT_GRAPHQL_MUTATION = '100/h'  # Increase from 50/h
```

### Rate limits not working

1. Check `RATE_LIMIT_ENABLED` is `True`
2. Verify middleware is in `MIDDLEWARE` list
3. Check cache backend is working
4. Review logs for errors

### Cache issues

If using Redis, verify connection:
```python
from django.core.cache import cache
cache.set('test', 'value', 60)
assert cache.get('test') == 'value'
```
