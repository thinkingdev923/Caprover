#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/release.conf"

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to validate the release version." >&2
    exit 1
fi

if [[ ! "$CAPROVER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid CapRover version: $CAPROVER_VERSION" >&2
    exit 1
fi

TAG_URL="https://hub.docker.com/v2/repositories/${CAPROVER_IMAGE_NAME}/tags/${CAPROVER_VERSION}"
HTTP_STATUS="$(curl --silent --show-error --location --output /dev/null --write-out '%{http_code}' "$TAG_URL")"

case "$HTTP_STATUS" in
    200)
        echo "Version $CAPROVER_VERSION already exists on Docker Hub." >&2
        exit 1
        ;;
    404)
        printf '%s\n' "$CAPROVER_VERSION"
        ;;
    *)
        echo "Docker Hub returned HTTP $HTTP_STATUS while validating version $CAPROVER_VERSION." >&2
        exit 1
        ;;
esac
