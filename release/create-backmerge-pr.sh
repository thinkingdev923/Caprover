#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/release.conf"

if [ -z "${GH_TOKEN:-}" ] || [ -z "${GITHUB_REPOSITORY:-}" ]; then
    echo "GH_TOKEN and GITHUB_REPOSITORY are required." >&2
    exit 1
fi

EXISTING_PR_URL="$(
    gh pr list \
        --repo "$GITHUB_REPOSITORY" \
        --base master \
        --head release \
        --state open \
        --json url \
        --jq '.[0].url // empty'
)"

if [ -n "$EXISTING_PR_URL" ]; then
    echo "Backmerge PR already exists: $EXISTING_PR_URL"
    PR_URL="$EXISTING_PR_URL"
else
    PR_URL="$(
        gh pr create \
            --repo "$GITHUB_REPOSITORY" \
            --base master \
            --head release \
            --title "Backmerge v$CAPROVER_VERSION from release into master" \
            --body "Automated backmerge after successfully publishing v$CAPROVER_VERSION."
    )"

    echo "Created backmerge PR: $PR_URL"
fi

for workflow in build_project.yml format_project.yml lint_project.yml; do
    gh workflow run "$workflow" \
        --repo "$GITHUB_REPOSITORY" \
        --ref release
done

if gh pr merge --repo "$GITHUB_REPOSITORY" --auto --merge "$PR_URL"; then
    echo "Enabled auto-merge for $PR_URL"
else
    echo "Auto-merge is unavailable or the PR requires manual conflict resolution."
fi
