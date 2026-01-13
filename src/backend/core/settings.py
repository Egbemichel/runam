"""
Django settings for core project.
Configured for GraphQL (Graphene + graphql-jwt), not REST.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# -------------------------------------------------------------------
# Base
# -------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / '.env')

SECRET_KEY = os.getenv(
    "DJANGO_SECRET_KEY",
    'django-insecure-k#oc+-y2hbem_c_bck#ka_#lzb9=k@sd)wx!^rk)zovt4q0sd-'
)

DEBUG = True
ALLOWED_HOSTS = ["*"]

# -------------------------------------------------------------------
# Applications
# -------------------------------------------------------------------
INSTALLED_APPS = [
    # Django
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.sites',

    # CORS
    'corsheaders',

    # GraphQL
    'graphene_django',

    # JWT refresh tokens
    'graphql_jwt.refresh_token.apps.RefreshTokenConfig',

    # Auth / Social (used via GraphQL)
    'allauth',
    'allauth.account',
    'allauth.socialaccount',
    'allauth.socialaccount.providers.google',

    # Local apps
    'apps.users.apps.UsersConfig',
    'apps.errands.apps.ErrandsConfig',
    'apps.locations.apps.LocationsConfig',
    'apps.roles.apps.RolesConfig',
    'apps.trust.apps.TrustConfig',
    'apps.escrow.apps.EscrowConfig',
    'apps.payments.apps.PaymentsConfig',
    'errand_location'

]

SITE_ID = 1

# -------------------------------------------------------------------
# Middleware
# -------------------------------------------------------------------
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',

    # Rate limiting (after auth middleware to access user)
    'core.middleware.RateLimitMiddleware',

    # Required by django-allauth
    'allauth.account.middleware.AccountMiddleware',
]

# -------------------------------------------------------------------
# URLs / WSGI
# -------------------------------------------------------------------
ROOT_URLCONF = 'core.urls'
WSGI_APPLICATION = 'core.wsgi.application'

# -------------------------------------------------------------------
# Templates
# -------------------------------------------------------------------
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# -------------------------------------------------------------------
# Database
# -------------------------------------------------------------------
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# -------------------------------------------------------------------
# Authentication
# -------------------------------------------------------------------

AUTHENTICATION_BACKENDS = [
    # GraphQL JWT auth
    'graphql_jwt.backends.JSONWebTokenBackend',

    # Default Django auth
    'django.contrib.auth.backends.ModelBackend',
]

GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID', '')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET', '')

# -------------------------------------------------------------------
# GraphQL / Graphene
# -------------------------------------------------------------------
GRAPHENE = {
    'SCHEMA': 'core.schema.schema',
    'MIDDLEWARE': [
        'graphql_jwt.middleware.JSONWebTokenMiddleware',
        'core.graphql_middleware.RateLimitGraphQLMiddleware',
    ],
}

GRAPHQL_JWT = {
    'JWT_VERIFY_EXPIRATION': True,
    'JWT_LONG_RUNNING_REFRESH_TOKEN': True,
    'JWT_ALLOW_ARGUMENT': True,
}

# -------------------------------------------------------------------
# CORS
# -------------------------------------------------------------------
CORS_ALLOW_ALL_ORIGINS = True

# -------------------------------------------------------------------
# Password validation
# -------------------------------------------------------------------
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# -------------------------------------------------------------------
# Internationalization
# -------------------------------------------------------------------
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# -------------------------------------------------------------------
# Static files
# -------------------------------------------------------------------
STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# -------------------------------------------------------------------
# Environment variables
# -------------------------------------------------------------------
SOCIALACCOUNT_ADAPTER = 'apps.users.adapters.CustomSocialAccountAdapter'

# -------------------------------------------------------------------
# Media / Storage
# -------------------------------------------------------------------
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Storage mode: 'local' or 'supabase'
STORAGE_MODE = os.getenv('STORAGE_MODE', 'local' if DEBUG else 'supabase')
SUPABASE_URL = os.getenv('SUPABASE_URL', '')
SUPABASE_BUCKET = os.getenv('SUPABASE_BUCKET', 'public')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY', '')

# -------------------------------------------------------------------
# Flutterwave Payment Gateway
# -------------------------------------------------------------------
FLUTTERWAVE_SECRET_KEY = os.getenv('FLUTTERWAVE_SECRET_KEY', '')
FLUTTERWAVE_PUBLIC_KEY = os.getenv('FLUTTERWAVE_PUBLIC_KEY', '')
FLUTTERWAVE_ENCRYPTION_KEY = os.getenv('FLUTTERWAVE_ENCRYPTION_KEY', '')
FLUTTERWAVE_SECRET_HASH = os.getenv('FLUTTERWAVE_SECRET_HASH', '')  # For webhook signature verification
FLUTTERWAVE_CURRENCY = os.getenv('FLUTTERWAVE_CURRENCY', 'NGN')
FLUTTERWAVE_TEST_MODE = os.getenv('FLUTTERWAVE_TEST_MODE', 'True').lower() == 'true'
FLUTTERWAVE_LOGO_URL = os.getenv('FLUTTERWAVE_LOGO_URL', '')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'http://localhost:3000')

# -------------------------------------------------------------------
# Rate Limiting
# -------------------------------------------------------------------
RATE_LIMIT_ENABLED = os.getenv('RATE_LIMIT_ENABLED', 'True').lower() == 'true'
RATE_LIMIT_CACHE_PREFIX = os.getenv('RATE_LIMIT_CACHE_PREFIX', 'ratelimit')
RATE_LIMIT_DEFAULT = os.getenv('RATE_LIMIT_DEFAULT', '100/h')  # Default: 100 requests per hour

# Rate limit rules for specific paths/operations
# Format: 'path_pattern': 'max_requests/period'
# Periods: s (second), m (minute), h (hour), d (day)
RATE_LIMIT_RULES = {
    '/graphql/': '200/h',  # GraphQL endpoint: 200 requests per hour
    '/webhooks/flutterwave/': '1000/d',  # Webhooks: 1000 per day
    '/admin/': '1000/h',  # Admin: 1000 per hour
}

# GraphQL-specific rate limits
RATE_LIMIT_GRAPHQL_QUERY = os.getenv('RATE_LIMIT_GRAPHQL_QUERY', '300/h')  # Default: 300 queries per hour
RATE_LIMIT_GRAPHQL_MUTATION = os.getenv('RATE_LIMIT_GRAPHQL_MUTATION', '50/h')  # Default: 50 mutations per hour

# Operation-specific rate limits
# Format: 'operation_name': 'max_requests/period'
RATE_LIMIT_GRAPHQL_OPERATIONS = {
    # Authentication operations - more lenient
    'tokenAuth': '20/m',  # 20 login attempts per minute
    'verifyGoogleToken': '20/m',
    'refreshToken': '100/h',
    
    # Payment operations - stricter
    'initializePayment': '10/h',  # 10 payment initializations per hour
    'verifyPayment': '30/h',
    'transferToRunner': '5/h',  # 5 transfers per hour
    
    # Errand operations
    'createErrand': '20/h',  # 20 errands per hour
    'acceptErrand': '30/h',  # 30 acceptances per hour
    'updateErrand': '100/h',
    
    # Bank account operations
    'updateBankAccount': '5/h',  # 5 updates per hour
    
    # FCM token operations
    'registerFCMToken': '10/h',
    'unregisterFCMToken': '20/h',
}

# -------------------------------------------------------------------
# Caching Configuration
# -------------------------------------------------------------------
CACHE_ENABLED = os.getenv('CACHE_ENABLED', 'True').lower() == 'true'
CACHE_DEFAULT_TIMEOUT = int(os.getenv('CACHE_DEFAULT_TIMEOUT', '300'))  # 5 minutes
REDIS_URL = os.getenv('REDIS_URL', '')

# Cache configuration
# Supports Redis (production) or local memory (development)
if CACHE_ENABLED and REDIS_URL:
    # Use Redis for production
    try:
        CACHES = {
            'default': {
                'BACKEND': 'django.core.cache.backends.redis.RedisCache',
                'LOCATION': REDIS_URL,
                'OPTIONS': {
                    'CLIENT_CLASS': 'django_redis.client.DefaultClient',
                    'SOCKET_CONNECT_TIMEOUT': 5,
                    'SOCKET_TIMEOUT': 5,
                    'COMPRESSOR': 'django_redis.compressors.zlib.ZlibCompressor',
                    'IGNORE_EXCEPTIONS': True,  # Don't fail if Redis is down
                },
                'KEY_PREFIX': 'runam',
                'VERSION': 1,
                'TIMEOUT': CACHE_DEFAULT_TIMEOUT,
            }
        }
    except ImportError:
        # Fallback to local memory if django-redis not installed
        logger.warning("Redis URL provided but django-redis not installed. Using local memory cache.")
        CACHES = {
            'default': {
                'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
                'LOCATION': 'runam-cache',
                'OPTIONS': {
                    'MAX_ENTRIES': 10000,
                },
                'TIMEOUT': CACHE_DEFAULT_TIMEOUT,
            }
        }
else:
    # Use local memory cache for development
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
            'LOCATION': 'runam-cache',
            'OPTIONS': {
                'MAX_ENTRIES': 10000,
            },
            'TIMEOUT': CACHE_DEFAULT_TIMEOUT,
        }
    }

# Cache timeouts (in seconds)
CACHE_TIMEOUTS = {
    'user_profile': int(os.getenv('CACHE_TIMEOUT_USER_PROFILE', '3600')),  # 1 hour
    'user_errands': int(os.getenv('CACHE_TIMEOUT_USER_ERRANDS', '300')),  # 5 minutes
    'user_escrows': int(os.getenv('CACHE_TIMEOUT_USER_ESCROWS', '300')),  # 5 minutes
    'errand_list': int(os.getenv('CACHE_TIMEOUT_ERRAND_LIST', '60')),  # 1 minute
    'errand_detail': int(os.getenv('CACHE_TIMEOUT_ERRAND_DETAIL', '300')),  # 5 minutes
    'banks_list': int(os.getenv('CACHE_TIMEOUT_BANKS_LIST', '86400')),  # 24 hours
    'roles': int(os.getenv('CACHE_TIMEOUT_ROLES', '3600')),  # 1 hour
}
