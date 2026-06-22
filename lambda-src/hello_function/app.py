import json
import os


def lambda_handler(event, context):
    environment = os.environ.get('ENVIRONMENT', 'unknown')
    version = os.environ.get('VERSION', 'Blue')  # For blue/green

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET,OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,X-Api-Key'
        },
        'body': json.dumps({
            'message': f'Hello from {environment} ({version})!'
        })
    }
