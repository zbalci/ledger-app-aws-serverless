import os
import boto3
from functools import lru_cache

class Config:
    SESSION_TYPE = 'dynamodb'
    SESSION_DYNAMODB = boto3.resource('dynamodb')
    SESSION_DYNAMODB_TABLE = 'flask-sessions'


class Settings:

    def __init__(self):

        self.app_name = os.getenv("APP_NAME")
        self.environment = os.getenv("ENVIRONMENT")
        self.region = os.getenv("REGION")

        self.base_domain = os.getenv("COGNITO_DOMAIN")

        self.cognito_domain_prefix = f"{self.app_name}-{self.environment}"

        self.ssm_prefix = f"/{self.app_name}/{self.environment}/cognito"

@lru_cache()
def get_ssm_parameters(prefix, region):

    ssm = boto3.client("ssm", region_name=region)

    response = ssm.get_parameters_by_path(
        Path=prefix,
        WithDecryption=True
    )

    params = {}
    for p in response["Parameters"]:
        key = p["Name"].split("/")[-1]
        params[key] = p["Value"]

    return params