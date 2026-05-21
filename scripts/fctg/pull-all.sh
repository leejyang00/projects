#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Table formatting
COL_REPO=40
COL_BRANCH=15
COL_STATUS=20

print_separator() {
    printf '+-%*s-+-%*s-+-%*s-+\n' $COL_REPO '' $COL_BRANCH '' $COL_STATUS '' | tr ' ' '-'
}

print_header() {
    print_separator
    printf "| ${BOLD}%-*s${NC} | ${BOLD}%-*s${NC} | ${BOLD}%-*s${NC} |\n" $COL_REPO "Repository" $COL_BRANCH "Branch" $COL_STATUS "Status"
    print_separator
}

print_row() {
    local repo="$1"
    local branch="$2"
    local status="$3"
    local color="$4"
    printf "| %-*s | %-*s | ${color}%-*s${NC} |\n" $COL_REPO "$repo" $COL_BRANCH "$branch" $COL_STATUS "$status"
}

get_default_branch() {
    local dir="$1"
    local branch

    # Try to get the default branch from the remote HEAD
    branch=$(git -C "$dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    if [[ -z "$branch" ]]; then
        # Fallback: check if main or master exists
        if git -C "$dir" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
            branch="main"
        elif git -C "$dir" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
            branch="master"
        else
            # Last resort: use current branch
            branch=$(git -C "$dir" branch --show-current 2>/dev/null)
        fi
    fi

    echo "$branch"
}

echo ""
echo "${BOLD}Pulling all repositories in: ${CYAN}${SCRIPT_DIR}${NC}"
echo ""

print_header

for dir in "$SCRIPT_DIR"/*/; do
    [[ ! -d "$dir/.git" ]] && continue

    repo_name=$(basename "$dir")
    branch=$(get_default_branch "$dir")

    if [[ -z "$branch" ]]; then
        print_row "$repo_name" "N/A" "NO BRANCH FOUND" "$RED"
        continue
    fi

    # Print in-progress status
    printf "| %-*s | %-*s | ${YELLOW}%-*s${NC} |\r" $COL_REPO "$repo_name" $COL_BRANCH "$branch" $COL_STATUS "Pulling..."

    # Checkout default branch and pull
    checkout_output=$(git -C "$dir" checkout "$branch" 2>&1)
    if [[ $? -ne 0 ]]; then
        print_row "$repo_name" "$branch" "CHECKOUT FAILED" "$RED"
        continue
    fi

    pull_output=$(git -C "$dir" pull origin "$branch" 2>&1)
    pull_exit=$?

    if [[ $pull_exit -eq 0 ]]; then
        if echo "$pull_output" | grep -q "Already up to date"; then
            print_row "$repo_name" "$branch" "Up to date" "$GREEN"
        else
            print_row "$repo_name" "$branch" "Updated" "$CYAN"
        fi
    else
        print_row "$repo_name" "$branch" "PULL FAILED" "$RED"
    fi
done

print_separator
echo ""
echo "${BOLD}Done.${NC}"
echo ""
