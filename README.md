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
- `POST /services/{id}/actions/deploy`
- `GET /services/{id}/actions/status`

## Provisioning (Step Functions)
Set `STEP_FUNCTION_ARN` and `AWS_REGION` to enable Step Functions execution on provision actions.
Also set `PROVISIONING_CALLBACK_TOKEN` and configure your worker to call:
`POST /provisioning/callback` with header `X-Callback-Token`.

### Worker
See `infra/provisioner/README.md` for the Terraform-based worker that runs in ECS/EKS and updates status.
