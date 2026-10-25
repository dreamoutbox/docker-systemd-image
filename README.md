# Docker Systemd VPS Setup Tester

Test VPS setup scripts that manage `systemd` services inside a lightweight Docker container on cgroup v2 hosts, avoiding full VM overhead.

## Prerequisites

- Docker with cgroup v2 host support:
  ```bash
  stat -fc %T /sys/fs/cgroup   # must output: cgroup2fs
  ```

## File Structure

- `Dockerfile.systemd-test`: Debian 12 base image configured with `systemd` as PID 1, stripping units that hang or fail in container environments.
- `setup-script-test.sh`: Test wrapper script that orchestrates container creation, script execution, log streaming, and container cleanup.
- `setup.sh`: Sample VPS setup script demonstrating unit file creation, daemon reload, service enablement, and verification.
- `recipe.md`: Detailed manual recipe, compose references, and troubleshooting tips.

## Usage

1. Make scripts executable:
   ```bash
   chmod +x setup-script-test.sh setup.sh
   ```

2. Test a setup script:
   ```bash
   ./setup-script-test.sh setup.sh
   ```

3. Test any custom setup script:
   ```bash
   ./setup-script-test.sh ./path/to/your-script.sh
   ```

## Test Runner Lifecycle

`setup-script-test.sh` performs the following steps:

1. **Image Check**: Builds `vps-test` from `Dockerfile.systemd-test` if not already present.
2. **Container Launch**: Spawns an isolated container with cgroup host namespace, unconfined seccomp profile, and tmpfs mounts on `/tmp`, `/run`, and `/run/lock`.
3. **Boot Readiness**: Waits for systemd to complete initialization (`systemctl is-system-running --wait`).
4. **Execution**: Copies the target setup script into `/root/`, marks it executable, and executes it. Output streams directly to your terminal.
5. **Automatic Cleanup**: A shell trap cleans up the container (`docker rm -f`) on exit or interruption while preserving the setup script's exit status.

## Limitations

Containers share the host kernel. The following operations do not behave like a bare-metal or full VM VPS:
- Kernel parameter tuning (`sysctl`) and kernel modules (`modprobe`).
- Host-level firewall configurations (`ufw`, `iptables`, `nftables`).
- Disk partitioning, swap configuration, and filesystem mounts (`fstab`).
- Low-level system services (`hostnamectl`, `timedatectl`, `systemd-resolved`).
