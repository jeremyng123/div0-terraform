# Terraform-N — div0 homelab fleet (N× Proxmox docker LXC + Dockge stacks)

A parametrized version of [`../terraform`](../terraform): instead of one docker
LXC container, it creates **`instance_count` identical containers** (default
**2**), each running Dockge + all four stacks. "Twice the services" = two full
hosts, with no port conflicts because each container has its own IP/port space.

Set `instance_count` in `terraform.tfvars` to scale to any N ≥ 1.

```
instance_count = 2

container[0] -> docker-0 : Dockge + 4 stacks (own IP, ports 3000/5380/8888/...)
container[1] -> docker-1 : Dockge + 4 stacks (own IP, same ports)
```

Each container reproduces the community-script "docker" CT (unprivileged Debian,
4 cores / 4 GB RAM / 512 MB swap, 100 GB rootfs, `nesting`+`keyctl`, DHCP on
`vmbr0`, starts on boot) and deploys the stacks from
[`../div0-homelab-stack`](../div0-homelab-stack):

- **Dockge** (`:5001`) → `/opt/dockge`, manages the stacks below without listing itself
- `docker-socket-proxy` — read-only Docker API proxy (`docker-socket-net`)
- `dozzle` — log viewer, consumes the proxy
- `technitium` — DNS server (`observability`)
- `lgtm-stack` — Grafana / Loki / Tempo / Mimir / Pyroscope / Alloy + Technitium exporter

## What's different from `../terraform`

|                         | `terraform`     | `terraform2`                                              |
| ----------------------- | --------------- | --------------------------------------------------------- |
| Containers              | 1               | `var.instance_count` (default 2) via `count`              |
| Hostname                | `docker`        | `docker-0`, `docker-1`, ...                               |
| VMID                    | `vmid` or auto  | `vmid + index` or auto                                    |
| MAC                     | optional static | always auto-generated (a shared static MAC would collide) |
| `container_ip_override` | `string`        | `list(string)`, one entry per instance                    |
| Outputs                 | scalars         | lists indexed by instance                                 |

Rendered `.env`/`bootstrap.sh` are identical for all instances, so they're
rendered once and reused; only the `terraform_data.deploy_stacks` provisioner
(and the container) is multiplied by `count`.

## How it works

| Layer      | Tool                                                                                                                           |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Provider   | `bpg/proxmox` creates each LXC via the PVE API                                                                                 |
| Secrets    | sensitive TF vars → `templatefile` → gitignored `.env` files                                                                   |
| App deploy | per-instance `terraform_data` provisioners SSH into each CT, copy `stacks/` + `dockge/` + `.env`, run `bootstrap.sh`           |
| Bootstrap  | installs Docker if missing, creates the `external` networks, `docker compose up -d` Dockge then each stack in dependency order |

## Usage

```bash
cd terraform2
cp terraform.tfvars.example terraform.tfvars   # then edit it (set instance_count)
terraform init
terraform plan
terraform apply
```

`terraform apply` creates `instance_count` LXCs → waits for each IP → copies the
stacks in → installs Docker → brings Dockge and all stacks up on each. Service
URLs are printed as a list, one map per instance.

### Scaling

Change `instance_count` and re-apply. Increasing it adds containers; decreasing
it destroys the highest-indexed ones (`count` is index-based, so don't reorder).

## Notes & caveats

- **Auth must be root@pam username/password**, not an API token — the containers
  set the `keyctl` feature flag, which tokens can't (`403`). Use a token only if
  you remove `keyctl` from `main.tf`.
- **Use DHCP when `instance_count > 1`.** A single static `ipv4_address` would be
  assigned to every instance and clash. For static IPs, set `container_ip_override`
  per instance (and a DHCP reservation per MAC) instead.
- **One shared SSH keypair** is generated in `./.ssh/` and injected into every
  container. The deploy provisioner uses the matching private key for all of them.
- **Alloy** runs `privileged` + `pid: host` and mounts the real Docker socket —
  the deliberate exception, relying on each LXC's `nesting`/`keyctl` features.
- **Dockge** deploys to `/opt/dockge` (outside `/opt/stacks`) so it doesn't manage
  itself; `DOCKGE_STACKS_DIR` is hardcoded to `/opt/stacks` in its compose.
- Secrets are rendered to `./.rendered/` (gitignored) before being pushed.
  `terraform.tfvars` and `*.tfstate` hold secrets — keep them out of git.
