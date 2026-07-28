# Ledger App – AWS Serverless

A production-style serverless application deployed entirely on AWS using Infrastructure as Code (CloudFormation). The project demonstrates a complete deployment workflow built around AWS Lambda, API Gateway, Cognito, DynamoDB, Route 53, ACM, CodePipeline, and CodeBuild.

The infrastructure is organized into modular nested CloudFormation stacks and can be provisioned or destroyed using a single deployment script. The project focuses on automation, repeatability, and maintainability, making it suitable as a reference implementation for modern serverless deployments.

![Ledger App](docs/diagrams/01-ledger-app.png)

## Highlights

- Fully serverless architecture built on AWS managed services
- Modular nested CloudFormation stacks
- One-command deployment and cleanup
- Automated custom domain configuration with Route 53 and ACM
- Secure authentication using Amazon Cognito
- REST API powered by API Gateway and AWS Lambda
- DynamoDB for scalable NoSQL data storage
- CI/CD pipeline using GitHub, CodePipeline and CodeBuild
- Shared Lambda Layer for dependency management
- Parameter Store integration for configuration sharing

## Architecture

The application follows a fully serverless architecture where authentication, API processing, and data persistence are provided entirely by managed AWS services.

The deployment separates shared infrastructure from application-specific resources through multiple CloudFormation stacks. This approach improves maintainability, enables independent updates, and simplifies environment provisioning.

![CloudFormation Stacks](docs/diagrams/02-cfn-stacks.png)

### Architecture Components

| Component | Purpose |
|-----------|---------|
| Route 53 | DNS hosting |
| ACM | SSL certificate management |
| API Gateway | Public REST API |
| Lambda | Business logic |
| Cognito | User authentication |
| DynamoDB | Persistent storage |
| S3 | Deployment artifacts |
| CloudFormation | Infrastructure provisioning |
| CodePipeline | Continuous deployment |
| CodeBuild | Application build process |

## Key Features

### Infrastructure

- Infrastructure as Code using nested CloudFormation stacks
- Modular stack organization
- Automated stack dependency management
- Environment-specific configuration
- Shared resources isolated from application resources

### Deployment

- Single-command deployment
- Partial deployment support
- Dry-run mode
- Automatic template synchronization
- Bootstrap resource provisioning

### Application

- JWT authentication with Amazon Cognito
- REST API using API Gateway
- Stateless Lambda functions
- Shared Lambda Layer
- DynamoDB persistence

![App Flow](docs/diagrams/05-app-flow.png)

### CI/CD

- GitHub integration
- Automated CloudFormation deployments
- Automated Lambda packaging
- Continuous delivery through CodePipeline

![Pipeline Flow](docs/diagrams/03-pipeline-flow.png)

<p align="center"> <img width="700" height="295" src="docs/diagrams/04-build-detail.png"> </p>

---

## Deployment Workflow

The entire infrastructure can be provisioned using a single deployment script.

The deployment process is divided into multiple logical stages. Each stage is responsible for provisioning a specific layer of the infrastructure while respecting stack dependencies.

```mermaid
flowchart TD
    A[deploy.sh] --> B[Bootstrap]
    B --> C[Upload CloudFormation Templates]
    C --> D[Global Stack]
    D --> E[Foundation Stack]
    E --> F[Application Stack]
    F --> G[Deployment Complete]
```

## Deployment Options

The deployment script supports both full and partial deployments.

| Option | Description |
|---------|-------------|
| `--all` | Deploy the complete infrastructure |
| `--bootstrap-only` | Deploy only the bootstrap stack |
| `--global-only` | Deploy only shared global resources |
| `--foundation-only` | Deploy only the foundation layer |
| `--app-only` | Deploy only the application stack |
| `--skip-layer` | Skip Lambda Layer deployment |
| `--dry-run` | Print commands without executing them |
| `--help` | Display available options |

## Examples

Deploy the entire infrastructure:

```bash
./deploy.sh --all
```

Deploy only shared infrastructure:

```bash
./deploy.sh --global-only
```

Deploy only the application:

```bash
./deploy.sh --app-only
```

Preview the deployment:

```bash
./deploy.sh --all --dry-run
```

## Destroy Workflow

The infrastructure can be removed using the companion destroy script.

Resources are deleted in reverse dependency order to avoid CloudFormation failures.

```mermaid
flowchart TD
    A[destroy.sh]
    A --> B[Application Stack]
    B --> C[Foundation Stack]
    C --> D[Global Stack]
    D --> E[Bootstrap Stack]
    E --> F[Cleanup Complete]
```

During cleanup the script automatically:

- Deletes application resources first
- Removes shared infrastructure
- Empties S3 buckets when required
- Deletes the bootstrap resources
- Removes deployment artifacts
- Cleans up SSM parameters created during deployment
- Removes Route 53 validation and alias records to enable hosted zone deletion

---

## CloudFormation Stack Organization

The infrastructure is organized into multiple nested CloudFormation stacks. Each layer has a well-defined responsibility and depends only on the resources it requires.

```mermaid
flowchart TD
    A[Bootstrap] --> B[Global]
    B --> C[Foundation]
    C --> D[Application]
```

| Stack | Responsibility |
|--------|----------------|
| **Bootstrap** | Creates deployment buckets and shared parameters required for the deployment process. |
| **Global** | Deploys shared infrastructure such as Route 53, ACM certificates, and DNS configuration. |
| **Foundation** | Deploys shared application services including Cognito, DynamoDB, IAM resources, and the Lambda Layer. |
| **Application** | Deploys Lambda functions, API Gateway, custom domain mapping, and application-specific resources. |

---

## Repository Structure

```text
.
├── cloudformation/
│   ├── bootstrap/
│   ├── global/
│   ├── foundation/
│   └── application/
│
├── lambda/
│   ├── layer/
│   └── functions/
│
├── scripts/
│
├── deploy.sh
├── destroy.sh
└── README.md
```

The repository separates infrastructure, application code, and deployment automation to keep the project modular and easy to maintain.

---

## Prerequisites

Before deploying the project, ensure the following requirements are met:

- AWS CLI v2
- An AWS account with sufficient permissions
- Git
- Bash (Linux or macOS)
- Python 3.x (if required for Lambda packaging)

---

## Quick Start

Clone the repository:

```bash
git clone https://github.com/zbalci/ledger-app-aws-serverless.git
cd ledger-app-aws-serverless
```

Deploy the complete infrastructure:

```bash
./deploy.sh --all
```

Destroy all deployed resources:

```bash
./destroy.sh
```
---

## Continuous Integration and Deployment

The project includes an AWS-native CI/CD pipeline built with CodePipeline and CodeBuild.

The pipeline automatically:

- Retrieves the latest source code from GitHub
- Builds and packages Lambda functions
- Uploads deployment artifacts
- Updates CloudFormation stacks
- Deploys the latest application version

---

### Summary

This project is designed as a **realistic AWS Serverless portfolio**:

* Modular CloudFormation design
* Environment‑aware deployments
* Production‑grade CI/CD patterns
* Clean separation of concerns

It aims to reflect how serverless systems are typically structured in real‑world environments rather than minimal demos.

* Keeps application logic simple and auditable
* Emphasizes reproducibility, security, and clarity

It is not a framework or a product, but a **reference implementation** for serverless delivery pipelines.
