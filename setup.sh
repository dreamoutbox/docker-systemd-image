#!/usr/bin/env bash
set -euo pipefail

# install_service - Creates and activates a systemd service unit.
# Arguments:
#   $1 - service_name: Name of the service (without .service extension).
# Example usage:
#   install_service "vps-demo"
install_service() {
  local service_name="$1"
  local service_path="/etc/systemd/system/${service_name}.service"

  # Write unit file definition
  cat <<EOF > "$service_path"
[Unit]
Description=VPS Demo Service
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/echo "VPS setup service is active and running"

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "$service_path"
  systemctl daemon-reload
  systemctl enable --now "${service_name}.service"
}

# verify_service - Checks status and recent journal logs for the given systemd service.
# Arguments:
#   $1 - service_name: Name of the service to inspect.
# Example usage:
#   verify_service "vps-demo"
verify_service() {
  local service_name="$1"

  # Display service status and recent journal logs
  systemctl status "${service_name}.service" --no-pager
  journalctl -u "${service_name}.service" --no-pager -n 10
}

# main - Entrypoint running setup and verification steps.
# Arguments:
#   None
# Example usage:
#   main
main() {
  local service_name="vps-demo"
  echo "Setting up VPS test service: ${service_name}..."
  install_service "$service_name"
  echo "Verifying service status..."
  verify_service "$service_name"
  echo "VPS setup completed successfully."
}

main "$@"
