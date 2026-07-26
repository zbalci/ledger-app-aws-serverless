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

clone_repository() {

    #
    # Already inside a Git repository
    #
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then

        local REPO_ROOT
        local REPO_URL

        REPO_ROOT=$(git rev-parse --show-toplevel)
        REPO_URL=$(git config --get remote.origin.url)

        if [[ "$REPO_URL" != "$REPOSITORY_URL" ]]; then

            error "Current directory belongs to a different Git repository."
            error "Repository : $REPO_URL"
            error "Expected   : $REPOSITORY_URL"
            exit 1

        fi

        info "Using existing repository."

        cd "$REPO_ROOT"

        return

    fi

    #
    # Repository exists in current directory
    #
    if [[ -d "$REPOSITORY_DIR/.git" ]]; then

        info "Using existing repository."

        cd "$REPOSITORY_DIR"

        return

    fi

    #
    # Clone repository
    #
    info "Cloning repository..."

    git clone "$REPOSITORY_URL"

    cd "$REPOSITORY_DIR"

    success "Repository cloned."

}

########################################
# Sync templates function
########################################

sync_templates() {

    if $DRY_RUN; then
        info "[PLAN] Upload CloudFormation templates"
        return
    fi

    local IAC_S3_URL

    IAC_S3_URL=$(get_ssm_parameter "/${APP_NAME}/iac_bucket_s3")

    info "Uploading CloudFormation templates..."

    aws s3 sync \
        infrastructure/cloudformation \
        "$IAC_S3_URL"

    success "Templates uploaded."
}

########################################
# Show nameserver function
########################################

show_nameservers() {

    if $DRY_RUN; then
        info "[PLAN] Would display Route53 Name Server records."
        return
    fi

    local HOSTED_ZONE_ID
    local NAME_SERVERS

    HOSTED_ZONE_ID=$(aws cloudformation describe-stacks \
        --stack-name "${APP_NAME}-global" \
        --query "Stacks[0].Outputs[?OutputKey=='HostedZoneId'].OutputValue" \
        --output text \
        --region "$AWS_REGION")

    NAME_SERVERS=$(aws route53 get-hosted-zone \
        --id "$HOSTED_ZONE_ID" \
        --query "DelegationSet.NameServers[]" \
        --output text \
        --region "$AWS_REGION")

    echo
    echo "=========================================================="
    echo " DNS Configuration Required"
    echo "=========================================================="
    echo
    echo "Domain:"
    echo "  ${ROOT_DOMAIN}"
    echo
    echo "Update the NS records at your domain registrar:"
    echo

    for ns in $NAME_SERVERS; do
        echo "  • $ns"
    done

    echo
    echo "After updating the records, DNS propagation may"
    echo "take a few minutes."
    echo
    read -rp "Press ENTER to continue..."
    echo
}

########################################
# Deploy stack function
########################################

deploy_stack() {

    local STACK_NAME="$1"
    local TEMPLATE="$2"

    shift 2

    #
    # Eğer kullanıcı "global", "foundation" veya "app"
    # gibi bir klasör adı verdiyse TemplateURL oluştur.
    #
    if [[ "$TEMPLATE" != *.yaml ]]; then
        TEMPLATE="$(get_ssm_parameter "/${APP_NAME}/iac_bucket_url")/${TEMPLATE}/stack.yaml"
    fi

    local TEMPLATE_OPTION

    if [[ "$TEMPLATE" =~ ^https?:// ]]; then
        TEMPLATE_OPTION="--template-url"
    else
        TEMPLATE_OPTION="--template-body"
        TEMPLATE="file://${TEMPLATE}"
    fi

    if $DRY_RUN; then
        info "[PLAN] Would deploy stack: ${STACK_NAME}"
        info "[PLAN] Template: ${TEMPLATE}"
        info "[PLAN] Parameters: $*"
        return 0
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

    if $DRY_RUN; then
        case "$1" in
            "/${APP_NAME}/iac_bucket_s3")
                echo "s3://dummy-iac-bucket"
                ;;
            "/${APP_NAME}/iac_bucket_url")
                echo "https://dummy-iac-bucket.s3.amazonaws.com"
                ;;
            "/${APP_NAME}/artifact_bucket_s3")
                echo "s3://dummy-artifact-bucket"
                ;;
            *)
                echo "<unknown>"
                ;;
        esac
        return 0
    fi

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

    if $DRY_RUN; then
        info "[PLAN] Skipping layer build."
        return
    else
        info "Building Lambda layer..."

    fi

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
    --help             Show this help (default)

    --all              Deploy everything 

    --bootstrap-only   Deploy bootstrap stack

    --global-only      Deploy global stack

    --foundation-only  Deploy foundation stack

    --app-only         Deploy application stack

    --skip-layer       Skip Lambda layer upload

    --dry-run          Print actions without executing

