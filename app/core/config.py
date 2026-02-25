import os

APP_NAME = "IDP Portal / API Gateway"
JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret")
JWT_ALG = "HS256"
JWT_TTL_SECONDS = 8 * 60 * 60

STEP_FUNCTION_ARN = os.getenv("STEP_FUNCTION_ARN")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
DEFAULT_BUCKET_PREFIX = os.getenv("TENANT_BUCKET_PREFIX", "idp-tenant")
CALLBACK_TOKEN = os.getenv("PROVISIONING_CALLBACK_TOKEN", "dev-callback-token")

USERS = {
    "admin": {"password": "admin", "role": "admin"},
    "dev": {"password": "dev", "role": "developer"},
    "viewer": {"password": "viewer", "role": "viewer"},
}
