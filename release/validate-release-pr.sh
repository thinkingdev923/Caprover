#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/release.conf"

required_variables=(
    PR_TITLE
    PR_HEAD_REF
    PR_HEAD_REPOSITORY
    PR_BASE_SHA
    REPOSITORY
)

for variable_name in "${required_variables[@]}"; do
    if [ -z "${!variable_name:-}" ]; then
        echo "Missing required variable: $variable_name" >&2
        exit 1
    fi
done

if [ "$PR_HEAD_REPOSITORY" != "$REPOSITORY" ]; then
    echo "Release PRs must originate from $REPOSITORY." >&2
    exit 1
fi

if [[ "$PR_TITLE" =~ ^(Release|Hotfix)\ v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    RELEASE_TYPE="${BASH_REMATCH[1]}"
    TITLE_VERSION="${BASH_REMATCH[2]}"
else
    echo "PR title must be 'Release vX.Y.Z' or 'Hotfix vX.Y.Z'." >&2
    exit 1
fi

if [ "$TITLE_VERSION" != "$CAPROVER_VERSION" ]; then
    echo "PR title version $TITLE_VERSION does not match release.conf version $CAPROVER_VERSION." >&2
    exit 1
fi

if ! grep --extended-regexp --quiet "^## \[$CAPROVER_VERSION\]( |$)" CHANGELOG.md; then
    echo "CHANGELOG.md is missing the heading ## [$CAPROVER_VERSION]." >&2
    exit 1
fi

if ! git merge-base --is-ancestor "$PR_BASE_SHA" HEAD; then
    echo "The release PR does not contain the current release branch." >&2
    echo "Complete any pending release-to-master backmerge before preparing a normal release." >&2
    exit 1
fi

case "$RELEASE_TYPE" in
    Release)
        EXPECTED_PREFIX="release/"
        ;;
    Hotfix)
        EXPECTED_PREFIX="hotfix/"

        if git show-ref --verify --quiet refs/remotes/origin/master; then
            while read -r candidate_commit; do
                if git merge-base --is-ancestor "$candidate_commit" origin/master; then
                    echo "Hotfix PRs cannot include unreleased commits from master." >&2
                    exit 1
                fi
            done < <(git rev-list "$PR_BASE_SHA"..HEAD)
        else
            echo "origin/master is required to validate a hotfix PR." >&2
            exit 1
        fi
        ;;
esac

if [[ "$PR_HEAD_REF" != "$EXPECTED_PREFIX"* ]]; then
    echo "$RELEASE_TYPE PR branches must start with $EXPECTED_PREFIX." >&2
    exit 1
fi

echo "$RELEASE_TYPE v$CAPROVER_VERSION is a valid production release candidate."
