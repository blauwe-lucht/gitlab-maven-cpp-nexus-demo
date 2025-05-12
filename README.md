# Gitlab demo showing a Maven build that pulls from and pushes to Nexus

## What this demo shows

- Using GitLab, GitLab Runner and Nexus using docker-compose.
- Configuring GitLab and Nexus using ```docker exec``` or their respective APIs through bash scripts:

  - Setting admin/root passwords.
  - Creating and populating GitLab repos.

- Registering a GitLab Runner using a bash script. Note: this uses the deprecated registration token.
- How to use Maven 3 and the NAR plugin to build C++ projects and upload nar files to Nexus.
Note: I only got this to work with maven-releases. I could not use a nar file from the maven-snapshots repo.
- Building and executing a Google Test using Maven.
- Doing building, testing and deploying from a GitLab pipeline.
- Showing Google Test output in the Tests tab of a GitLab pipeline.
- How to prevent Maven from always downloading all its dependencies on every build.

## Prerequisites

- add ```127.0.0.1 gitlab.local``` to your local /etc/hosts file
- nothing should be listening on ports 8080, and 8081

## Usage

- ```docker compose up -d```
- ```./build-ci-image.sh```
- ```./configure-nexus.sh```
- ```./configure-gitlab.sh```
- ```./register-runner.sh```

Log in to GitLab:

- Point browser to <http://gitlab.local:8080/>
- User root, password 'Abcd1234!'

Log in to Nexus:

- Point browser to <http://localhost:8081/>
- User admin, password 'Abcd1234!'

## TODO

- deploy fibonacci binary to application-server after manual approval
- Make a setup script that executes all required steps.
- Don't use registration token, but the new OAuth token.
- Try to get maven-snapshots to work.
