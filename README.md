# Gitlab demo showing a Maven build that pulls from and pushes to Nexus

## Prerequisites

- add ```127.0.0.1 gitlab.local``` to your local /etc/hosts file
- nothing should be listening on ports 80, 443, 2222 and 8081

## Usage

- ```docker compose up -d```
-

docker exec gitlab gitlab-rails runner "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"
