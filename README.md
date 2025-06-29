# Math.AI — Infrastructure

Terraform IaC for the **serverless backend** that powers [Math.AI](https://github.com/MathAI-hq).  
It deploys a DynamoDB-backed sign-up API (HTTP API Gateway → Lambda → DynamoDB) and nothing else—clean, fast, cost-effective.

---

## ✨ What’s inside


infra/
├─ main.tf              # root module: DynamoDB + calls lambda/
├─ output.tf            # exposes signup_api_url
├─ lambda/              # sub-module for the sign-up Lambda + HTTP API
│  ├─ main.tf           # IAM, Lambda, API Gateway, $default stage
│  ├─ variables.tf      # module inputs
│  └─ zip/              # deployment package
│     ├─ handler.py
│     ├─ bcrypt/        # linux-compiled wheels (via Docker build step)
│     └─ bcrypt-*.dist-info/
└─ .gitignore           # keeps .terraform/ out of git



## System Architecture


   +──────────────+        POST /signup        +──────────────+
   |  Browser /   | ─────────────────────────▶ |  API Gateway  |
   |  Next.js App |                            +──────▲───────+
   +──────────────+                                   │
                                                     AWS_PROXY
                                                     │
                                     +───────────────┴───────────────+
                                     |  Lambda (mathai_signup)       |
                                     |  • bcrypt hash                |
                                     |  • PutItem → DynamoDB         |
                                     +───────────────▲───────────────+
                                                     │
                                      +──────────────┴──────────────+
                                      | DynamoDB  mathai_users      |
                                      +─────────────────────────────+



## 🚀 Getting Started

# Prerequisites
Tool	Version
Terraform	≥ 1.7
AWS CLI	≥ 2.0, configured with creds & default region (us-east-1)
Docker Desktop	(only for building Linux-compatible bcrypt)

```
  # clone & initialise
  git clone git@github.com:MathAI-hq/infra.git
  cd infra
  terraform init   # downloads providers
  
  # one-time build of bcrypt inside lambda/zip
  cd lambda
  rm -rf zip && mkdir zip
  docker run --rm -v "$PWD/zip:/var/task" amazonlinux:2 \
    bash -c "yum install -y python3-pip gcc python3-devel \
             && pip3 install bcrypt -t /var/task"
  cp handler.py zip/    # if handler.py lives at module root
  cd ..
  
  # deploy
  terraform apply
```
