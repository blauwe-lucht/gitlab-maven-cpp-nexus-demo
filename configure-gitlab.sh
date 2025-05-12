#!/bin/bash

set -euo pipefail

# Configurable variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

GITLAB_URL="http://${GITLAB_HOST}:${GITLAB_PORT}/"
GITLAB_API_URL="${GITLAB_URL}api/v4/"
GITLAB_CONTAINER="gitlab"
GITLAB_PAT_NAME="demo-token"
GITLAB_PAT="gptdemo1234567890abcdef1234567890abcdefabcd"
SCOPES=("api" "read_repository" "write_repository")
SKIP_PAT=false

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

parse_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-pat)
                SKIP_PAT=true
                shift
                ;;
            *)
                echo "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
}

wait_for_gitlab_to_be_ready() {
    log_info "Waiting for GitLab at ${GITLAB_URL}..."
    until docker exec gitlab curl -sSf "http://localhost:${GITLAB_PORT}/-/readiness"; do
        log_info "GitLab not ready yet, retrying in 5 seconds..."
        sleep 5
    done
}

ensure_pat() {
    log_info "Ensuring personal access token is present (this may take a while)..."
    docker exec "$GITLAB_CONTAINER" gitlab-rails runner -e production "
        name = '$GITLAB_PAT_NAME'
        scopes = %w(${SCOPES[*]})
        token_value = '${GITLAB_PAT}'
        user = User.find_by_username('root')

        existing_tokens = user.personal_access_tokens.where(name: name)

        # Revoke and destroy conflicting tokens if the same value was used before
        existing_tokens.each do |t|
          if t.revoked? || t.expired?
            t.destroy
          else
            puts 'Found existing PAT.'
            exit
          end
        end

        token = user.personal_access_tokens.create!(
          name: name,
          scopes: scopes,
          expires_at: 1.year.from_now
        )
        token.set_token(token_value)
        token.save!
        puts 'Token created successfully.'
    "
}

call_gitlab_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local curl_args=(-s -f -H "PRIVATE-TOKEN: ${GITLAB_PAT}" -H "Content-Type: application/json" -X "$method")

    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi

    curl "${curl_args[@]}" "${GITLAB_API_URL}${endpoint}"
}

ensure_gitlab_project() {
    local project_name="$1"

    log_info "Checking if project '$project_name' exists..."
    local search_response
    if ! search_response=$(call_gitlab_api GET "/projects?search=${project_name}"); then
        log_error "Failed to query GitLab API."
        return 1
    fi

    if grep -q "\"name\":\"${project_name}\"" <<< "$search_response"; then
        log_info "Project '$project_name' already exists."
    else
        log_info "Creating project '$project_name'..."
        if call_gitlab_api POST "/projects" "{\"name\": \"${project_name}\"}"; then
            log_info "Created project '$project_name'."
        else
            log_error "Failed to create project '$project_name'."
            return 1
        fi
    fi
}

prepare_and_push_subdir_repo() {
    local subdir="$1"
    local project="$2"
    local stage_dir="${SCRIPT_DIR}/_gitlab_push/${project}"
    local remote_url="http://root:${GITLAB_PAT}@${GITLAB_HOST}:${GITLAB_PORT}/root/${project}.git"

    log_info "Preparing subdir '$subdir' for GitLab push to '$project'..."

    mkdir -p "$(dirname "$stage_dir")"

    # Create or update standalone repo
    git -C "$SCRIPT_DIR" subtree split --prefix="$subdir" -b "tmp-$project"
    rm -rf "$stage_dir"
    git clone --single-branch --branch "tmp-$project" "$SCRIPT_DIR" "$stage_dir"
    git -C "$stage_dir" checkout -b main
    git -C "$SCRIPT_DIR" branch -D "tmp-$project"

    (
        cd "$stage_dir"

        if ! git remote | grep -q gitlab; then
            git remote add gitlab "$remote_url"
        else
            git remote set-url gitlab "$remote_url"
        fi

        git push gitlab main --force
    )
}

parse_flags "$@"
wait_for_gitlab_to_be_ready
if [[ "$SKIP_PAT" == false ]]; then
    ensure_pat
else
    log_info "Skipping personal access token creation."
fi
ensure_gitlab_project "libfibonacci"
prepare_and_push_subdir_repo "libfibonacci" "libfibonacci"
ensure_gitlab_project "fibonacci"
prepare_and_push_subdir_repo "fibonacci" "fibonacci"
