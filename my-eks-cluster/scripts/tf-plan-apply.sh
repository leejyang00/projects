#!/usr/bin/env bash

echo "Running Terraform plan and apply..."

# reading input 
# ./tf-plan-apply.sh infrastructure
# running tf plan and apply from tf folders from /my-eks-cluster folder as root
# script lives in /script folder

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_FOLDER="$1"

if [[ -z "$TF_FOLDER" ]]; then
    echo " "
    echo "Error: No Terraform folder specified."
    echo "  - run script \"sh ./scripts/tf-plan-apply.sh <terraform-folder>\""
    exit 1
fi

FOLDER_PATH="$BASE_DIR/$TF_FOLDER"

if [[ ! -d "$FOLDER_PATH" ]]; then 
    echo " "
    echo "Error: Folder '$TF_FOLDER' not found in $(basename "$BASE_DIR")."
    echo "  - available folders: $(ls -d "$BASE_DIR"/*/  2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    exit 1
fi

echo ""
echo "Terraform folder: $FOLDER_PATH"

### PREFLIGHT CHECKS ###

# check terraform is installed
if ! command -v terraform &>/dev/null; then
    echo ""
    echo "Error: terraform is not installed or not in PATH."
    echo ""
    exit 1
fi

# check tf-summarize is installed
if ! command -v tf-summarize &>/dev/null; then
    echo "Error: tf-summarize is not installed or not in PATH."
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query "Arn" --output text)

# check AWS credentials are configured
if [[ -z "$AWS_ACCOUNT" ]]; then
    echo ""
    echo "Error: AWS credentials are not configured or have expired."
    echo "  - run \"aws configure\" or refresh your session."
    echo ""
    exit 1
fi

echo "AWS caller identity: $AWS_ACCOUNT"
echo ""


# check for .tf files in the folder
if ! ls "$FOLDER_PATH"/*.tf &>/dev/null; then
    echo "Error: No .tf files found in '$TF_FOLDER'."
    exit 1
fi

### FUNCTIONS ###

# RUN: terraform init (only if not already initialized)
run_tf_init() {
    if [[ -d "$FOLDER_PATH/.terraform" ]]; then
        echo ""
        echo "Skipping terraform init (already initialized)."
        return
    fi
    echo ""
    echo "Running terraform init..."
    terraform -chdir="$FOLDER_PATH" init
    if [[ $? -ne 0 ]]; then # $? exit code of last command, -ne means "not equal", 0 means success
        echo "Error: Terraform init failed."
        exit 1
    fi
}

# RUN: terraform plan and output summary of changes
run_tf_plan() {
    echo ""
    echo "Running terraform plan..."
    terraform -chdir="$FOLDER_PATH" plan -out=tfplan
    if [[ $? -ne 0 ]]; then
        echo "Error: Terraform plan failed."
        exit 1
    fi
    (cd "$FOLDER_PATH" && tf-summarize tfplan)

    read -p "Apply these changes? (Y/n) " apply_changes
    apply_changes="${apply_changes:-y}"
    echo ""
}

run_tf_apply() {
    echo ""
    echo "Running terraform apply..."
    terraform -chdir="$FOLDER_PATH" apply tfplan
    if [[ $? -ne 0 ]]; then
        echo "Error: Terraform apply failed."
        exit 1
    fi
}

### MAIN SCRIPT EXECUTION ###

run_tf_init
run_tf_plan

if [[ "$apply_changes" != "y" ]]; then
    echo "Aborting terraform apply."
    exit 0
else
    echo "Proceeding with terraform apply..."
    run_tf_apply
fi
