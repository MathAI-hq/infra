import json
import os
import requests
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

def handler(event, context):
    print("Received event:", event)

    try:
        body = json.loads(event.get("body") or "{}")
    except Exception as e:
        print("Error parsing body:", str(e))
        return _response(400, "Invalid JSON")

    # Validate required fields
    required_fields = ["user_email", "message"]
    for field in required_fields:
        if field not in body:
            return _response(400, f"Missing required field: {field}")

    user_email = body["user_email"].lower()
    message = body["message"]

    # Verify user exists
    resp = table.query(
        IndexName="user_email_index",
        KeyConditionExpression=Key("user_email").eq(user_email),
        Limit=1
    )
    
    if resp["Count"] == 0:
        return _response(401, "User not found")

    user = resp["Items"][0]

    try:
        # Get OpenAI API key from environment or AWS Secrets Manager
        openai_api_key = os.environ.get("OPENAI_API_KEY")
        
        if not openai_api_key:
            # Try to get from Secrets Manager
            secrets_client = boto3.client('secretsmanager')
            try:
                secret = secrets_client.get_secret_value(SecretId='openai-api-key')
                openai_api_key = secret['SecretString']
            except Exception as e:
                print(f"Error getting API key from Secrets Manager: {e}")
                return _response(500, "OpenAI API key not configured")

        # Call OpenAI API
        headers = {
            "Authorization": f"Bearer {openai_api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "gpt-3.5-turbo",
            "messages": [
                {"role": "system", "content": "You are a helpful math tutor. Provide clear, step-by-step explanations for mathematical problems."},
                {"role": "user", "content": message}
            ],
            "max_tokens": 500,
            "temperature": 0.7
        }

        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=25
        )

        if response.status_code == 200:
            result = response.json()
            ai_response = result["choices"][0]["message"]["content"]
            
            return _response(200, {
                "user_name": user["user_name"],
                "ai_response": ai_response,
                "message": "AI response generated successfully"
            })
        else:
            print(f"OpenAI API error: {response.status_code} - {response.text}")
            return _response(500, "Error calling OpenAI API")

    except requests.exceptions.Timeout:
        return _response(408, "Request timeout")
    except requests.exceptions.RequestException as e:
        print(f"Request error: {e}")
        return _response(500, "Error communicating with OpenAI")
    except Exception as e:
        print(f"Unhandled error: {e}")
        return _response(500, "Server error")

def _response(status, body):
    if not isinstance(body, str):
        body = json.dumps(body)
    return {
        "statusCode": status,
        "headers": {"Access-Control-Allow-Origin": "*"},
        "body": body
    }