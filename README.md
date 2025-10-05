# 💾 PetStore Demo API (AWS API Gateway + Lambda + DynamoDB)

A fully functional **CRUD API** built on AWS using **API Gateway**, **Lambda**, and **DynamoDB** — all defined via Terraform and a single Python Lambda handler.

This project demonstrates how to deploy a production-style serverless application that can create, read, update, and delete pet records, with clean integration logging, CORS, and DynamoDB persistence.

---

## 📘 Overview

**Architecture:**

```
+------------------+           +---------------------------+           +------------------------+
|  Client (curl,   |  HTTPS    |   Amazon API Gateway      |  invokes  |   AWS Lambda Function  |
|  Postman, etc.)  +---------->+---------------------------+---------->+------------------------+
|                  |           |  REST API (AWS_PROXY)     |           |  (PetStoreHandler.py)  |
|                  |           |  Stage: dev               |           |  CRUD Logic            |
+------------------+           +---------------------------+           |  DynamoDB Access       |
                                                                       |  CloudWatch Logs       |
                                                                       +-----------+------------+
                                                                                   |
                                                                                   |
                                                                                   v
                                                                      +------------------------+
                                                                      |   DynamoDB Table       |
                                                                      |   Name: PetsTable      |
                                                                      |   PK: id (String)      |
                                                                      +------------------------+
```

**Features:**
- ✅ RESTful endpoints (`GET`, `POST`, `PUT`, `DELETE`)
- ✅ Serverless Python backend
- ✅ DynamoDB persistence
- ✅ CORS enabled
- ✅ Detailed CloudWatch logs (API + Lambda)
- ✅ Terraform-managed deployment

---

## 💧 Components

### 1. DynamoDB Table
**Table name:** `PetsTable`

**Primary key:**
| Attribute | Type | Notes |
|------------|------|-------|
| `id` | `String` | UUID (primary key) |

Example item:
```json
{
  "id": "db346ff0-8e92-4306-abeb-6d02573195bc",
  "petName": "Lola",
  "petType": "Cat",
  "price": 99.99
}
```

---

### 2. AWS Lambda — `PetStoreHandler`

**File:** `lambda_function.py`

**Purpose:** Implements all CRUD operations using the DynamoDB `PetsTable`.

#### Key Features
- JSON parsing with Base64 detection (for proxy integration)
- `DecimalEncoder` for serializing DynamoDB Decimal types
- CORS headers on every response
- Rich debug logging to CloudWatch

#### Supported Methods
| Method | Path | Description |
|---------|------|-------------|
| `GET` | `/pets` | List all pets |
| `GET` | `/pets/{petId}` | Retrieve a pet by ID |
| `POST` | `/pets` | Create a new pet |
| `PUT` | `/pets/{petId}` | Update a pet |
| `DELETE` | `/pets/{petId}` | Delete a pet |

---

### 3. API Gateway

**Type:** REST API using `aws_proxy` Lambda integration.

**Deployed stage:** `dev`

#### Base URL
```
https://<api_id>.execute-api.us-east-1.amazonaws.com/dev
```

#### Example Requests

**Create a pet**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"petName":"Lola","petType":"Cat","price":99.99}' \
  https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/pets
```

**List all pets**
```bash
curl https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/pets
```

**Update a pet**
```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -d '{"price":2.49,"petType":"UpdatedThing","petName":"Lola"}' \
  https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/pets/<petId>
```

**Delete a pet**
```bash
curl -X DELETE \
  https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/pets/<petId>
```

---

### 4. Terraform Infrastructure

**Key resources:**
- `aws_lambda_function.petstore`
- `aws_dynamodb_table.pets`
- `aws_api_gateway_rest_api.petstore_api`
- `aws_api_gateway_stage.petstore_stage`
- `aws_iam_role.lambda_exec` (Lambda execution role)
- `aws_api_gateway_account.account` (CloudWatch log role link)

Run sequence:

```bash
terraform init
terraform apply -auto-approve
```

This:
- Creates the DynamoDB table
- Deploys the Lambda handler
- Imports the API Gateway definition (`petstore.json`)
- Links CloudWatch logging via `APIGatewayCloudWatchLogsRole`
- Deploys the API to the `dev` stage

To destroy all resources:
```bash
terraform destroy -auto-approve
```

---

## 🥵 Logging & Monitoring

### Lambda Logs
CloudWatch log group:
```
/aws/lambda/PetStoreHandler
```

Contains:
- Raw API Gateway event payloads
- Decoded JSON bodies
- DynamoDB update expressions
- Request/response durations

### API Gateway Logs
CloudWatch log group:
```
/aws/apigateway/<api_id>/dev
```

Shows:
- HTTP method, resource path
- Transformed request body (proxy envelope)
- Integration request/response timing
- Execution result (`status: 200`, `error: null`)

---

## ⚙️ Configuration Notes

- **Region:** `us-east-1`
- **Account ID:** `${account_id}` (templated in Terraform)
- **Runtime:** Python 3.12
- **Integration type:** `AWS_PROXY`
- **CORS:** Enabled globally
- **CloudWatch Role:** `APIGatewayCloudWatchLogsRole`
- **Stage name:** `dev`

---

## 🧮 Development Tips

- To update Lambda code only:
  ```bash
  terraform apply -target=aws_lambda_function.petstore -auto-approve
  ```
- To refresh the API Gateway definition after changing `petstore.json`:
  ```bash
  terraform apply -target=aws_api_gateway_rest_api.petstore_api -auto-approve
  terraform apply -target=aws_api_gateway_deployment.petstore_deploy -auto-approve
  ```
- To manually invoke Lambda:
  ```bash
  aws lambda invoke --function-name PetStoreHandler out.json
  ```

---

## 🪜 Cleanup

Destroy all demo resources:
```bash
terraform destroy -auto-approve
```

This deletes:
- DynamoDB table
- Lambda function + IAM role
- API Gateway REST API + stage
- CloudWatch log groups (if set to delete on destroy)

---

## 🏁 Summary

This PetStore demo provides a **complete, production-ready example** of how to build and manage a serverless REST API on AWS using infrastructure as code.

It demonstrates:
- How to structure a single Lambda for multiple routes
- How API Gateway proxy events are passed to Lambda
- Safe Decimal handling with DynamoDB
- Practical logging for debugging and monitoring
- Terraform-based repeatable deployment

---

### 👨‍💻 Author
Created for instructional demos and hands-on cloud training in **AWS Developer & DevOps** labs.

---

