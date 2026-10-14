# AWS ECS Microservices CI/CD

This repository demonstrates a small microservices application deployed to Amazon ECS with CI/CD automation using GitHub Actions and Terraform. The sample app is intentionally simple: several Node.js services expose CRUD APIs, a frontend aggregates data from them, and the platform wiring shows how to build, tag, publish, and deploy container images to ECS.

It combines:

- A local Docker Compose environment for development and validation
- Terraform modules for provisioning the ECS/VPC/ALB/IAM/ECR infrastructure
- GitHub Actions workflows to build images in ECR and deploy them to ECS
- Sidecar, init-container, and scheduled-job patterns commonly used in containerized workloads

## Architecture overview

```text
Internet
  |
  v
  ALB / ECS services
  |
  +---------------------------+
  |                           |
  v                           v
frontend                   orders-service
  |                           |
  |---> users-service         |---> users-service
  |---> products-service      |---> products-service
  |
  +---> dashboard aggregates data from all backend services

Additional patterns in the repo:
- sidecar-logger attached to the orders task
- init-check container waits for dependencies before app startup
- cron-report runs as a short-lived scheduled job
```

## Services

The application is composed of these services under `services/`:

- `users-service`: in-memory user catalog API on port 4001
- `products-service`: in-memory product catalog API on port 4002
- `orders-service`: orchestrates orders by calling `users-service` and `products-service`, exposed on port 4003
- `frontend`: BFF-style UI and API layer on port 4000
- `sidecar-logger`: polls the main app health endpoint and logs status
- `init-check`: waits until dependencies are healthy before main app startup
- `cron-report`: short-lived job that fetches orders and prints a summary

Each service has its own Dockerfile and a minimal Node.js package manifest.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml            # Build and push Docker images to ECR
│       └── cd.yaml           # Deploy built images to ECS services
├── ECS/
│   ├── child-module/         # Reusable Terraform modules
│   └── root-module/          # Top-level Terraform composition
├── services/
│   ├── cron-report/
│   ├── frontend/
│   ├── init-check/
│   ├── orders-service/
│   ├── products-service/
│   ├── sidecar-logger/
│   └── users-service/
├── questions/
│   ├── docs/
│   ├── images/
│   └── *.md                 # AWS ECS / CI/CD notes and Q&A content
├── docker-compose.yml        # Local orchestration for sanity checks
├── .gitignore
├── README.md                 # This file
└── ...
```

## Local development

This repo includes a Docker Compose file to run the stack locally.

### Prerequisites

- Docker Engine / Docker Desktop
- Docker Compose v2
- Node.js (optional, only if you want to work on the services directly)

### Start the stack

```bash
docker compose up --build
```

Then open:

- Frontend: http://localhost:4000
- Users service: http://localhost:4001/users
- Products service: http://localhost:4002/products
- Orders service: http://localhost:4003/orders

### Run the cron job manually

```bash
docker compose run --rm cron-report
```

This is a local simulation of a scheduled report task that calls the orders API and prints revenue information.

## CI/CD flow

### CI workflow: `Build and Push Images to ECR`

The workflow in `.github/workflows/ci.yml`:

- checks out the selected branch
- logs in to Amazon ECR
- builds each microservice image with Docker Buildx
- pushes an image tagged with the Git commit SHA
- avoids rebuilding identical images when the same SHA was already pushed

### CD workflow: `Deploy Images to ECS`

The workflow in `.github/workflows/cd.yaml`:

- triggers after the CI workflow succeeds or can be run manually
- resolves the correct image tag to deploy
- downloads the current ECS task definition
- patches the relevant container images in the task definitions
- updates the ECS services and verifies the deployed revision is primary

The deployment matrix includes:

- `products-service`
- `users-service`
- `orders-service`
- `frontend`
- `cron-report`

## Terraform infrastructure

The `ECS/` folder contains a modular Terraform design.

- `ECS/root-module/` composes the application environment using child modules
- child modules include VPC, security groups, IAM, ECR, cluster, task definitions, ALB, services, and cron scheduler setup

The root module wires together:

```hcl
module "VPC" { ... }
module "Security_Group" { ... }
module "IAM" { ... }
module "ECR" { ... }
module "ECS_cluster" { ... }
module "ECS_task_definition" { ... }
module "ECS_service" { ... }
module "ALB" { ... }
module "ECS_cron_scheduler" { ... }
```

Core required variables are defined in `ECS/root-module/variable.tf`:

- `vpc_cidr`
- `public_subnet_cidrs`
- `azs`
- `project_name`
- `aws_region`
- `image_tag`
- `cron_schedule_expression`

This makes the repo suitable as a reference for infrastructure-as-code patterns around a multi-service ECS workload.

## Example runtime behavior

The runtime flow is intentionally simple but realistic:

1. `frontend` exposes the browser-facing API and dashboard
2. Frontend calls the downstream microservices over HTTP
3. `orders-service` enriches order data by fetching users and products from other services
4. `users-service` and `products-service` maintain in-memory data stores
5. `sidecar-logger` monitors health of the `orders-service` task
6. `init-check` can gate a task until dependencies are ready
7. `cron-report` can run periodically or on demand to generate a report

## Notes

- These services intentionally use in-memory state. They are designed for learning and demos, not production persistence.
- The repo includes question-and-answer material in `questions/` to explain ECS concepts, deployment strategies, and common CI/CD concerns.
- Some documentation and comments mention both ECS and EKS patterns, showing the same application design can be adapted across orchestrators.

## Suggested next steps

If you want to extend the project, common next improvements are:

- add persistent storage (RDS, DynamoDB, or Redis)
- add health checks and retries for inter-service calls
- add Terraform variables and outputs for environment-specific configuration
- add production-grade observability with CloudWatch, X-Ray, or OpenTelemetry
- add automated end-to-end tests for the frontend and service APIs

## License

No explicit license file is included in this repository. Use this project as a reference/example for learning, demos, and internal experimentation unless otherwise specified by the repository owner.
