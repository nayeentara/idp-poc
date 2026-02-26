# Observability Stack (Local)

This starts a local OpenTelemetry Collector + Prometheus + Grafana stack.

## Start

```bash
cd infra/observability
docker compose up -d
```

## Endpoints

- OTel Collector OTLP gRPC: `http://localhost:4317`
- OTel Collector OTLP HTTP: `http://localhost:4318`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000` (`admin` / `admin`)

## Notes

- Configure IDP API with:
  - `OBSERVABILITY_GRAFANA_URL=http://localhost:3000`
  - `OBSERVABILITY_GRAFANA_DASHBOARD_UID=<your-dashboard-uid>`
- Add a Grafana dashboard with variable `service` so IDP links can filter by service.
