# Mao Quotes API - Enterprise SRE Practice Project

[![Python](https://img.shields.io/badge/Python-3.11-blue)](https://www.python.org/)
[![Docker](https://img.shields.io/badge/Docker-24.0-blue)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.30-blue)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.7-purple)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-orange)](https://aws.amazon.com/eks/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-green)](https://github.com/features/actions)

> A complete SRE practice project demonstrating enterprise-level DevOps workflows, from application development to CI/CD automation.

---

## Project Highlights

- **Complete Tech Stack**: Full DevOps lifecycle from app development to CI/CD
- **Production-Grade**: Enterprise VPC architecture, high availability, monitoring & alerting
- **Comprehensive Documentation**: 10,000+ lines of technical documentation
- **Real Cloud Deployment**: Hands-on AWS EKS production environment
- **Automated CI/CD**: Complete GitHub Actions workflows

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Actions                         │
│                   (CI/CD Automation)                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     AWS Cloud (EKS)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   VPC        │  │   ALB/NLB    │  │  CloudWatch  │      │
│  │ (3 AZs)      │  │              │  │   (Logs &    │      │
│  │ - Public     │  │              │  │   Metrics)   │      │
│  │ - Private    │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │            EKS Cluster (Kubernetes)                   │  │
│  │  ┌────────┐  ┌────────┐  ┌────────┐                  │  │
│  │  │  Pod   │  │  Pod   │  │  Pod   │  (HPA: 2-10)    │  │
│  │  │FastAPI │  │FastAPI │  │FastAPI │                  │  │
│  │  └────────┘  └────────┘  └────────┘                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────┐                                           │
│  │     ECR      │  (Container Registry)                     │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Terraform (IaC)                           │
│                Manages entire infrastructure                │
└─────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

### Application Layer
- **Backend**: Python 3.11 + FastAPI
- **Features**: Async API, health checks, structured logging, graceful shutdown

### Containerization
- **Docker**: Multi-stage builds, optimized images (600MB → 70MB)
- **Security**: Non-root user, read-only filesystem, vulnerability scanning

### Orchestration
- **Kubernetes**: Deployment, Service, HPA, ConfigMap/Secret
- **Features**: Rolling updates, zero-downtime deployment, auto-scaling

### Cloud Platform
- **AWS EKS**: Production-grade Kubernetes cluster
- **AWS ECR**: Container image registry
- **AWS VPC**: Enterprise network architecture (3 public + 3 private subnets across 3 AZs)
- **AWS Load Balancer**: NLB for high availability
- **AWS CloudWatch**: Logs, metrics, alarms, dashboards

### Monitoring & Observability
- **CloudWatch Logs Insights**: Complex log analysis
- **CloudWatch Metrics**: Custom application metrics
- **CloudWatch Alarms**: SLO-based alerting
- **Four Golden Signals**: Latency, traffic, errors, saturation

### Infrastructure as Code
- **Terraform**: Manage 60+ AWS resources with modules
- **Features**: Remote backend (S3 + DynamoDB), workspaces, drift detection

### CI/CD
- **GitHub Actions**: Complete automation pipeline
- **CI**: Linting, testing, Docker build, push to ECR
- **CD**: Auto-deploy to EKS, rollout verification, smoke tests
- **Rollback**: One-click rollback in 2 minutes

---

## Project Structure

```
sre-lab/
├── README.md                    # Project overview
│
├── docs/                        # Technical documentation
│   ├── 01-application-development.md
│   ├── 02-containerization.md
│   ├── 03-kubernetes-deployment.md
│   ├── 04-aws-cloud-deployment.md
│   ├── 05-monitoring-and-alerting.md
│   ├── 06-infrastructure-as-code.md
│   └── 07-cicd-automation.md
│
├── app/                         # FastAPI application
│   ├── main.py                  # Main application
│   ├── quotes.py                # Quote database
│   └── requirements.txt         # Python dependencies
│
├── docker/                      # Docker configuration
│   ├── Dockerfile               # Multi-stage build
│   └── .dockerignore            # Build context optimization
│
├── k8s/                         # Kubernetes manifests
│   ├── deployment.yaml          # Deployment config
│   ├── deployment-eks.yaml      # EKS-specific config
│   ├── service.yaml             # Service config
│   ├── hpa.yaml                 # Auto-scaling config
│   └── configmap.yaml           # Configuration management
│
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                  # Main configuration
│   ├── eks.tf                   # EKS cluster
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── backend.tf.example       # Remote backend example
│   └── workspace-example.tf     # Multi-environment example
│
└── .github/                     # CI/CD workflows
    ├── workflows/
    │   ├── ci.yml               # CI Pipeline
    │   ├── cd.yml               # CD Pipeline
    │   └── rollback.yml         # Rollback workflow
    └── CICD-SETUP.md            # CI/CD configuration guide
```

---

## Key Features & Achievements

### Infrastructure as Code
- Terraform manages 60+ AWS resources using official modules
- One-command infrastructure provisioning (15 minutes from zero to production)
- Enterprise VPC architecture with high availability across 3 AZs
- Remote backend with S3 + DynamoDB for team collaboration
- Workspace-based multi-environment management (dev/staging/prod)

### Container Optimization
- Docker image size reduced from 600MB to 70MB (88% reduction)
- Multi-platform builds (ARM64/AMD64) for Mac M1/M2/M3 compatibility
- Security hardening: non-root user, read-only filesystem
- Multi-stage builds for optimized layer caching

### Kubernetes & Auto-Scaling
- HPA (Horizontal Pod Autoscaler) for dynamic scaling (2-10 pods)
- Resource requests/limits for optimal utilization (Burstable QoS)
- Liveness/Readiness probes for self-healing and traffic control
- Rolling updates with zero downtime
- ConfigMap/Secret for configuration management

### Monitoring & SRE
- SLO-based monitoring (P95 latency < 200ms, availability > 99.9%)
- CloudWatch alarms for SLO violations
- Custom metrics and dashboards
- Google SRE Four Golden Signals implementation
- Comprehensive log aggregation and analysis

### CI/CD Automation
- Deployment time reduced from 30 minutes to 5 minutes (6x improvement)
- Automated code quality checks (Black, isort, Flake8)
- Automated testing and Docker builds
- Production environment approval workflow
- One-click rollback capability (2-minute recovery)
- Supports multiple daily releases

### Cost Optimization
- HPA auto-scaling saves 40% resource costs
- Single NAT Gateway in dev environment
- Right-sized instance types (t3.small for dev)
- ECR lifecycle policies for image retention

---

## Quick Start

### Prerequisites

- Python 3.11+
- Docker 24.0+
- kubectl 1.30+
- AWS CLI 2.x
- Terraform 1.7+ (for infrastructure)

### Local Development

```bash
# 1. Clone the repository
git clone https://github.com/<YOUR_USERNAME>/sre-lab.git
cd sre-lab

# 2. Install dependencies
pip install -r app/requirements.txt

# 3. Run the application
cd app
uvicorn main:app --reload

# 4. Test the API
curl http://localhost:8000/health
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Need encouragement"}'
```

### Docker Build & Run

```bash
# Build the image
docker build -t mao-quotes-api:v1 -f docker/Dockerfile .

# Run the container
docker run -p 8000:8000 mao-quotes-api:v1

# Test
curl http://localhost:8000/health
```

### Kubernetes Deployment (Local)

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check status
kubectl get pods
kubectl get svc

# Test the service
kubectl port-forward svc/mao-quotes-service 8080:80
curl http://localhost:8080/health
```

### Deploy to AWS EKS (with Terraform)

```bash
# 1. Configure AWS credentials
aws configure

# 2. Initialize Terraform
cd terraform
terraform init

# 3. Create EKS cluster
terraform plan
terraform apply  # Takes ~15 minutes

# 4. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name <CLUSTER_NAME>

# 5. Deploy application
kubectl apply -f k8s/deployment-eks.yaml

# 6. Get LoadBalancer URL
kubectl get svc mao-quotes-service

# 7. Test
curl http://<LOAD_BALANCER_URL>/health
```

---

## Documentation

Comprehensive documentation is available in the `docs/` directory:

1. **[Application Development](docs/01-application-development.md)**: FastAPI, async programming, health checks
2. **[Containerization](docs/02-containerization.md)**: Docker optimization, multi-stage builds
3. **[Kubernetes Deployment](docs/03-kubernetes-deployment.md)**: Pod, Deployment, Service, HPA
4. **[AWS Cloud Deployment](docs/04-aws-cloud-deployment.md)**: EKS, ECR, VPC, Load Balancer
5. **[Monitoring & Alerting](docs/05-monitoring-and-alerting.md)**: CloudWatch, SLO, Four Golden Signals
6. **[Infrastructure as Code](docs/06-infrastructure-as-code.md)**: Terraform, modules, remote backend
7. **[CI/CD Automation](docs/07-cicd-automation.md)**: GitHub Actions, automated deployment

---

## CI/CD Pipeline

### CI Pipeline (5 minutes)
```
Code Push → Lint (Black, isort, Flake8) → Test (pytest) → 
Build Docker → Push to ECR → Success
```

### CD Pipeline (3 minutes)
```
CI Success → Configure kubectl → Update Deployment → 
Rollout Verification → Health Checks → Smoke Tests → Success
```

### Rollback (2 minutes)
```
Manual Trigger → Confirm → Rollback Deployment → 
Verify Health → Success
```

See [CI/CD Setup Guide](.github/CICD-SETUP.md) for detailed configuration.

---

## Monitoring Dashboard

Key metrics tracked:

- **Latency**: P50, P95, P99 response times
- **Traffic**: Requests per second
- **Errors**: 4xx, 5xx error rates
- **Saturation**: CPU, memory, pod count

CloudWatch Alarms configured for:
- P95 latency > 200ms
- Error rate > 1%
- Pod availability < 3

---

## Project Highlights for Resume

**Key Achievements**:
- Implemented complete Infrastructure as Code with Terraform (60+ resources)
- Designed enterprise VPC architecture (3 public + 3 private subnets, 3 AZs)
- Optimized Docker images by 88% (600MB → 70MB)
- Reduced deployment time by 83% (30min → 5min with CI/CD)
- Achieved cost savings of 40% through HPA auto-scaling
- Built SLO monitoring system with automated alerting (P95 < 200ms)
- Implemented zero-downtime deployment with 2-minute rollback capability

**Technical Stack**: Python, FastAPI, Docker, Kubernetes, AWS (EKS/ECR/VPC/CloudWatch), Terraform, GitHub Actions

---

## License

MIT License - see [LICENSE](LICENSE) file for details

---

## Contact & Feedback

For questions or suggestions, please open an issue or contact via:
- GitHub Issues: https://github.com/<YOUR_USERNAME>/sre-lab/issues
- Email: your.email@example.com

---

## Acknowledgments

This project demonstrates enterprise-level SRE practices including:
- Google SRE principles (SLI/SLO/Error Budget)
- 12-Factor App methodology
- AWS Well-Architected Framework
- Kubernetes best practices
- Infrastructure as Code patterns

---

**Built with ❤️ for learning and practicing enterprise SRE skills**
