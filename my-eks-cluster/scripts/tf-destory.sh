#!/usr/bin/env bash

echo "Running Terraform destroy..."
echo ""
echo "Description:"
echo "  Runs 'terraform destroy' on one or all paths listed under the 'destroy'"
echo "  heading in scripts/paths.txt. Paths must be relative to my-eks-cluster."
echo ""
echo "Usage:"
echo "  sh ./scripts/tf-destroy.sh                        # destroy all paths in paths.txt"
echo "  sh ./scripts/tf-destroy.sh my-eks-cluster/infra   # destroy a specific path"
echo ""
echo "paths.txt format:"
echo "  destroy"
echo "  my-eks-cluster/infrastructure"
echo "  my-eks-cluster/another-folder"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATHS_FILE="$SCRIPT_DIR/paths.txt"

SPECIFIC="$1"

destroy_all_paths() {
    # read paths listed under the "destroy" heading in paths.txt
    # stops at the next heading (a line with no "/" that isn't empty)
    DESTROY_PATHS=$(awk '/^destroy$/{found=1; next} found && /^[^\/]+$/ && NF{found=0} found && NF{print}' "$PATHS_FILE")

    echo ""
    echo "Destroy paths found in $PATHS_FILE:"
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        echo "  - $path"
    done <<< "$DESTROY_PATHS"
    echo ""

    if [[ -z "$DESTROY_PATHS" ]]; then
        echo "Error: No paths found under 'destroy' heading in paths.txt."
        exit 1
    fi

    # check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "Error: AWS credentials are not configured or have expired."
        exit 1
    fi

    # run terraform destroy on each path
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue

        FOLDER_PATH="$BASE_DIR/${path#my-eks-cluster/}"

        if [[ ! -d "$FOLDER_PATH" ]]; then
            echo ""
            echo "Warning: Folder '$path' not found, skipping."
            echo ""
            continue
        fi

        echo ""
        echo "Destroying: $FOLDER_PATH"
        read -p "Confirm destroy for '$path'? (y/N) " confirm < /dev/tty
        confirm="${confirm:-n}"
        echo ""


        if [[ "$confirm" != "y" ]]; then
            echo "Skipping '$path'."
            continue
        fi

        terraform -chdir="$FOLDER_PATH" destroy
        if [[ $? -ne 0 ]]; then
            echo "Error: Terraform destroy failed for '$path'."
            exit 1
        fi
    done <<< "$DESTROY_PATHS"

}

destroy_one_path() {
    FOLDER_PATH="$BASE_DIR/${SPECIFIC#my-eks-cluster/}"

    if [[ ! -d "$FOLDER_PATH" ]]; then
        echo ""
        echo "Error: Folder '$SPECIFIC' not found."
        echo ""
        exit 1
    fi

    echo ""
    echo "Destroying: $FOLDER_PATH"
    read -p "Confirm destroy for '$SPECIFIC'? (y/N) " confirm < /dev/tty
    confirm="${confirm:-n}"
    echo ""

    if [[ "$confirm" != "y" ]]; then
        echo "Aborting destroy for '$SPECIFIC'."
        exit 0
    fi

    terraform -chdir="$FOLDER_PATH" destroy
    if [[ $? -ne 0 ]]; then
        echo "Error: Terraform destroy failed for '$SPECIFIC'."
        exit 1
    fi
}

if [[ -z "$SPECIFIC" ]]; then
    destroy_all_paths
else
    destroy_one_path
fi
