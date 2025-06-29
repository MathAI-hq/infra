import os, json, uuid, datetime, bcrypt, boto3
table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

def handler(event, _):
    print("Received event:", event)  # DEBUG

    try:
        body = json.loads(event.get("body") or "{}")
    except Exception as e:
        print("Error parsing body:", str(e))
        return {"statusCode": 400, "body": "Invalid JSON"}

    for f in ("user_email", "user_password", "user_name", "user_age"):
        if f not in body:
            return {
                "statusCode": 400,
                "headers": {"Access-Control-Allow-Origin": "*"},
                "body": f"Missing required field: {f}"
            }

    try:
        uid = str(uuid.uuid4())
        pwd_hash = bcrypt.hashpw(body["user_password"].encode(), bcrypt.gensalt()).decode()
        now_iso = datetime.datetime.utcnow().isoformat()

        table.put_item(Item={
            "uid": uid,
            "user_email": body["user_email"].lower(),
            "user_name": body["user_name"],
            "user_password": pwd_hash,
            "user_age": int(body["user_age"]),
            "date_created": now_iso,
            "last_logged_in": None
        })

        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"uid": uid})
        }

    except Exception as e:
        print("Unhandled error:", str(e))
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": "Server error"
        }

