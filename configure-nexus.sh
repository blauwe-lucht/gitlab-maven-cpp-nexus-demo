#!/bin/bash
set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

NEXUS_URL="http://${NEXUS_HOST}:${NEXUS_PORT}"
DEFAULT_PASSWORD="Abcd1234!"
ROLE_ID="anonymous-deploy"
ROLE_NAME="Anonymous Deploy Role"
ROLE_DESC="Allow anonymous to deploy to maven-snapshots"
ROLE_PRIVILEGES=(
    "nx-repository-view-maven2-maven-snapshots-add"
    "nx-repository-view-maven2-maven-snapshots-edit"
    "nx-repository-view-maven2-maven-snapshots-read"
    "nx-repository-view-maven2-maven-releases-add"
    "nx-repository-view-maven2-maven-releases-edit"
    "nx-repository-view-maven2-maven-releases-read"
)

# === Utilities ===

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

get_admin_password() {
    docker exec nexus sh -c 'cat /nexus-data/admin.password 2>/dev/null || true'
}

call_nexus_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local curl_args=(-s -f -u "admin:${NEXUS_PASSWORD}" -H "Content-Type: application/json" -X "$method")

    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi

    curl "${curl_args[@]}" "${NEXUS_URL}${endpoint}"
}

enable_anonymous_access() {
    log_info "Enabling anonymous access"
    call_nexus_api PUT "/service/rest/v1/security/anonymous" \
        '{"enabled":true,"userId":"anonymous","realmName":"NexusAuthorizingRealm"}'
}

define_anonymous_role() {
    log_info "Creating or updating role '${ROLE_ID}'"

    local privs_json
    privs_json=$(printf '%s\n' "${ROLE_PRIVILEGES[@]}" | jq -R . | jq -s .)

    local payload
    payload=$(jq -n \
        --arg id "$ROLE_ID" \
        --arg name "$ROLE_NAME" \
        --arg desc "$ROLE_DESC" \
        --argjson privs "$privs_json" \
        '{
            id: $id,
            name: $name,
            description: $desc,
            privileges: $privs,
            roles: []
        }')

    if call_nexus_api GET "/service/rest/v1/security/roles/${ROLE_ID}" >/dev/null 2>&1; then
        call_nexus_api PUT "/service/rest/v1/security/roles/${ROLE_ID}" "$payload"
    else
        call_nexus_api POST "/service/rest/v1/security/roles" "$payload"
    fi
}

assign_role_to_anonymous_user() {
    log_info "Assigning role '${ROLE_ID}' to anonymous user"

    local payload
    payload=$(jq -n \
        --arg userId "anonymous" \
        --argjson roles "[\"$ROLE_ID\"]" \
        '{
            userId: $userId,
            firstName: "Anonymous",
            lastName: "User",
            emailAddress: "anon@example.com",
            source: "default",
            status: "active",
            roles: $roles
        }')

    call_nexus_api PUT "/service/rest/v1/security/users/anonymous" "$payload"
}

# === Main ===

NEXUS_PASSWORD=$(get_admin_password)
NEXUS_PASSWORD=${NEXUS_PASSWORD:-$DEFAULT_PASSWORD}

enable_anonymous_access
define_anonymous_role
assign_role_to_anonymous_user

log_info "✔ Anonymous snapshot access is fully configured."
