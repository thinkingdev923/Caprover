#!/bin/bash

set -e
set -o pipefail

if [ -z "${GH_TOKEN:-}" ] || [ -z "${GITHUB_REPOSITORY:-}" ] || [ -z "${GITHUB_SHA:-}" ]; then
    echo "GH_TOKEN, GITHUB_REPOSITORY, and GITHUB_SHA are required." >&2
    exit 1
fi

MATCHING_PRS=()

for retry_delay in 0 2 4 8 16; do
    if [ "$retry_delay" -gt 0 ]; then
        sleep "$retry_delay"
    fi

    mapfile -t MATCHING_PRS < <(
        gh api \
            -H "Accept: application/vnd.github+json" \
            "/repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" \
            --jq ".[] | select(.merged_at != null and .base.ref == \"release\" and .merge_commit_sha == \"$GITHUB_SHA\") | [.title, .head.ref, .head.repo.full_name] | @tsv"
    )

    if [ "${#MATCHING_PRS[@]}" -gt 0 ]; then
        break
    fi
done

if [ "${#MATCHING_PRS[@]}" -ne 1 ]; then
    echo "Expected $GITHUB_SHA to belong to exactly one merged PR targeting release." >&2
    exit 1
fi

IFS=$'\t' read -r PR_TITLE PR_HEAD_REF PR_HEAD_REPOSITORY <<< "${MATCHING_PRS[0]}"

read -r -a COMMIT_AND_PARENTS <<< "$(git rev-list --parents --max-count=1 "$GITHUB_SHA")"
if [ "${#COMMIT_AND_PARENTS[@]}" -ne 3 ]; then
    echo "Release PRs must use a regular merge commit." >&2
    exit 1
fi

PR_BASE_SHA="${COMMIT_AND_PARENTS[1]}"

export PR_TITLE PR_HEAD_REF PR_HEAD_REPOSITORY PR_BASE_SHA
export REPOSITORY="$GITHUB_REPOSITORY"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-release-pr.sh"
