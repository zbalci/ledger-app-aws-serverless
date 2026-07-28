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
# Destroy functions
########################################

delete_stack() {

    local STACK_NAME="$1"

    if $DRY_RUN; then
        info "[PLAN] Would delete stack: ${STACK_NAME}"
        return
    fi

    if ! aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" >/dev/null 2>&1; then

        warn "Stack '${STACK_NAME}' does not exist."
        return

    fi

    info "Deleting stack: ${STACK_NAME}"

    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION"

    if ! aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION"; then

        error "Failed to delete stack '${STACK_NAME}'."

        aws cloudformation describe-stack-events \
            --stack-name "$STACK_NAME" \
            --max-items 10 \
            --region "$AWS_REGION"

        exit 1
    fi

    success "Stack deleted."

}

empty_bucket() {

    local BUCKET="$1"

    if $DRY_RUN; then
        info "[PLAN] Would empty bucket: ${BUCKET}"
        return
    fi

    if ! aws s3api head-bucket \
        --bucket "${BUCKET#s3://}" \
        >/dev/null 2>&1; then

        warn "Bucket '${BUCKET}' does not exist."
        return

    fi

    info "Emptying bucket: ${BUCKET}"

    aws s3 rm "$BUCKET" \
        --recursive

    success "Bucket emptied."

}

delete_bucket() {

    local BUCKET="$1"

    if $DRY_RUN; then
        info "[PLAN] Would delete bucket: ${BUCKET}"
        return
    fi

    info "Deleting bucket: ${BUCKET}"

    aws s3 rb "$BUCKET"

    success "Bucket deleted."

}

delete_hosted_zone_records() {

    if $DRY_RUN; then
        info "[PLAN] Would clean Route53 Hosted Zone."
        return
    fi

    local HOSTED_ZONE_ID
    local CHANGE_BATCH
    local CHANGE_ID

    if ! HOSTED_ZONE_ID=$(aws cloudformation describe-stacks \
        --stack-name "${APP_NAME}-global" \
        --query "Stacks[0].Outputs[?OutputKey=='HostedZoneId'].OutputValue" \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null); then

        warn "Global stack not found. Skipping Route53 cleanup."
        return

    fi

    info "Cleaning Route53 Hosted Zone..."

    CHANGE_BATCH=$(
        aws route53 list-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --output json |
        jq '{
            Changes: [
                .ResourceRecordSets[]
                | select(.Type != "NS" and .Type != "SOA")
                | {
                    Action: "DELETE",
                    ResourceRecordSet: .
                }
            ]
        }'
    )

    CHANGE_ID=$(
        aws route53 change-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --change-batch "$CHANGE_BATCH" \
            --query "ChangeInfo.Id" \
            --output text
    )

    info "Waiting for Route53 changes to complete..."

    aws route53 wait resource-record-sets-changed \
        --id "$CHANGE_ID"

    success "Hosted Zone cleaned."

}

get_ssm_parameter() {

    local VALUE

    if ! VALUE=$(aws ssm get-parameter \
        --name "$1" \
        --query "Parameter.Value" \
        --output text \
        --region "$AWS_REGION" 2>/dev/null); then

        error "SSM parameter '$1' not found."
        exit 1
    fi

    echo "$VALUE"
}

confirm_destroy() {

    if $DRY_RUN; then
        return
    fi

    echo
    echo "=========================================================="
    echo " WARNING"
    echo "=========================================================="
    echo
    echo "The following resources will be permanently deleted:"
    echo
    echo "  • ${APP_NAME}-app"
    echo "  • ${APP_NAME}-foundation"
    echo "  • ${APP_NAME}-global"
    echo "  • ${APP_NAME}-bootstrap"
    echo
    echo "  • Route53 Hosted Zone"
    echo "  • Artifact Bucket"
    echo "  • Infrastructure Bucket"
    echo
    echo "This action cannot be undone."
    echo

    read -rp "Type 'yes' to continue: " CONFIRM

    if [[ "$CONFIRM" != "yes" ]]; then
        info "Operation cancelled."
        exit 0
    fi

    echo
}

usage() {

cat << EOF

Usage:
  $(basename "$0") --all [OPTIONS]

Description:
  Destroy all AWS resources created by the deployment script.

Options:
  --all         Destroy all resources.
  --dry-run     Show the execution plan without deleting resources.
  --help, -h    Show this help message.

Examples:
  $(basename "$0") --all
  $(basename "$0") --all --dry-run

EOF

}

SHOW_HELP=true

DESTROY_ALL=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in

        --all)
            SHOW_HELP=false
            DESTROY_ALL=true
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

    confirm_destroy

    delete_stack "${APP_NAME}-app"

    if ARTIFACT_BUCKET=$(get_ssm_parameter "/${APP_NAME}/artifact_bucket_s3"); then
        empty_bucket "$ARTIFACT_BUCKET"
    else
        warn "Artifact bucket parameter not found."
    fi

    delete_stack "${APP_NAME}-foundation"

    delete_hosted_zone_records

    delete_stack "${APP_NAME}-global"

    if IAC_BUCKET=$(get_ssm_parameter "/${APP_NAME}/iac_bucket_s3"); then
        empty_bucket "$IAC_BUCKET"
    else
        warn "IAC bucket parameter not found."
    fi

    delete_stack "${APP_NAME}-bootstrap"

    success "Destroy completed successfully."

}

main "$@"