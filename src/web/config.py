import boto3

class Config:
    SESSION_TYPE = 'dynamodb'
    SESSION_DYNAMODB = boto3.resource('dynamodb')
    SESSION_DYNAMODB_TABLE = 'flask-sessions'