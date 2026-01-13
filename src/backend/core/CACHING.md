# Caching Integration Documentation

This document describes the caching implementation for the RunAm API.

## Overview

The caching system provides:
1. **Automatic cache invalidation** when models are updated
2. **Query result caching** for frequently accessed data
3. **Redis support** for production (with local memory fallback)
4. **Cache utilities** for easy integration
5. **Cache management commands**

## Configuration

### Environment Variables

Add these to your `.env` file:

```bash
# Enable/disable caching (default: True)
CACHE_ENABLED=True

# Default cache timeout in seconds (default: 300 = 5 minutes)
CACHE_DEFAULT_TIMEOUT=300

# Redis URL (optional, uses local memory if not provided)
REDIS_URL=redis://127.0.0.1:6379/1

# Cache timeouts for specific data types
CACHE_TIMEOUT_USER_PROFILE=3600      # 1 hour
CACHE_TIMEOUT_USER_ERRANDS=300      # 5 minutes
CACHE_TIMEOUT_USER_ESCROWS=300      # 5 minutes
CACHE_TIMEOUT_ERRAND_LIST=60        # 1 minute
CACHE_TIMEOUT_ERRAND_DETAIL=300     # 5 minutes
CACHE_TIMEOUT_BANKS_LIST=86400      # 24 hours
CACHE_TIMEOUT_ROLES=3600            # 1 hour
```

### Cache Backends

#### Development (Local Memory)
Uses Django's `LocMemCache` by default. No additional setup required.

#### Production (Redis)
1. Install Redis:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install redis-server
   
   # macOS
   brew install redis
   ```

2. Install Python Redis client:
   ```bash
   pip install django-redis
   ```

3. Set `REDIS_URL` in `.env`:
   ```bash
   REDIS_URL=redis://127.0.0.1:6379/1
   ```

4. Start Redis:
   ```bash
   redis-server
   ```

## Cache Utilities

### Decorator: `@cache_result`

Cache function results automatically:

```python
from core.cache_utils import cache_result

@cache_result(timeout=600, key_prefix='user_profile')
def get_user_profile(user_id):
    return UserProfile.objects.get(user_id=user_id)

# Invalidate cache
get_user_profile.invalidate(user_id)
```

### Helper Functions

```python
from core.cache_utils import (
    get_cache_key,
    cache_user_data,
    get_cached_user_data,
    invalidate_user_cache,
    cache_queryset,
    CacheManager
)

# Generate cache key
key = get_cache_key('user', user_id)

# Cache user data
cache_user_data(user_id, data, timeout=3600)

# Get cached user data
data = get_cached_user_data(user_id)

# Invalidate all user cache
invalidate_user_cache(user_id)

# Cache queryset
results = cache_queryset(queryset, timeout=300)

# Clear all cache
CacheManager.clear_all()
```

## Automatic Cache Invalidation

Cache is automatically invalidated when models are saved or deleted:

- **User**: Invalidates user cache, user profile cache
- **UserProfile**: Invalidates user cache, profile cache
- **Errand**: Invalidates errand cache, user errands cache, errand list cache
- **Escrow**: Invalidates escrow cache, user escrows cache, errand escrow cache

## Cached GraphQL Queries

The following GraphQL queries are cached:

1. **`errands`**: Errand list (1 minute)
2. **`myEscrows`**: User's escrows (5 minutes)
3. **`banks`**: Bank list (24 hours)

## Cache Management

### Clear All Cache

```bash
python manage.py clear_cache --all
```

### Clear Cache Pattern

```bash
python manage.py clear_cache --pattern "user:*"
```

### Programmatic Cache Management

```python
from core.cache_utils import CacheManager

# Clear all cache
CacheManager.clear_all()

# Get cache statistics
stats = CacheManager.get_stats()

# Warm up cache
CacheManager.warm_up()
```

## Cache Key Patterns

Cache keys follow these patterns:

- `user:{user_id}:data` - User data
- `user_profile:{user_id}` - User profile
- `user_errands:{user_id}` - User's errands
- `user_escrows:{user_id}` - User's escrows
- `errand:{errand_id}` - Errand details
- `errand_list:*` - Errand lists
- `escrow:{escrow_id}` - Escrow details
- `banks_list:{country}` - Bank lists

## Best Practices

1. **Use appropriate timeouts**: 
   - Frequently changing data: 1-5 minutes
   - Rarely changing data: 1-24 hours
   - Static data: 24+ hours

2. **Invalidate on updates**: 
   - Cache signals handle automatic invalidation
   - Manually invalidate when needed

3. **Monitor cache performance**:
   - Check cache hit rates
   - Monitor Redis memory usage
   - Adjust timeouts based on usage

4. **Use Redis in production**:
   - Better performance
   - Distributed caching
   - Persistence options

## Testing Cache

### Test Cache Hit/Miss

```python
from django.core.cache import cache
from core.cache_utils import cache_result

@cache_result(timeout=60)
def test_function(value):
    return value * 2

# First call - cache miss
result1 = test_function(5)  # Executes function

# Second call - cache hit
result2 = test_function(5)  # Returns cached value
```

### Test Cache Invalidation

```python
# Cache some data
cache.set('test_key', 'test_value', 60)

# Verify it's cached
assert cache.get('test_key') == 'test_value'

# Invalidate
cache.delete('test_key')

# Verify it's gone
assert cache.get('test_key') is None
```

## Troubleshooting

### Cache not working

1. Check `CACHE_ENABLED` is `True`
2. Verify cache backend is configured
3. Check Redis connection (if using Redis)
4. Review logs for cache errors

### Redis connection issues

```python
from django.core.cache import cache

# Test connection
try:
    cache.set('test', 'value', 60)
    assert cache.get('test') == 'value'
    print("Cache working!")
except Exception as e:
    print(f"Cache error: {e}")
```

### Cache memory issues

- Monitor Redis memory: `redis-cli INFO memory`
- Set max memory: `redis-cli CONFIG SET maxmemory 256mb`
- Use eviction policy: `redis-cli CONFIG SET maxmemory-policy allkeys-lru`

## Performance Tips

1. **Cache expensive queries**: Database queries, API calls
2. **Use appropriate timeouts**: Balance freshness vs performance
3. **Cache at multiple levels**: Query results, computed values, rendered content
4. **Monitor cache hit rates**: Optimize based on actual usage
5. **Use Redis in production**: Better performance than local memory

## Production Checklist

- [ ] Set `CACHE_ENABLED=True`
- [ ] Configure `REDIS_URL` for production
- [ ] Set appropriate cache timeouts
- [ ] Monitor Redis memory usage
- [ ] Set up Redis persistence (if needed)
- [ ] Configure Redis eviction policy
- [ ] Test cache invalidation
- [ ] Monitor cache hit rates
