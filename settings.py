import os
from pathlib import Path
import sys

# Load environment variables
BASE_DIR = Path(__file__).resolve().parent.parent

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Get secret key from environment or use default for development
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'django-insecure-your-secret-key-here')

DEBUG = os.environ.get('DJANGO_DEBUG', 'True') == 'True'

# PythonAnywhere subdomain - change 'yourusername' to your actual PythonAnywhere username
PYTHONANYWHERE_DOMAIN = os.environ.get('PYTHONANYWHERE_DOMAIN', 'yourusername.pythonanywhere.com')

# Add your network IP and PythonAnywhere domain to ALLOWED_HOSTS
ALLOWED_HOSTS = ['localhost', '127.0.0.1', PYTHONANYWHERE_DOMAIN]
# Add additional hosts from environment if provided
if os.environ.get('DJANGO_ALLOWED_HOSTS'):
    ALLOWED_HOSTS.extend(os.environ.get('DJANGO_ALLOWED_HOSTS').split(','))

# For development, you can keep using '*' but not recommended for production
if DEBUG:
    ALLOWED_HOSTS.append('*')
    ALLOWED_HOSTS.append('192.168.197.149')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'novalib',
    'corsheaders',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'corsheaders.middleware.CorsMiddleware',
]

ROOT_URLCONF = 'novalib_web.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / "templates"],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'novalib_web.wsgi.application'

# Database configuration
# Use environment variables for production database or default to development settings
if 'PYTHONANYWHERE_SITE' in os.environ:
    # Production database settings
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.mysql',
            'NAME': os.environ.get('DB_NAME', 'yourusername$novalib_db'),
            'USER': os.environ.get('DB_USER', 'yourusername'),
            'PASSWORD': os.environ.get('DB_PASSWORD', 'database_password'),
            'HOST': os.environ.get('DB_HOST', 'yourusername.mysql.pythonanywhere-services.com'),
            'PORT': '3306',
            'OPTIONS': {
                'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
            },
        }
    }
else:
    # Development database settings
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.mysql',
            'NAME': "novalib_db",  
            'USER': "root",        
            'PASSWORD': "Sayan@kumar1234",
            'HOST': "localhost",         
            'PORT': '3306',
            'OPTIONS': {
                'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
            },
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kolkata'
USE_I18N = True
USE_TZ = True

# Static files configuration for PythonAnywhere
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static')

# Additional static file locations
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'static'),
]

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# REST Framework configuration
REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
}

# Session configuration
SESSION_ENGINE = 'django.contrib.sessions.backends.db'
SESSION_COOKIE_AGE = 600  # 10 minutes

# Email configuration - use environment variables for production
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', 'sayan.kumar.roy@aus.ac.in')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', 'dhsa hntb ency rxzx')

# CORS settings
CORS_ALLOW_ALL_ORIGINS = DEBUG  # Only allow all origins in development
if not DEBUG:
    CORS_ALLOWED_ORIGINS = [
        f"https://{PYTHONANYWHERE_DOMAIN}",
        # Add other allowed origins as needed
    ]