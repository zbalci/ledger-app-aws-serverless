#!/usr/bin/env bash

set -Eeuo pipefail

########################################
# Configuration
########################################

APP_NAME="ledger"
ENVIRONMENT="dev"
AWS_REGION="eu-north-1"

ROOT_DOMAIN="aws.zbalci.com"

GITHUB_CONNECTION_ARN="arn:aws:codeconnections:eu-north-1:253712034003:connection/2c02ecd9-b115-4cec-967f-a0e4445ecfaa"

SOURCE_REPO="zbalci/ledger-app-aws-serverless"
SOURCE_BRANCH="main"

REPOSITORY_URL="git@github.com:zbalci/ledger-app-aws-serverless.git"
REPOSITORY_DIR="ledger-app-aws-serverless"

########################################
# Colors
########################################

GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

########################################
# Helper functions
########################################

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

trap 'error "Deployment failed on line $LINENO."' ERR

########################################
# Clone repo function
########################################

# clone_repository() {

#     if [[ ! -d "$REPOSITORY_DIR" ]]; then

#         info "Cloning repository..."

#         git clone "$REPOSITORY_URL"

#         success "Repository cloned."

#     else

#         warn "Repository already exists."

#     fi

#     cd "$REPOSITORY_DIR"
# }

########################################
# Deploy stack Function
########################################

deploy_stack() {

    local STACK_NAME="$1"
    local TEMPLATE="$2"

    shift 2

    local TEMPLATE_OPTION

    if [[ "$TEMPLATE" =~ ^https?:// ]]; then
        TEMPLATE_OPTION="--template-url"
    else
        TEMPLATE_OPTION="--template-body"
        TEMPLATE="file://${TEMPLATE}"
    fi

    info "Deploying stack: ${STACK_NAME}"

    if aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        >/dev/null 2>&1
    then

        info "Updating existing stack..."

        if ! UPDATE_OUTPUT=$(
            aws cloudformation update-stack \
                --stack-name "$STACK_NAME" \
                "$TEMPLATE_OPTION" "$TEMPLATE" \
                --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
                "$@" \
                --region "$AWS_REGION" \
                2>&1
        ); then

            if [[ "$UPDATE_OUTPUT" == *"No updates are to be performed."* ]]; then
                info "No changes detected."

            else
                error "Update failed."
                echo "$UPDATE_OUTPUT"
                exit 1
            fi

        else

            aws cloudformation wait stack-update-complete \
                --stack-name "$STACK_NAME" \
                --region "$AWS_REGION"

            success "Stack updated."

        fi

    else

        info "Creating new stack..."

        aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            "$TEMPLATE_OPTION" "$TEMPLATE" \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
            "$@" \
            --region "$AWS_REGION"

        aws cloudformation wait stack-create-complete \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION"

        success "Stack created."

    fi
}

########################################
# Get SSM Parameter Function
########################################

get_ssm_parameter() {

    aws ssm get-parameter \
        --name "$1" \
        --query "Parameter.Value" \
        --output text \
        --region "$AWS_REGION"
}

########################################
# Build Layer Function
########################################

build_layer() {

    info "Building Lambda layer..."

    bash scripts/build-layer.sh

    local ARTIFACTS_BUCKET

    ARTIFACTS_BUCKET=$(get_ssm_parameter "/${APP_NAME}/artifact_bucket_s3")

    aws s3 cp \
        layer.zip \
        "${ARTIFACTS_BUCKET}/bootstrap/layer.zip"

    success "Layer uploaded."
}

usage() {

cat << EOF

Usage:

    ./deploy.sh [option]

Options

    --all              Deploy everything (default)

    --bootstrap-only   Deploy bootstrap stack

    --global-only      Deploy global stack

    --foundation-only  Deploy foundation stack

    --app-only         Deploy application stack

    --skip-layer       Skip Lambda layer upload

    --dry-run          Print actions without executing

    --help             Show this help

EOF

}


DRY_RUN=false

run() {

    if $DRY_RUN; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi

}

DEPLOY_BOOTSTRAP=true
DEPLOY_GLOBAL=true
DEPLOY_FOUNDATION=true
DEPLOY_APP=true
BUILD_LAYER_ENABLED=true

while [[ $# -gt 0 ]]; do
    case "$1" in

        --bootstrap-only)
            DEPLOY_GLOBAL=false
            DEPLOY_FOUNDATION=false
            DEPLOY_APP=false
            ;;

        --global-only)
            DEPLOY_BOOTSTRAP=false
            DEPLOY_FOUNDATION=false
            DEPLOY_APP=false
            ;;

        --foundation-only)
            DEPLOY_BOOTSTRAP=false
            DEPLOY_GLOBAL=false
            DEPLOY_APP=false
            ;;

        --app-only)
            DEPLOY_BOOTSTRAP=false
            DEPLOY_GLOBAL=false
            DEPLOY_FOUNDATION=false
            ;;

        --skip-layer)
            BUILD_LAYER_ENABLED=false
            ;;

        --dry-run)
            DRY_RUN=true
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;

    esac

    shift
done

main() {

    # clone_repository

    if $DEPLOY_BOOTSTRAP; then

        deploy_stack \
            "${APP_NAME}-bootstrap" \
            infrastructure/cloudformation/bootstrap/s3-iac.yaml \
            --parameters \
                ParameterKey=AppName,ParameterValue="$APP_NAME"

    fi

    IAC_S3_URL=$(get_ssm_parameter "/${APP_NAME}/iac_bucket_s3")
    IAC_HTTP_URL=$(get_ssm_parameter "/${APP_NAME}/iac_bucket_url")

    run aws s3 sync infrastructure/cloudformation "$IAC_S3_URL"

    if $DEPLOY_GLOBAL; then

        deploy_stack \
            "${APP_NAME}-global" \
            "${IAC_HTTP_URL}/global/stack.yaml" \
            --parameters \
                ParameterKey=AppName,ParameterValue="$APP_NAME" \
                ParameterKey=RootDomain,ParameterValue="$ROOT_DOMAIN"
    fi

    if $DEPLOY_FOUNDATION; then

        deploy_stack \
            "${APP_NAME}-foundation" \
            "${IAC_HTTP_URL}/foundation/stack.yaml" \
            --parameters \
                ParameterKey=AppName,ParameterValue="$APP_NAME" \
                ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
                ParameterKey=RootDomain,ParameterValue="$ROOT_DOMAIN"
    fi

    if $BUILD_LAYER_ENABLED; then

        build_layer

    fi

    if $DEPLOY_APP; then

        deploy_stack \
            "${APP_NAME}-app" \
            "${IAC_HTTP_URL}/app/stack.yaml" \
            --disable-rollback \
            --parameters \
                ParameterKey=AppName,ParameterValue="$APP_NAME" \
                ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
                ParameterKey=RootDomain,ParameterValue="$ROOT_DOMAIN" \
                ParameterKey=GithubConnectionArn,ParameterValue="$GITHUB_CONNECTION_ARN" \
                ParameterKey=SourceRepo,ParameterValue="$SOURCE_REPO" \
                ParameterKey=SourceBranch,ParameterValue="$SOURCE_BRANCH"
    fi

    echo
    success "Deployment completed successfully."

}

main "$@"