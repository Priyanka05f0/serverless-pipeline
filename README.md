# Multi-Environment Serverless Deployment Pipeline

> **AWS Lambda + API Gateway + Terraform + GitHub Actions CI/CD with Blue/Green Deployment**

## Architecture Overview

This project implements a robust, production-grade CI/CD pipeline for a serverless API across three fully isolated environments (`dev`, `staging`, `prod`), using Infrastructure as Code and a blue/green deployment strategy for zero-downtime production releases.

```
GitHub Push
    │
    ├─► [feature/*] ──► Deploy DEV (auto)
    │
    └─► [main] ──► Deploy DEV (auto)
                       │
                       ▼
              Manual Approval Gate
                       │
                       ▼
               Deploy STAGING (auto)
                       │
                       ▼
              Manual Approval Gate
                       │
                       ▼
          Deploy PROD Blue/Green (validate → swap)
```

## Technology Stack

| Layer | Technology |
|---|---|
| Compute | AWS Lambda (Python 3.11) |
| API | AWS API Gateway (REST) |
| IaC | Terraform (modular, S3 backend) |
| CI/CD | GitHub Actions |
| Monitoring | AWS CloudWatch Logs + Alarms |
| Secrets | AWS Secrets Manager / GitHub Secrets |
| Local Dev | Docker Compose + LocalStack |

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline definition
├── terraform/
│   ├── modules/
│   │   ├── lambda/             # Reusable Lambda module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── api-gateway/        # Reusable API Gateway module
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── environments/
│       ├── dev/                # Dev environment root module
│       ├── staging/            # Staging environment root module
│       └── prod/               # Prod environment (blue/green logic)
├── lambda-src/
│   └── hello_function/
│       ├── app.py              # Python Lambda handler
│       └── requirements.txt
├── docker-compose.yml          # Local testing with LocalStack
├── Makefile                    # Local deployment commands
├── .env.example                # Required environment variables
└── README.md
```

## Prerequisites

- AWS Account with appropriate IAM permissions
- Terraform >= 1.0 installed locally
- AWS CLI configured
- GitHub repository with Actions enabled

## AWS Setup (One-Time Manual Steps)

### 1. Create S3 Bucket for Terraform State

```bash
aws s3api create-bucket \
  --bucket your-tf-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-tf-state-bucket \
  --versioning-configuration Status=Enabled
```

### 2. Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name your-tf-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Create IAM User for CI/CD

```bash
aws iam create-user --user-name github-actions-deployer
aws iam attach-user-policy \
  --user-name github-actions-deployer \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam create-access-key --user-name github-actions-deployer
# Save the AccessKeyId and SecretAccessKey
```

## GitHub Repository Setup

### Add Repository Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | From IAM user created above |
| `AWS_SECRET_ACCESS_KEY` | From IAM user created above |
| `TF_STATE_BUCKET` | Your S3 bucket name |
| `TF_LOCK_TABLE` | Your DynamoDB table name |
| `PROD_API_KEY` | Will be output after first prod deploy |

### Configure GitHub Environments with Manual Approval

1. Go to **Settings → Environments**
2. Create environment `staging`:
   - Check **Required reviewers**
   - Add yourself as a reviewer
3. Create environment `prod`:
   - Check **Required reviewers**
   - Add yourself as a reviewer

## Local Development

### Setup

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/serverless-pipeline.git
cd serverless-pipeline

# Copy and fill in environment variables
cp .env.example .env
# Edit .env with your actual values
source .env
```

### Deploy Locally with Make

```bash
# Deploy to dev only
make dev TF_STATE_BUCKET=your-bucket TF_LOCK_TABLE=your-table

# Deploy to staging
make staging TF_STATE_BUCKET=your-bucket TF_LOCK_TABLE=your-table

# Deploy to prod (blue slot)
make prod TF_STATE_BUCKET=your-bucket TF_LOCK_TABLE=your-table ACTIVE_SLOT=blue

# Destroy everything (careful!)
make clean
```

### Local Testing with Docker

```bash
docker-compose up -d
# LocalStack starts on http://localhost:4566
```

## CI/CD Pipeline

### Trigger

- **Any branch push** → triggers DEV deployment
- **`main` branch push** → triggers DEV → (approval) → STAGING → (approval) → PROD

### Pipeline Stages

| Stage | Trigger | Approval Required | Notes |
|---|---|---|---|
| DEV | Any push | ❌ Auto | Runs `terraform plan` + `apply` |
| STAGING | main branch | ✅ Manual | Requires reviewer approval in GitHub |
| PROD | After staging | ✅ Manual | Blue/green swap with validation |

### Blue/Green Deployment (PROD)

The production environment runs two Lambda functions simultaneously:
- **`prod-hello-function-blue`** — the stable/current version
- **`prod-hello-function-green`** — the new deployment target

**Deployment Flow:**
1. Pipeline determines the current active slot (e.g., `blue`)
2. Deploys new code to the **inactive** slot (e.g., `green`)
3. Validates the new slot returns HTTP 200
4. Switches API Gateway to point to `green`
5. Old `blue` slot remains available for instant rollback

**API Responses:**
- Before swap: `{"message": "Hello from prod (Blue)!"}`
- After swap: `{"message": "Hello from prod (Green)!"}`

### Rollback

To roll back, re-run the pipeline with `active_slot=blue` (or the previous slot).

## API Endpoints

After deployment, each environment exposes:

```
GET https://<api-id>.execute-api.us-east-1.amazonaws.com/<env>/hello
```

**Expected Response (200 OK):**
```json
{"message": "Hello from dev (Blue)!"}
```

**Prod requires API Key:**
```bash
curl -H "x-api-key: YOUR_API_KEY" \
  https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/hello
```

## Monitoring & Observability

- **CloudWatch Log Groups**: `/aws/lambda/<env>-hello-function`
- **CloudWatch Alarm**: fires when Lambda errors > 0 for 5 minutes
- Log retention: 14 days

## Security

- ✅ Least-privilege IAM roles for Lambda
- ✅ API Key authentication on production
- ✅ No hardcoded secrets (all via GitHub Secrets / environment variables)
- ✅ Resource tagging: `Environment`, `Project`, `Owner`
- ✅ S3 backend with DynamoDB locking for safe concurrent Terraform runs

## Cleanup

```bash
make clean TF_STATE_BUCKET=your-bucket TF_LOCK_TABLE=your-table
```

Or via Terraform directly:
```bash
terraform -chdir=./terraform/environments/dev destroy -auto-approve
```
pipeline test