Examples:
    ./deploy.sh --all
    ./deploy.sh --all --dry-run
    ./deploy.sh --app-only
    ./deploy.sh --app-only --skip-layer

EOF

}

SHOW_HELP=true

DEPLOY_BOOTSTRAP=false
DEPLOY_GLOBAL=false
DEPLOY_FOUNDATION=false
DEPLOY_APP=false
BUILD_LAYER_ENABLED=false

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in

        --all)
            SHOW_HELP=false
            DEPLOY_BOOTSTRAP=true
            DEPLOY_GLOBAL=true
            DEPLOY_FOUNDATION=true
            DEPLOY_APP=true
            BUILD_LAYER_ENABLED=true
            ;;

        --bootstrap-only)
            SHOW_HELP=false
            DEPLOY_BOOTSTRAP=true
            ;;

        --global-only)
            SHOW_HELP=false
            DEPLOY_GLOBAL=true
            ;;

        --foundation-only)
            SHOW_HELP=false
            DEPLOY_FOUNDATION=true
            ;;

        --app-only)
            SHOW_HELP=false
            DEPLOY_APP=true
            BUILD_LAYER_ENABLED=true
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
            echo
            usage
            exit 1
            ;;

    esac

    shift
done

if $SHOW_HELP; then
    usage
    exit 0
fi

main() {

    clone_repository

    if $DEPLOY_BOOTSTRAP; then
        deploy_stack \
            "${APP_NAME}-bootstrap" \
            infrastructure/cloudformation/bootstrap/s3-iac.yaml \
            --parameters \
                ParameterKey=AppName,ParameterValue="$APP_NAME"
    fi

    #
    # Global/Foundation/App için template'leri yükle
    #
    if $DEPLOY_GLOBAL || \
       $DEPLOY_FOUNDATION || \
       $DEPLOY_APP; then

        sync_templates

    fi

    if $DEPLOY_GLOBAL; then

        deploy_stack \
            "${APP_NAME}-global" \
            global \
            --parameters \
                ParameterKey=AppName,ParameterValue="$APP_NAME" \
                ParameterKey=RootDomain,ParameterValue="$ROOT_DOMAIN"
        
        show_nameservers

    fi

    if $DEPLOY_FOUNDATION; then

        deploy_stack \
            "${APP_NAME}-foundation" \
            foundation \
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
            app \
            --disable-rollback \
            --parameters \
                ParameterKey=AppName,ParameterValue="$APP_NAME" \
                ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
                ParameterKey=RootDomain,ParameterValue="$ROOT_DOMAIN" \
                ParameterKey=GithubConnectionArn,ParameterValue="$GITHUB_CONNECTION_ARN" \
                ParameterKey=SourceRepo,ParameterValue="$SOURCE_REPO" \
                ParameterKey=SourceBranch,ParameterValue="$SOURCE_BRANCH"
    fi


    if $DRY_RUN; then
        info "[PLAN] Dry-run completed."
        return
    else
        echo
        success "Deployment completed successfully."
    fi

}

main "$@"