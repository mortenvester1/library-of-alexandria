# Borg UI

Web frontend for [Borg Backup](https://www.borgbackup.org/), running on
gurpgork-bee. Backs up the self-hosted app data and media on that machine to the
8TB btrfs drive at `/mnt/backup`, with database dumps driven by pre-backup hooks.

Docs: <https://docs.borgui.com/>

## Layout on disk

The 8TB drive is one btrfs filesystem, split by subvolume rather than by
partition — same isolation, pooled free space, and no need to guess the
borg/Time Machine ratio up front.

| Path | Holds |
| --- | --- |
| `/mnt/backup/@borg` | the borg repositories |
| `/mnt/backup/@timemachine` | Samba/`vfs_fruit` share for the Macs — **not part of this stack** |
| `/mnt/storage` | the sources: `immich/`, `couchdb/`, `seafile/`, media |
| `/mnt/storage/dumps` | staging dir the pre-backup hooks dump databases into |
| `/mnt/storage/borgui-data` | Borg UI's own state — see [Disaster recovery](#disaster-recovery) |

Inside the container: `/local/backup`, `/local/storage` (read-only),
`/local/dumps`.

## Setup

### 1. Create the subvolumes

`chattr +C` only affects files created afterwards, so it must run **before any
data lands**. Doing it later is a silent no-op. Borg's own docs recommend
nodatacow for repos on btrfs; Time Machine sparsebundle band files fragment
badly under CoW for the same reason.

```bash
sudo btrfs subvolume create /mnt/backup/@borg
sudo btrfs subvolume create /mnt/backup/@timemachine
sudo chattr +C /mnt/backup/@borg /mnt/backup/@timemachine
sudo mkdir -p /mnt/storage/dumps /mnt/storage/borgui-data
sudo chown -R <PUID>:<PGID> /mnt/backup/@borg /mnt/storage/dumps \
                            /mnt/storage/borgui-data
```

`<PUID>` is your account — `id -u`. `<PGID>` is the `storage` group created in
the next step, not your primary group.

### 2. Set ownership

Every app's uid is fixed by its image — CouchDB's entrypoint refuses anything but
5984, Postgres likewise — so the owner is not yours to choose. What you choose is
the **group**: a shared `storage` group is how Borg gets read access without
anything running as root.

```bash
sudo ./setup-permissions.sh            # dry run, prints what it would do
sudo ./setup-permissions.sh --apply
```

It creates the group, adds you to it, creates Borg UI's own directories as
`<PUID>:storage 2750`, and on the app data sets group + `g+rX` + setgid while
leaving owners alone. setgid matters because it only affects files created
*afterwards* — existing files keep their old group, which is why the script also
fixes up what is already there.

It deliberately never touches `/mnt/storage/immich/db` or
`/mnt/storage/seafile/mysql`. Those are excluded from every plan, and Postgres
refuses to start on a group-readable pgdata without `--allow-group-access`.

Put the printed `storage` gid in `.env` as `PGID`. Group membership does not
reach an already-open shell — log out and back in, or `stat` will look right
while reads still fail.

### 3. Start the stack

```bash
cp .env.example .env   # then fill in the guarded values
docker compose up -d
docker compose logs -f app
```

The UI comes up on `http://gurpgork-bee:8081`. Log in as `admin` with
`INITIAL_ADMIN_PASSWORD` and change it immediately — upstream's default is
`admin123`, so the compose file guards the variable rather than inheriting it.

### 4. Install the Docker CLI in the container

**Settings > System > Packages > `docker.io`.**

The socket proxy exposes the daemon, but the hooks still need the `docker`
binary. Without this every hook fails with `docker: command not found`.

### 5. Verify `docker exec` survives the proxy

```bash
docker exec borg-web-ui docker exec immich_postgres pg_dump --version
```

`exec` needs a connection hijack through haproxy, which is a different code path
from the plain stop/start the CouchDB hooks use — so it can fail while those
still work. If it does, mount `/var/run/docker.sock` into `app` directly and drop
`DOCKER_HOST`. That is host-level access; the proxy exists to avoid it. Do not
rewrite the hooks.

### 6. Check that Borg can actually read everything

```bash
./check-permissions.sh
```

Read-only. It reports ownership, warns if `PGID` misses the `storage` gid, and —
the only part that really counts — runs `find ! -readable` as `PUID:PGID` inside
the container against every backup source. Empty output means Borg will not
silently skip files. Re-run it after any app upgrade that might recreate files
under a different uid.

### 7. Create the repos, scripts and plans

Repositories under `/local/backup`, one per source group. Then paste the hook
scripts into the script library and build the backup plans — see
[`hooks/README.md`](hooks/README.md) for the scripts, the source lists, and what
attaches where.

## Why a socket proxy

The hooks need the Docker API, but mounting `/var/run/docker.sock` into the app
container is host-level root. The Tecnativa proxy narrows that to the endpoints
the hooks actually call, stays on the `default` network, and publishes no port.

`EXEC=1` is still effectively root on any container this daemon runs — it is the
minimum the dump hooks need. Keep the proxy unpublished.

## Disaster recovery

`/data` (`BORGUI_DATA_PATH`) holds the sqlite database, the script library, SSH
material, repo config, and the generated `.secret_key` that unlocks every stored
repo passphrase. It is a bind mount, not a named volume, so it is not stranded in
`/var/lib/docker`.

**It cannot be backed up into a repo Borg UI manages** — restoring it would
require the thing being restored. Send it to the offsite target or a plain
scheduled `tar`. Keep the repo passphrases themselves somewhere off this machine
too: an unrecoverable repo is worse than no repo.

One drive in one machine is also not a backup. Media, app data, and every Mac's
history currently fail together; an offsite replication target is cheap to add
now and awkward to retrofit.

## Not done yet

- **Time Machine** — Samba ≥4.8 + `vfs_fruit` + avahi advertising `_adisk._tcp`
  on `@timemachine`. Cap it with `fruit:time machine max size` on the share, not
  with partition geometry. Netatalk/AFP is dead; don't use it.
- **Plane** — volume paths still unknown, so it has no plan.
- **Retention** — no prune policy on any repo.
- **Offsite replication** — see above.
