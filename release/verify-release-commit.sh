#!/bin/bash

set -e
set -o pipefail

if [ -z "${GH_TOKEN:-}" ] || [ -z "${GITHUB_REPOSITORY:-}" ] || [ -z "${GITHUB_SHA:-}" ]; then
    echo "GH_TOKEN, GITHUB_REPOSITORY, and GITHUB_SHA are required." >&2
    exit 1
fi

MATCHING_PRS=()

for attempt in 1 2 3; do
    mapfile -t MATCHING_PRS < <(
        gh api \
            -H "Accept: application/vnd.github+json" \
            "/repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" \
            --jq '.[] | select(.merged_at != null and .base.ref == "release") | [.title, .head.ref, .head.repo.full_name, .base.sha] | @tsv'
    )

    if [ "${#MATCHING_PRS[@]}" -gt 0 ]; then
        break
    fi

    if [ "$attempt" -lt 3 ]; then
        sleep 2
    fi
done

if [ "${#MATCHING_PRS[@]}" -ne 1 ]; then
    echo "Expected $GITHUB_SHA to belong to exactly one merged PR targeting release." >&2
    exit 1
fi

IFS=$'\t' read -r PR_TITLE PR_HEAD_REF PR_HEAD_REPOSITORY PR_BASE_SHA <<< "${MATCHING_PRS[0]}"

export PR_TITLE PR_HEAD_REF PR_HEAD_REPOSITORY PR_BASE_SHA
export REPOSITORY="$GITHUB_REPOSITORY"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-release-pr.sh"
