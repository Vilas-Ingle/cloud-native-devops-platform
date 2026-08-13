# Application Architecture

## 1. Application Overview

The Cloud-Native DevOps Platform uses a small web application as its workload.

The application is designed to provide a realistic workload for demonstrating:

- Containerization
- CI/CD
- Kubernetes deployment
- Infrastructure as Code
- Configuration management
- Monitoring
- Logging
- Security
- Operational practices

The application itself is intentionally kept simple so that the primary focus remains on the DevOps platform.

---

## 2. Application Architecture

The initial application consists of three components:

```
                 User
                   |
                   v
              Frontend
                React
                   |
                   | HTTP/REST
                   v
             Backend API
              Node.js
              Express
                   |
                   | SQL
                   v
              PostgreSQL

```


---

## 3. Frontend

The frontend provides a simple web interface for interacting with the application.

Responsibilities include:

- Displaying application data
- Calling backend APIs
- Handling basic user interactions
- Providing a user-facing health/status indication

The frontend communicates with the backend through HTTP/REST APIs.

The frontend does not communicate directly with PostgreSQL.

---

## 4. Backend API

The backend provides the application's REST API.

Technology:

- Node.js
- Express

Initial responsibilities include:

- Serving REST APIs
- Validating incoming requests
- Reading and writing application data
- Providing health-check endpoints
- Handling application configuration
- Exposing application metrics where appropriate

Initial API endpoints:

```
GET /health
GET /api/products
POST /api/products
GET /api/orders
POST /api/orders

```
## 5. Database

PostgreSQL is used as the relational database.

Initial entities:

- products
- orders

The database is responsible for persistent application data.

The backend is the only application component that directly communicates with PostgreSQL.

Database credentials and connection configuration must not be hardcoded in application source code.

## 6. Local Development Architecture

Local development will use Docker Compose.

```

Docker Compose
│
├── frontend
├── backend
└── postgres


Communication:

Browser
   |
   v
Frontend Container
   |
   v
Backend Container
   |
   v
PostgreSQL Container

```
Docker Compose will provide:

- Container networking
- Environment configuration
- Local service discovery
- Database persistence
- Reproducible local development

---

## 7. Containerization Strategy

Each application component will be independently containerized.

```
Frontend
   |
   v
Docker Image
   |
   v
Amazon ECR


Backend
   |
   v
Docker Image
   |
   v
Amazon ECR

```

The PostgreSQL container will primarily support local development.

Production database architecture will be evaluated separately.

Container images should:

- Use appropriate base images
- Minimize unnecessary packages
- Run as a non-root user where practical
- Define a predictable startup command
- Support health checks
- Avoid embedding secrets
- Be versioned using immutable image tags

---

## 8. AWS / Kubernetes Target Architecture

The target AWS deployment will use Amazon EKS.

```
                        Internet
                           |
                           v
                    Application Load
                       Balancer
                           |
                           v
                    Amazon EKS
                           |
              +------------+------------+
              |                         |
              v                         v
        Frontend Pods              Backend Pods
                                      |
                                      v
                                  PostgreSQL

```

The exact production database architecture will be determined during the infrastructure phase.

---

## 9. Kubernetes Deployment

The application will be deployed using Kubernetes resources.

Planned resources include:

- Namespace
- Deployment
- Service
- Ingress
- ConfigMap
- Secret integration
- ServiceAccount where required
- HorizontalPodAutoscaler where appropriate

Workloads will include:

- frontend Deployment
- backend Deployment

The database deployment strategy will be determined separately.

---

## 10. Application Configuration

Application configuration will be separated from application code.

Examples include:

- PORT
- DATABASE_HOST
- DATABASE_PORT
- DATABASE_NAME
- DATABASE_USER
- DATABASE_PASSWORD
- API_BASE_URL

Sensitive configuration must not be committed to Git.

The project will evaluate:

- Kubernetes ConfigMaps
- Kubernetes Secrets
- AWS Secrets Manager
- AWS SSM Parameter Store

based on the sensitivity and lifecycle of each configuration value.

---

## 11. Health Checks

The backend will provide:

GET /health

The endpoint will be used by:

- Docker health checks
- Kubernetes liveness/readiness probes
- Deployment verification
- Monitoring

The health endpoint should provide a lightweight response without performing expensive database operations unless a separate readiness check requires database validation.

---

## 12. Observability

The application and platform will be designed to support observability.

Metrics

Prometheus will be used for metrics collection.

Potential application metrics include:

- Request count
- Request latency
- HTTP error count
- Application process health

Visualization

Grafana will provide dashboards for application and Kubernetes metrics.

AWS Monitoring

CloudWatch will be used for appropriate AWS infrastructure and logging requirements.

Alerting

SNS will be used for operational notifications where appropriate.

## 13. Security Boundaries

The application architecture follows these boundaries:

Internet
   |
   v
Application Load Balancer
   |
   v
Kubernetes Services
   |
   v
Application Pods
   |
   v
Database


Security responsibilities include:

- IAM least privilege
- Kubernetes RBAC where required
- Secure secret management
- Network access controls
- Container security
- Image vulnerability scanning
- TLS where required
- No credentials stored in source control

## 14. Development to Production Flow

The intended application lifecycle is:

Developer
   |
   v
GitHub
   |
   v
GitHub Actions
   |
   +--> Test
   |
   +--> Build
   |
   +--> Security Scan
   |
   +--> Container Image
   |
   v
Amazon ECR
   |
   v
Jenkins
   |
   v
Helm
   |
   v
Amazon EKS
   |
   v
Application

---

## 15. Design Decisions

### Why a three-component application?

A frontend, backend, and database provide enough complexity to demonstrate:

- Multi-container development
- Service-to-service communication
- Container networking
- CI/CD
- Kubernetes deployment
- Configuration management
- Secrets
- Monitoring

while keeping the application itself small enough that the DevOps platform remains the primary focus.

### Why React + Node.js + PostgreSQL?

This combination provides:

- Clear separation between presentation, API, and persistence
- Straightforward containerization
- Good Docker Compose support
- A realistic workload for Kubernetes
- A practical environment for CI/CD and observability

### Why not start with microservices?

The initial application does not require multiple independent backend services.

Starting with a small multi-container application keeps operational complexity manageable while still providing a realistic workload.

Microservices introduce additional concerns such as:

- Service discovery
- Inter-service communication
- Distributed tracing
- Independent deployments
- More complex monitoring
- Increased infrastructure cost

We will introduce additional services only when there is a genuine engineering requirement.

### Why use PostgreSQL locally?

PostgreSQL will initially run as a Docker Compose service for local development.

This provides:

- Reproducible development
- Simple local setup
- No dependency on AWS during application development
- Easy database lifecycle management

The production database architecture will be evaluated separately based on operational requirements and cost.

---

## 16. Future Evolution

The architecture may evolve as platform requirements increase.

Potential future improvements include:

- Redis caching
- Background workers
- Message queues
- Additional backend services
- Distributed tracing
- Horizontal autoscaling
- Advanced deployment strategies
- Managed PostgreSQL
- Multi-environment deployment

These components will only be introduced when they provide a meaningful engineering use case.
