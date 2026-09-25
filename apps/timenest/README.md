# TimeNest

Network Time Machine target for the Macs, on **gurpgork-bee**. Samba 4.18 +
`vfs_fruit` over SMB3, advertised as a Time Capsule over Bonjour, with a FastAPI
admin UI for per-user accounts and quotas.

Upstream: <https://github.com/momenbasel/timenest>

This is the **Time Machine** item listed under "Not done yet" in
`apps/borgui/README.md` — Samba ≥ 4.8 + `vfs_fruit` + avahi advertising
`_adisk._tcp` on `/mnt/backup/@timemachine`, capped with
`fruit:time machine max size` rather than partition geometry.

## Layout

| Path | Role |
| --- | --- |
| `/mnt/backup/@timemachine` | the share itself; btrfs subvolume, `chattr +C` — created in `apps/borgui/README.md` |
| `/mnt/storage/timenest/samba` | `passdb.tdb` — the Samba accounts |
| `/mnt/storage/timenest/config/shares.d` | one `<user>.conf` share fragment per Mac, written by the web UI |
| `/mnt/storage/timenest/web` | `auth.db` (bcrypt admin hash), quota bookkeeping |
| `/etc/avahi/services/timenest.service` | Bonjour advertisement, installed into the **host** avahi |

State lives on `/mnt/storage`, not on the backup drive: `passdb.tdb` is the only
non-regenerable piece here, and it needs to be inside a Borg source. `setup.sh`
creates those three directories `2775 <you>:storage` for that reason — both
containers run as root (`id` in `timenest-web` is `uid=0`), so ownership is not
about their writes, it is about Borg UI being able to read them through its
read-only `/mnt/storage` mount as `PUID:PGID`. Files the containers create
inside keep whatever mode upstream sets; if a Borg run reports skipped files
here, that is where to look.
`/mnt/backup/@timemachine` itself must stay **excluded** from every Borg source —
`apps/borgui/.env.example` already says so.

Only `shares.d` is bind-mounted into the samba container, not the whole of
`/etc/timenest`. The image ships `/etc/timenest/smb.conf.template` and the
entrypoint renders `/etc/samba/smb.conf` from it on every start; binding the
parent directory — which is what upstream's compose does — masks that file and
smbd crash-loops on `smb.conf.template: No such file or directory`.

## Two host-level conflicts

**avahi.** gurpgork-bee runs `avahi-daemon` on `:5353` and `apps/entrance`
depends on it. Upstream ships a host-networked avahi container, which would
fight it. That service is dropped here; `setup.sh` installs the same service XML
(`timenest.service`, rendered with `SERVER_NAME`/`DEVICE_MODEL`) into the host's
`/etc/avahi/services/`. avahi re-reads that directory on change — no restart.

**smbd.** `:445` must be free. Host `smbd` is currently inactive on bee;
`setup.sh` refuses to proceed if it comes back. To retire it permanently:

```bash
sudo systemctl disable --now smbd nmbd && sudo systemctl mask smbd
```

## Install

```bash
cp .env.example .env
$EDITOR .env          # ADMIN_PASSWORD is the only value with no default
./setup.sh            # dry run
./setup.sh --apply
docker compose up -d
docker compose logs -f samba
```

Then open `http://gurpgork-bee:8083`, log in as `admin`, and add one user per
Mac. Each user gets its own `shares.d/<user>.conf` with a
`fruit:time machine max size` equal to `DEFAULT_QUOTA_GB`.

On the Mac: System Settings → General → Time Machine → Add Backup Disk. The
share appears as **TimeNest** with a Time Capsule icon. No IP, no `smb://` URL.

## Versions

Upstream publishes no semver tags — `ghcr.io/momenbasel/timenest-*` carry only
`main` and `latest`, and both move. The images are therefore pinned by manifest
digest in `.env.example` (resolved 2026-09-22). To bump:

```bash
docker buildx imagetools inspect ghcr.io/momenbasel/timenest-web:latest
```

Images are cosign-signed with GitHub OIDC; verification is not wired in here.

## Monitoring

`web` joins the external `monitoring` network as `timenest` and serves
Prometheus metrics on `:8080/metrics` when `ENABLE_METRICS=true`. The scrape job
is already in `apps/monitoring/config.alloy` — reload Alloy after first start.
Upstream puts no auth on `/metrics`, so it is also reachable on the published
host port; it carries per-user backup sizes and timestamps.

`samba` is host-networked, so it cannot also join `monitoring` — the same
constraint `apps/jellyfin` hits. It exports no metrics of its own. Logs and
cAdvisor container metrics for both services still arrive through the Docker
socket that `apps/monitoring` holds.

## Known rough edges

- `timenest-web` reaches the daemon through a narrowed `docker-socket-proxy`
  (`CONTAINERS`/`POST`/`EXEC` only), not upstream's raw `docker.sock` bind —
  `web/app/samba_mgr.py` shells out to the docker CLI, which honours
  `DOCKER_HOST`. `EXEC=1` is still root inside `timenest-samba`, which is a
  privileged container; that is inherent to how TimeNest manages Samba users.
  The proxy publishes no port and sits on `default` only.
- `SMB_INTERFACES` defaults to `enp2s0` here rather than upstream's empty value,
  which would bind `tailscale0` too and offer the share to every tailnet peer.
  The upstream `smb.conf` template sets `server smb encrypt = desired`, not
  `required`, so that exposure is not mitigated by encryption. Re-check the
  interface name after any NIC rename.
- `timenest.service` is a copy of upstream `avahi/timenest.service.template`
  as of 2026-09-22 (`main`). Diff it against upstream on any image bump — a
  change to the `_adisk._tcp` TXT records would otherwise desync silently.
- `SERVER_NAME` is both the Bonjour name and the netbios name. Changing it after
  Macs have enrolled points them at a share that no longer exists.
