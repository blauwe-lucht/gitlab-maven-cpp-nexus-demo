#!/bin/bash
set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

NEXUS_URL="http://${NEXUS_HOST}:${NEXUS_PORT}"
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

get_preseeded_admin_password() {
    docker exec nexus sh -c 'cat /nexus-data/admin.password 2>/dev/null || true'
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

is_password_valid() {
    call_nexus_api GET "/service/rest/v1/status" >/dev/null 2>&1
}

change_admin_password() {
    log_info "Ensuring admin password is set to default"

    if is_password_valid; then
        log_info "Admin password is already set correctly"
        return
    fi
    
    log_info "Configured password is not valid, trying preseeded password from admin.password file"
    local preseeded_password=$(get_preseeded_admin_password)

    if [[ -z "$preseeded_password" ]]; then
        log_error "No valid current password found, and configured password is incorrect. Cannot continue."
        exit 1
    fi

    log_info "Attempting to change admin password using guessed password"
    if curl -s -f -u "admin:${preseeded_password}" \
        -H "Content-Type: text/plain" \
        -X PUT \
        -d "${NEXUS_ADMIN_PASSWORD}" \
        "${NEXUS_URL}/service/rest/v1/security/users/admin/change-password" >/dev/null; then

        log_info "Password changed successfully"
    else
        log_error "Failed to change admin password with guessed password"
        exit 1
    fi
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

change_admin_password
enable_anonymous_access
define_anonymous_role
assign_role_to_anonymous_user

log_info "Done."
