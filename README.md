# Math.AI User Authentication Backend

A lightweight serverless backend for user **sign-up** and **login** built using AWS services, including Lambda, API Gateway, and DynamoDB. Passwords are securely hashed using `bcrypt`.

---

## 🚀 Features

- **User Sign-Up**: Stores user profile in DynamoDB
- **User Login**: Validates user credentials via hashed password
- **Serverless**: Fully managed via AWS Lambda & API Gateway
- **Secure**: Uses `bcrypt` for password hashing
- **Modern IaC**: Provisioned using Terraform
- **DynamoDB GSI**: Email-based login support via secondary index

---

## 📦 Tech Stack

- **AWS Lambda** (Python 3.12)
- **AWS API Gateway** (HTTP API)
- **AWS DynamoDB** (with GSI)
- **Terraform**
- **Python** (`boto3`, `bcrypt`)

---

## 📁 Project Structure




---

## ⚙️ Setup Instructions

### 1. Prerequisites

- AWS CLI configured
- Terraform installed
- Docker installed (for packaging bcrypt correctly)

### 2. Install `bcrypt` in a Lambda-compatible environment

```bash
docker run --rm -v "$PWD/lambda/zip:/var/task" amazonlinux:2 \
  bash -c "yum install -y python3-pip gcc python3-devel \
           && pip3 install bcrypt -t /var/task"


---
##Deploy

terraform init
terraform apply
