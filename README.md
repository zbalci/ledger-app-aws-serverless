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
| **Bootstrap** | Creates the deployment buckets and shared parameters required by the deployment process. |
| **Global** | Creates the root Route 53 hosted zone used to manage DNS records for all environments (for example, dev and prod). |
| **Foundation** | Provisions shared infrastructure, including the ACM certificate, CloudWatch log groups, and deployment artifact bucket. |
| **Application** | Deploys the application resources, including API Gateway, Lambda, DynamoDB, Cognito, IAM resources, CodeBuild, CodePipeline, and environment-specific DNS records. |

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

The project includes two independent AWS-native CI/CD pipelines built with CodePipeline and CodeBuild:

- **Layer Pipeline** monitors changes under `src/layers/*`, builds and publishes a new Lambda Layer version, then updates the latest Layer ARN in AWS Systems Manager Parameter Store.
- **Function Pipeline** monitors changes under `src/web/*`, retrieves the latest Layer ARN from Parameter Store, packages the application, and deploys a new Lambda Function version.

This separation allows Lambda Layers and application code to be released independently while ensuring that function deployments always reference the latest compatible layer.

![Pipeline Flow](docs/diagrams/03-pipeline-flow.png)

### Build Pipeline Details

Each pipeline includes automated quality and security checks before deployment.

The **Function Pipeline** builds the application, runs unit and integration tests, performs static code analysis with **Bandit**, scans dependencies with **Trivy**, and deploys the updated Lambda function.

The **Layer Pipeline** builds the shared Lambda Layer, audits Python dependencies with **pip-audit**, performs vulnerability scanning with **Trivy**, publishes a new layer version, and generates a Software Bill of Materials (SBOM) stored in Amazon S3.

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
