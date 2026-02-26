# IDP Portal / API Gateway (Thin)

## Features
- JWT auth with roles: `admin`, `developer`, `viewer`
- Service catalog CRUD (Postgres-backed) with required `tenant`
- Tenant-aware provisioning status tracking
- Self-serve actions: provision env, deploy, view status
- Simple web UI served from the same FastAPI app

## Docker Compose
```bash
docker compose up --build
```

Open `http://127.0.0.1:8000`.

If you are upgrading from the previous schema, remove the local volume to pick up new columns:
```bash
docker compose down -v
```

## Local (without Docker)
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Requires a running Postgres instance and a DB_URL
export DB_URL=postgresql+psycopg2://idp:idp@localhost:5432/idp
uvicorn app.main:app --reload
```

## Default users
- `admin` / `admin`
- `dev` / `dev`
- `viewer` / `viewer`

## API
- `POST /auth/login`
- `GET /services`
- `POST /services`
- `GET /services/{id}`
- `PUT /services/{id}`
- `DELETE /services/{id}`
- `POST /services/{id}/actions/provision`
- `POST /services/{id}/actions/deprovision`
- `POST /services/{id}/actions/deploy`
- `GET /services/{id}/actions/deploy/status`
- `GET /services/{id}/actions/status`
- `POST /services/deployments/callback`

## Provisioning (Step Functions)
Set `STEP_FUNCTION_ARN` and `AWS_REGION` to enable Step Functions execution on provision actions.
Also set `PROVISIONING_CALLBACK_TOKEN` and configure your worker to call:
`POST /provisioning/callback` with header `X-Callback-Token`.

### Worker
See `infra/provisioner/README.md` for the Terraform-based worker that runs in ECS/EKS and updates status.

## Deploy (Step Functions)
Set `DEPLOY_STEP_FUNCTION_ARN` (or fallback to `STEP_FUNCTION_ARN`) to enable deploy workflow execution.
Set `DEPLOYMENT_CALLBACK_TOKEN` and configure your deployment worker to call:
`POST /services/deployments/callback` with header `X-Callback-Token`.
Reference template: `infra/step-functions/deploy-state-machine.json`.

## AWS Deploy (ECS + ALB)
The Terraform stack in `infra/terraform/aws-bootstrap` can create:
- VPC, EKS, RDS
- ECS service + ALB for the app
- ECR repo for the app image

### GitHub Actions
Create the following GitHub Secrets in your repo:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `APP_ECR_REPO` (from Terraform output `app_ecr_repo`)
- `APP_ECS_CLUSTER` (from Terraform output `ecs_cluster`)
- `APP_ECS_SERVICE` (from Terraform output `app_ecs_service`)
- `APP_ECS_TASK_DEFINITION_FAMILY` (family name, e.g., `idp-poc-app`)

On `main` pushes, the workflow builds and deploys the app to ECS.
