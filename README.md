# Ledger App – AWS Serverless

A production-style serverless application deployed entirely on AWS using Infrastructure as Code (CloudFormation). The project demonstrates a complete deployment workflow built around AWS Lambda, API Gateway, Cognito, DynamoDB, Route 53, ACM, CodePipeline, and CodeBuild.

The infrastructure is organized into modular nested CloudFormation stacks and can be provisioned or destroyed using a single deployment script. The project focuses on automation, repeatability, and maintainability, making it a reference implementation for modern AWS serverless deployments.

![Ledger App](docs/diagrams/01-ledger-app.png)

---

## Highlights

- Fully serverless architecture built on AWS managed services
- Infrastructure as Code with modular nested CloudFormation stacks
- One-command deployment and cleanup
- Partial deployment support and dry-run mode
- Custom domain provisioning with Route 53 and ACM
- Amazon Cognito authentication
- REST API powered by API Gateway and AWS Lambda
- DynamoDB persistence
- Shared Lambda Layer for dependency management
- AWS-native CI/CD using GitHub, CodePipeline, and CodeBuild

---

## Prerequisites

Before deploying the project, ensure you have:

- AWS CLI v2
- An AWS account with sufficient permissions
- Git
- Bash (Linux or macOS)
- Python 3.x (required for Lambda packaging)

---

## Quick Start

Clone the repository:

```bash
git clone https://github.com/zbalci/ledger-app-aws-serverless.git
cd ledger-app-aws-serverless
```

Deploy the complete infrastructure:

```bash
./scripts/deploy.sh --all
```

To remove all deployed resources:

```bash
./scripts/destroy.sh --all
```

---

## Repository Structure

```text
.
├── cloudformation/
│   ├── bootstrap/
│   ├── global/
│   ├── foundation/
│   └── application/
├── lambda/
│   ├── layer/
│   └── functions/
├── scripts/
│   ├── deploy.sh
│   └── destroy.sh
└── README.md
```

---

## Architecture

The application follows a fully serverless architecture where authentication, API processing, and data persistence are provided entirely by managed AWS services.

![App Flow](docs/diagrams/05-app-flow.png)

Infrastructure is separated into four logical CloudFormation layers, allowing independent updates, reusable components, and clean dependency management.

![CloudFormation Stacks](docs/diagrams/02-cfn-stacks.png)

| Stack | Responsibility |
|--------|----------------|
| **Bootstrap** | Creates deployment buckets and shared parameters required by the deployment process. |
| **Global** | Deploys Route 53 |
| **Foundation** | Deploys ACM certificate, creates log groups and artifact bucket |
| **Application** | Deploys API Gateway, Lambda, DynamoDB, Cognito, CodeBuild, CodePipeline, IAM resources and application resources. |

---

## Deployment

Deploy the complete infrastructure:

```bash
./scripts/deploy.sh --all
```

The deployment script supports both full and partial deployments.

| Option | Description |
|---------|-------------|
| `--all` | Deploy the complete infrastructure |
| `--bootstrap-only` | Deploy only the bootstrap stack |
| `--global-only` | Deploy only shared resources |
| `--foundation-only` | Deploy only the foundation layer |
| `--app-only` | Deploy only the application stack |
| `--skip-layer` | Skip Lambda Layer deployment |
| `--dry-run` | Preview commands without executing them |
| `--help` | Display available options |

### Examples

```bash
# Deploy only shared infrastructure
./scripts/deploy.sh --global-only

# Deploy only the application
./scripts/deploy.sh --app-only

# Preview the deployment
./scripts/deploy.sh --all --dry-run
```

---

## Destroy

Destroy the complete infrastructure:

```bash
./scripts/destroy.sh --all
```

Preview the destroy process:

```bash
./scripts/destroy.sh --all --dry-run
```

Resources are removed in reverse dependency order. During cleanup the script also:

- Empties deployment buckets
- Removes deployment artifacts
- Cleans up SSM parameters
- Removes Route 53 validation and alias records when required to enable hosted zone deletion

---

## Continuous Integration and Deployment

The project includes an AWS-native CI/CD pipeline built with CodePipeline and CodeBuild.

The pipeline automatically:

- Retrieves the latest source code from GitHub
- Packages Lambda functions
- Uploads deployment artifacts
- Updates CloudFormation stacks
- Deploys the latest application version

![Pipeline Flow](docs/diagrams/03-pipeline-flow.png)

<p align="center">
  <img width="700" src="docs/diagrams/04-build-detail.png">
</p>

---

## Summary

This project demonstrates a production-style AWS serverless deployment featuring:

- Modular CloudFormation architecture
- Environment-aware infrastructure
- Automated deployment and teardown
- AWS-native CI/CD
- Clear separation between infrastructure and application code

Rather than being a framework or a production application, it serves as a reference implementation that showcases automation, maintainability, and real-world serverless deployment practices.
