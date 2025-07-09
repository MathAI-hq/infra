import json
import os
import datetime
import bcrypt
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

def handler(event, context):
    # Parse body
    body = json.loads(event.get("body") or "{}")
    email    = body.get("user_email")
    password = body.get("user_password")

    # Validate input
    if not email or not password:
        return _response(400, "Missing user_email or user_password")

    # 1) Query by e-mail via GSI
    resp = table.query(
        IndexName="user_email_index",
        KeyConditionExpression=Key("user_email").eq(email.lower()),
        Limit=1
    )
    if resp["Count"] == 0:
        return _response(401, "Invalid credentials")

    user = resp["Items"][0]

    # 2) Verify password
    if not bcrypt.checkpw(password.encode(), user["user_password"].encode()):
        return _response(401, "Invalid credentials")

    # 3) Update last_logged_in
    table.update_item(
        Key={"uid": user["uid"]},
        UpdateExpression="SET last_logged_in = :ts",
        ExpressionAttributeValues={":ts": datetime.datetime.utcnow().isoformat()}
    )

    # 4) Success
    return _response(200, {
        "uid": user["uid"],
        "user_name": user["user_name"],
        "message": "logged-in"
    })

def _response(status, body):
    if not isinstance(body, str):
        body = json.dumps(body)
    return {
        "statusCode": status,
        "headers": {"Access-Control-Allow-Origin": "*"},
        "body": body
    }

