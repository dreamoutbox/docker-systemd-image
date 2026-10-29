#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME=""
export IMAGE_NAME="${IMAGE_NAME:-dreamoutbox/docker-systemd-image}"

# cleanup - Stops and removes the Docker container if active.
# Arguments:
#   None
# Example usage:
#   trap cleanup EXIT INT TERM
cleanup() {
  # Clean up container resources on exit or interruption
  if [[ -n "${CONTAINER_NAME:-}" ]]; then
    echo "Cleaning up container: ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  fi
}

# ensure_image - Builds the systemd Docker image via docker-build-image.sh if it does not exist.
# Arguments:
#   $1 - image_tag: Name/tag of the target Docker image (also exported as IMAGE_NAME for the build script).
#   $2 - build_script: Path to docker-build-image.sh.
# Example usage:
#   ensure_image "dreamoutbox/docker-systemd-image" "./docker-build-image.sh"
ensure_image() {
  local image_tag="$1"
  local build_script="$2"

  if ! docker image inspect "${image_tag}" >/dev/null 2>&1; then
    echo "Docker image '${image_tag}' not found. Running ${build_script}..."
    IMAGE_NAME="${image_tag}" IMAGE_TAG=latest "${build_script}"
  fi
}

# start_container - Spawns a systemd-enabled Docker container in the background.
# Arguments:
#   $1 - container_name: Unique name to assign to the container.
#   $2 - image_tag: Target Docker image tag to run.
# Example usage:
#   start_container "vps-test-1234" "dreamoutbox/docker-systemd-image"
start_container() {
  local container_name="$1"
  local image_tag="$2"

  echo "Starting systemd container: ${container_name}..."
  # Run container with cgroups and tmpfs mounts as specified in recipe.md
  docker run -d --name "${container_name}" \
    --cgroupns=host \
    --privileged \
    --tmpfs /tmp:exec --tmpfs /run --tmpfs /run/lock \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --security-opt seccomp=unconfined \
    "${image_tag}" >/dev/null
}

# wait_for_systemd - Waits for systemd inside the container to reach running or degraded state.
# Arguments:
#   $1 - container_name: Name of the container to check.
# Example usage:
#   wait_for_systemd "vps-test-1234"
wait_for_systemd() {
  local container_name="$1"

  echo "Waiting for systemd to initialize..."
  # systemctl is-system-running --wait blocks until startup completes (returns 'running' or 'degraded')
  docker exec "${container_name}" systemctl is-system-running --wait >/dev/null 2>&1 || true
}

# execute_target_script - Copies target script to container and executes it, streaming output.
# Arguments:
#   $1 - container_name: Name of the target container.
#   $2 - host_script_path: Path to the script on host to test.
# Example usage:
#   execute_target_script "vps-test-1234" "./setup.sh"
execute_target_script() {
  local container_name="$1"
  local host_script_path="$2"
  local script_name
  script_name="$(basename "${host_script_path}")"
  local container_dest="/root/${script_name}"

  echo "Copying ${host_script_path} into container at ${container_dest}..."
  docker cp "${host_script_path}" "${container_name}:${container_dest}"
  docker exec "${container_name}" chmod +x "${container_dest}"

  echo "--- Execution Output (${script_name}) ---"
  # Execute script directly to stream all output to the terminal
  local exit_code=0
  docker exec "${container_name}" "${container_dest}" || exit_code=$?
  echo "Script exited with code: ${exit_code}"
  return "${exit_code}"
}

# main - Entrypoint parsing arguments and orchestrating test container lifecycle.
# Arguments:
#   $@ - Command line arguments passed to script.
# Example usage:
#   main "$@"
main() {
  if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 <target-setup-script>"
    exit 1
  fi

  local target_script="$1"
  if [[ ! -f "${target_script}" ]]; then
    echo "Error: Target setup script '${target_script}' not found." >&2
    exit 1
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local build_script="${script_dir}/docker-build-image.sh"

  if [[ ! -x "${build_script}" ]]; then
    echo "Error: Build script '${build_script}' not found or not executable." >&2
    exit 1
  fi

  trap cleanup EXIT INT TERM

  ensure_image "${IMAGE_NAME}" "${build_script}"

  CONTAINER_NAME="docker-systemd-image-$$-$(date +%s)"
  start_container "${CONTAINER_NAME}" "${IMAGE_NAME}"
  wait_for_systemd "${CONTAINER_NAME}"
  local exit_code=0
  execute_target_script "${CONTAINER_NAME}" "${target_script}" || exit_code=$?
  if [[ "${exit_code}" -eq 0 ]]; then
    echo "Test finished successfully."
  fi
  return "${exit_code}"
}

main "$@"
