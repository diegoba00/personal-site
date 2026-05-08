import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    try:
        response = table.update_item(
            Key={"id": "visitors"},
            UpdateExpression="ADD visit_count :inc",
            ExpressionAttributeValues={":inc": 1},
            ReturnValues="UPDATED_NEW",
        )

        count = int(response["Attributes"]["visit_count"])

        print(f"Visitor count updated successfully: {count}")

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({"visitors": count}),
        }

    except KeyError as e:
        # DynamoDB attribute missing
        print(f"Error: Missing attribute in DynamoDB response - {e}")
        return error_response(500, "Database error")

    except ClientError as e:
        # DynamoDB throttled, permission error, etc
        error_code = e.response["Error"]["Code"]
        print(f"DynamoDB error ({error_code}): {e}")
        return error_response(503, "Service temporarily unavailable")

    except Exception as e:
        # Unexpected error
        print(f"Unexpected error: {e}")
        return error_response(500, "Internal server error")


def error_response(status_code, message):
    """Return a safe error response without exposing details"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps({"error": message}),
    }
