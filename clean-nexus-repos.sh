#!/bin/bash

set -euo pipefail

# Configurable values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

NEXUS_URL="http://${NEXUS_HOST}:${NEXUS_PORT}"
REPOSITORY="maven-releases"

GROUP="nl.blauwe-lucht"
ARTIFACTS=("libfibonacci" "fibonacci")

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

call_nexus_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local curl_args=(-s -f -u "${NEXUS_ADMIN_USER}:${NEXUS_ADMIN_PASSWORD}" -H "Content-Type: application/json" -X "$method")

    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi

    curl "${curl_args[@]}" "${NEXUS_URL}${endpoint}"
}

delete_component_by_id() {
    local component_id="$1"

    if call_nexus_api DELETE "/service/rest/v1/components/${component_id}"; then
        log_info "Deleted component ID $component_id"
    else
        log_error "Failed to delete component ID $component_id"
    fi
}

delete_all_versions_of_artifact() {
    local artifact="$1"
    local continuation_token=""
    local query_url

    log_info "Searching for components of '$artifact'..."

    while :; do
        query_url="/service/rest/v1/components?repository=${REPOSITORY}&group=${GROUP}&name=${artifact}"

        if [[ -n "$continuation_token" ]]; then
            query_url+="&continuationToken=${continuation_token}"
        fi

        response=$(call_nexus_api GET "$query_url" || echo "")

        component_ids=($(echo "$response" | jq -r '.items[].id'))

        if [[ ${#component_ids[@]} -eq 0 ]]; then
            log_info "No components found for '$artifact'."
            break
        fi

        for id in "${component_ids[@]}"; do
            delete_component_by_id "$id"
        done

        continuation_token=$(echo "$response" | jq -r '.continuationToken // empty')
        [[ -z "$continuation_token" ]] && break
    done
}

# --- Main ---

command -v jq >/dev/null || { log_error "'jq' is required but not installed."; exit 1; }

for artifact in "${ARTIFACTS[@]}"; do
    delete_all_versions_of_artifact "$artifact"
done
