import os, json, datetime, bcrypt, boto3
from boto3.dynamodb.conditions import Key

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

def bad_request(msg, code=400):
    return {
        "statusCode": code,
        "headers": {"Access-Control-Allow-Origin": "*"},
        "body": msg
    }

def handler(event, _):
    body = json.loads(event.get("body") or "{}")

    for f in ("user_email", "user_password"):
        if f not in body:
            return bad_request(f"Missing {f}")

    # 1. Query by e-mail (GSI)
    resp = table.query(
        IndexName="user_email_index",
        KeyConditionExpression=Key("user_email").eq(body["user_email"].lower()),
        Limit=1
    )
    if resp["Count"] == 0:
        return bad_request("Invalid credentials", 401)

    user = resp["Items"][0]

    # 2. Verify bcrypt hash
    if not bcrypt.checkpw(body["user_password"].encode(),
                          user["user_password"].encode()):
        return bad_request("Invalid credentials", 401)

    # 3. Update last_logged_in
    table.update_item(
        Key={"uid": user["uid"]},
        UpdateExpression="SET last_logged_in = :ts",
        ExpressionAttributeValues={":ts": datetime.datetime.utcnow().isoformat()}
    )

    return {
        "statusCode": 200,
        "headers": {"Access-Control-Allow-Origin": "*"},
        "body": json.dumps({"uid": user["uid"], "message": "logged-in"})
    }

