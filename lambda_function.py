import json
import boto3
import uuid
import base64
import decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('PetsTable')

import json
import decimal

class DecimalEncoder(json.JSONEncoder):
    """JSON encoder that converts DynamoDB Decimals into int or float."""
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            # convert to int if it represents a whole number (e.g. 10)
            if o % 1 == 0:
                return int(o)
            # otherwise, convert to float (e.g. 99.99) and round to two decimal places
            return round(float(o), 2)
        return super().default(o)

def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Access-Control-Allow-Origin": "*"},
        "body": json.dumps(body, cls=DecimalEncoder)
    }

def lambda_handler(event, context):
    # Debug logging
    print("=== DEBUG EVENT ===")
    print(json.dumps(event, indent=2))

    method = event['httpMethod']
    path_params = event.get('pathParameters') or {}
    body = None

    # --- FIXED BODY PARSING ---
    if event.get('body'):
        raw_body = event['body']
        if event.get('isBase64Encoded'):
            raw_body = base64.b64decode(raw_body).decode('utf-8')
        try:
            body = json.loads(raw_body)
            print(f"🧩 Decoded request body for {method} {event.get('path')}: {json.dumps(body, indent=2)}")
        except Exception as e:
            print(f"Failed to parse body: {e}")
            body = {}
    else:
        body = {}
        print(f"🧩 No body found for {method} {event.get('path')}")

# # --- FIXED BODY PARSING ---
#     if event.get('body'):
#         if body:
#             print(f"🧩 Decoded request body for {method} {event.get('path')}: {json.dumps(body, indent=2)}")
#         else:
#             print(f"🧩 No body found for {method} {event.get('path')}")
#         raw_body = event['body']
#         if event.get('isBase64Encoded'):
#             raw_body = base64.b64decode(raw_body).decode('utf-8')
#         try:
#             body = json.loads(raw_body)
#         except Exception as e:
#             print(f"Failed to parse body: {e}")
#             body = {}

    # --- GET /pets or /pets/{petId} ---
    if method == 'GET':
        if 'petId' in path_params:
            pet_id = path_params['petId']
            item = table.get_item(Key={'id': pet_id}).get('Item')
            return response(200, item or {})
        else:
            items = table.scan().get('Items', [])
            return response(200, items)

    # --- POST /pets ---
    elif method == 'POST':
        pet_id = str(uuid.uuid4())
        
        # Normalize numeric fields into Decimals
        if body and "price" in body:
            try:
                body["price"] = decimal.Decimal(str(body["price"]))
            except Exception as e:
                print(f"Price conversion error: {e}")
                return response(400, {"error": "Invalid price value"})
        new_pet = {"id": pet_id, **(body or {})}
        table.put_item(Item=new_pet)
        print(f"Inserted item: {new_pet}")
        return response(201, new_pet)

    # --- PUT /pets/{petId} ---
        # --- PUT /pets/{petId} ---
    elif method == 'PUT':
        if 'petId' not in path_params:
            return response(400, {"error": "petId is required in path"})
        pet_id = path_params['petId']
        updates = body or {}

        # Debug: show what was received
        print(f"Received updates for {pet_id}: {updates}")

        # Safely convert numeric-like values to Decimal
        for key, value in list(updates.items()):
            if isinstance(value, (int, float, str)):
                try:
                    num_val = decimal.Decimal(str(value))
                    # Only assign if it’s a valid number (not a string like "Lola")
                    if num_val.is_finite():
                        updates[key] = num_val
                except Exception:
                    # ignore non-numeric values
                    continue

        if not updates:
            return response(400, {"error": "No fields to update"})

        # Build the DynamoDB update expression
        expression = []
        values = {}
        for k, v in updates.items():
            expression.append(f"{k} = :{k}")
            values[f":{k}"] = v

        print(f"Update expression: {expression}")
        print(f"Expression values: {values}")

        try:
            table.update_item(
                Key={'id': pet_id},
                UpdateExpression="SET " + ", ".join(expression),
                ExpressionAttributeValues=values
            )
        except Exception as e:
            print(f"Update failed: {e}")
            return response(500, {"error": "Update failed", "detail": str(e)})

        return response(200, {"message": f"Pet {pet_id} updated"})



    # --- DELETE /pets/{petId} ---
    elif method == 'DELETE':
        if 'petId' not in path_params:
            return response(400, {"error": "petId is required in path"})
        pet_id = path_params['petId']
        table.delete_item(Key={'id': pet_id})
        return response(200, {"message": f"Pet {pet_id} deleted"})

    else:
        return response(405, {"error": f"Method {method} not allowed"})