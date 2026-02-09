# import boto3

class Config:
    # SESSION_TYPE = 'dynamodb'
    # SESSION_DYNAMODB = boto3.resource('dynamodb')
    # SESSION_DYNAMODB_TABLE = 'flask-sessions'

    SESSION_TYPE = 'filesystem'
    SESSION_FILE_DIR = "/tmp/flask_session"
    SESSION_PERMANENT = False
    SESSION_USE_SIGNER = True
    SESSION_KEY_PREFIX = 'flask:'