#!/usr/bin/env python3
"""
deploy-to.py

Downloads the built Fibonacci binary from Nexus, unpacks it,
and copies it into the specified Docker container (test or acceptance).

Usage:
    python deploy-to.py <environment>
    where <environment> is either "test" or "acceptance"

Configuration via environment variables:
    NEXUS_URL        – Nexus base URL (default: http://nexus.local:8081)
"""
import os
import sys
import argparse
import logging
import tempfile
import shutil
import subprocess
from urllib.parse import urljoin
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
import zipfile

# Configuration constants
DEFAULT_NEXUS_URL = os.getenv('NEXUS_URL', 'http://nexus.local:8081')
REPO_PATH = 'repository/maven-releases'
GROUP_ID = 'nl.blauwe-lucht'
ARTIFACT_ID = 'fibonacci'
CLASSIFIER = 'bin'
EXT = 'zip'
# Map environments to container names
CONTAINERS = {
    'test': 'test-server',
    'acceptance': 'acceptance-server',
}


def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='[%(levelname)s] %(message)s'
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description='Deploy Fibonacci binary to Docker container'
    )
    parser.add_argument(
        'environment',
        choices=CONTAINERS,
        help="'test' or 'acceptance'"
    )
    return parser.parse_args()


def get_version():
    """Extract project.version from pom.xml via Maven Help plugin."""
    try:
        result = subprocess.run(
            ['mvn', '--batch-mode', 'help:evaluate',
             '-Dexpression=project.version', '-q', '-DforceStdout'],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=True,
            text=True
        )
        version = result.stdout.strip()
        logging.info(f"Detected project version: {version}")
        return version
    except subprocess.CalledProcessError:
        logging.error('Failed to retrieve project version via Maven')
        sys.exit(1)


def construct_download_url(version):
    """Construct Nexus download URL for the artifact zip."""
    group_path = GROUP_ID.replace('.', '/')
    artifact_name = f"{ARTIFACT_ID}-{version}-{CLASSIFIER}.{EXT}"
    base = f"{DEFAULT_NEXUS_URL}/{REPO_PATH}/{group_path}/{ARTIFACT_ID}/{version}/"
    full_url = urljoin(base, artifact_name)
    return full_url, artifact_name


def download_artifact(url, filename):
    """Download the artifact from Nexus using urllib."""
    logging.info(f"Download URL: {url}")
    logging.info(f"Downloading {filename} from Nexus...")
    try:
        req = Request(url)
        with urlopen(req) as response, open(filename, 'wb') as out_file:
            shutil.copyfileobj(response, out_file)
    except HTTPError as e:
        logging.error(f"HTTP Error: {e.code} when downloading {filename}")
        sys.exit(1)
    except URLError as e:
        logging.error(f"URL Error: {e.reason} when downloading {filename}")
        sys.exit(1)
    return filename


def unpack_artifact(artifact_file):
    """Unzip the downloaded artifact into a temporary directory."""
    temp_dir = tempfile.mkdtemp()
    logging.info(f"Unpacking {artifact_file} to {temp_dir}...")
    with zipfile.ZipFile(artifact_file, 'r') as zip_ref:
        zip_ref.extractall(temp_dir)
    return temp_dir


def find_container(env):
    """Find the Docker container ID by name filter."""
    filter_name = CONTAINERS[env]
    try:
        result = subprocess.run(
            ['docker', 'ps', '-qf', f'name={filter_name}'],
            stdout=subprocess.PIPE,
            check=True,
            text=True
        )
        cid = result.stdout.strip()
        if not cid:
            logging.error(f"No running container matching '{filter_name}' found.")
            sys.exit(1)
        logging.info(f"Found container ID: {cid}")
        return cid
    except subprocess.CalledProcessError:
        logging.error('Failed to query Docker containers')
        sys.exit(1)


def copy_binary(temp_dir, cid):
    """Locate the Fibonacci binary within temp_dir, ensure target dir exists, copy into the container, and set executable permission."""
    # Search recursively for the binary file
    bin_path = None
    for root, _, files in os.walk(temp_dir):
        if ARTIFACT_ID in files:
            bin_path = os.path.join(root, ARTIFACT_ID)
            break
    if not bin_path:
        logging.error(f"Binary '{ARTIFACT_ID}' not found in extracted artifact at {temp_dir}.")
        sys.exit(1)
    dest_dir = os.path.dirname(f"/opt/bin/{ARTIFACT_ID}")
    dest = f"{dest_dir}/{ARTIFACT_ID}"

    logging.info(f"Ensuring directory {dest_dir} exists in container {cid}...")
    subprocess.run(['docker', 'exec', cid, 'mkdir', '-p', dest_dir], check=True)

    logging.info(f"Copying {bin_path} to container {cid}:{dest}...")
    subprocess.run(['docker', 'cp', bin_path, f"{cid}:{dest}"], check=True)
    subprocess.run(['docker', 'exec', cid, 'chmod', '+x', dest], check=True)


def cleanup(paths):
    """Remove temporary files and directories."""
    for path in paths:
        try:
            if os.path.isdir(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
        except Exception:
            logging.warning(f"Failed to remove {path}")


def main():
    setup_logging()
    args = parse_args()

    version = get_version()

    url, filename = construct_download_url(version)
    download_artifact(url, filename)

    temp_dir = unpack_artifact(filename)

    container_id = find_container(args.environment)
    copy_binary(temp_dir, container_id)

    logging.info(
        f"Deployment complete: {ARTIFACT_ID} version {version} is now in container {container_id}."
    )

    cleanup([filename, temp_dir])


if __name__ == '__main__':
    main()
