# Gitlab demo showing a Maven build that pulls from and pushes to Nexus

## Prerequisites

- add ```127.0.0.1 gitlab.local``` to your local /etc/hosts file
- nothing should be listening on ports 8080, and 8081

## Usage

- ```docker compose up -d```
-

docker exec gitlab gitlab-rails runner "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"

Log in to GitLab:

- Point browser to <http://gitlab.local:8080/>
- User root, password 'Abcd1234!'

Log in to Nexus:

- Point browser to <http://localhost:8081/>
- User admin, password 'Abcd1234!'
