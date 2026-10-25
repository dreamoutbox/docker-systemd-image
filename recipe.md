# Testing a VPS setup script in Docker with systemd

Docker container running systemd as PID 1 (cgroup v2 host). Good for service/unit-file logic. Not a faithful VPS: see [Limitations](#limitations).

## Prerequisites

```bash
stat -fc %T /sys/fs/cgroup   # must print: cgroup2fs
```

Pin the base image to the distro/version your VPS runs.

## Dockerfile

`Dockerfile.systemd-test`:

```dockerfile
FROM debian:12

ENV container=docker
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus ca-certificates curl sudo \
    && rm -rf /var/lib/apt/lists/* \
    # strip units that fail/hang in containers
    && find /etc/systemd/system /lib/systemd/system \
         \( -path '*.wants/*' \) \
         \( -name '*getty*' -o -name '*udev*' -o -name '*systemd-remount-fs*' \
            -o -name '*systemd-logind*' -o -name '*systemd-networkd*' \) \
         -delete

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
```

## Build and run

```bash
docker build -t vps-test -f Dockerfile.systemd-test .

docker run -d --name vps \
  --cgroupns=host \
  --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --security-opt seccomp=unconfined \
  vps-test
```

Avoid `--privileged`; use it only as a last-resort fallback.

## Verify boot

```bash
docker exec vps systemctl is-system-running --wait   # "running" or "degraded"
docker exec vps systemctl --failed
```

## Run the script

```bash
docker cp setup.sh vps:/root/
docker exec vps bash /root/setup.sh
docker exec vps systemctl status yourservice --no-pager
docker exec vps journalctl -u yourservice --no-pager
```

Run it a second time to verify idempotency:

```bash
docker exec vps bash /root/setup.sh && echo "idempotent OK"
```

## Fast reset loop

Snapshot a clean boot, then restore per test run:

```bash
docker commit vps vps-test:clean

# each iteration
docker rm -f vps
docker run -d --name vps \
  --cgroupns=host \
  --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --security-opt seccomp=unconfined \
  vps-test:clean
```

## Compose equivalent

```yaml
services:
  vps:
    build:
      context: .
      dockerfile: Dockerfile.systemd-test
    cgroup: host
    tmpfs: [/tmp, /run, /run/lock]
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    security_opt:
      - seccomp=unconfined
    stop_signal: SIGRTMIN+3
```

## Cleanup

```bash
docker rm -f vps
docker rmi vps-test vps-test:clean
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Boot hangs / exits immediately | Check `docker logs vps`; confirm cgroup v2; as fallback add `--privileged` |
| cgroup v1 host | Use `-v /sys/fs/cgroup:/sys/fs/cgroup:ro` and drop `--cgroupns=host` (or upgrade the host) |
| Docker Desktop (macOS/Windows) | Drop `-v /sys/fs/cgroup...` and `--cgroupns=host`; try `--privileged` if boot hangs |
| `Failed to connect to bus` | systemd not PID 1; ensure `CMD ["/sbin/init"]` and no `--entrypoint` override |
| `docker stop` takes 10s | `STOPSIGNAL SIGRTMIN+3` missing |

## Limitations

The container shares the host kernel. These will not behave like a real VPS:

- `sysctl` writes, kernel modules (`modprobe`)
- Firewall (`iptables`/`nftables`/`ufw`): needs `--cap-add NET_ADMIN`, still flaky
- Swap, mounts, `fstab`, partitioning
- `hostnamectl`, `timedatectl set-*`, `systemd-resolved`, `networkd`
- AppArmor/SELinux, auditd

If the script touches any of the above, do the final validation in a VM (Multipass, Lima, Vagrant, QEMU/KVM).
