# Backup hooks

Borg UI keeps hook scripts in its own script library inside `/data`, not on disk,
so these files are the source of truth you paste into the UI, not something the
compose file mounts. Keep them in sync by hand when you edit one in the UI.

Per script: **Settings > Scripts > New**, paste the body, then attach it to the
matching Backup Plan as a pre- or post-backup hook. Values written as
`${NAME:?...}` are **script parameters** — set them per repository in the UI so
passwords never live in this repo.

Prerequisite: `docker.io` installed under **Settings > System > Packages**,
otherwise every one of these fails with `docker: command not found`.

| Script | Attach to | Notes |
| --- | --- | --- |
| `pre-immich.sh` | immich plan, pre-backup | dump-while-live; no downtime |
| `pre-seafile.sh` | seafile plan, pre-backup | dump-while-live; no downtime |
| `pre-couchdb.sh` | couchdb plan, pre-backup | stops the container |
| `post-couchdb.sh` | couchdb plan, post-backup, **run on failure too** | restarts it |

`post-couchdb.sh` must be set to run regardless of `BORG_UI_BACKUP_STATUS`, or a
failed backup leaves CouchDB down.

## Before you trust a plan

Two things in this stack are inferred and need one manual check each:

- `docker exec` through the socket proxy. `pre-immich.sh` and `pre-seafile.sh`
  depend on it, and exec needs a connection hijack, which is a different haproxy
  path from the plain stop/start the CouchDB hooks use. From the host:
  `docker exec borg-web-ui docker exec immich_postgres pg_dump --version`.
  If it fails, the fallback is mounting `/var/run/docker.sock` into `app`
  directly and dropping `DOCKER_HOST` — not a rewrite of the hooks.
- `MYSQL_PWD` reaching `mariadb-dump` on MariaDB 10.11. If the dump comes back
  empty, try `MARIADB_PWD` instead.

`LOCAL_MOUNT_POINTS` comma-separation is also inferred; the docs only show the
single `/local` default. If the file browser shows one path, set it to `/local`
and move the three binds under it.

## Backup plan sources

Host paths confirmed from `docker inspect` on gurpgork-bee. `/local/storage` is
`/mnt/storage`.

| Plan | Sources | Excludes |
| --- | --- | --- |
| `immich` | `/local/dumps/immich`, `/local/storage/immich/data/{library,upload,profile}` | `thumbs/`, `encoded-video/` |
| `seafile` | `/local/dumps/seafile`, `/local/storage/seafile/data` | `logs/` |
| `couchdb` | `/local/storage/couchdb/data` (container stopped) | — |
| `media` | `/local/storage/movies`, `/local/storage/music`, `/local/storage/shows` | — |

Immich's `thumbs/` and `encoded-video/` are regenerable; you rerun the transcode
and thumbnail jobs after a restore. The media repo gets `--compression none`:
video and music dedup near zero and compress worse than not at all.

### The live databases are siblings of the data dirs

**The only database content in any archive comes from `/local/dumps`.** A live
database directory is torn by definition; an archive containing one restores to
nothing and looks fine doing it. On this host they sit right next to the data:

| Live DB — never a source | Belongs to |
| --- | --- |
| `/local/storage/immich/db` | `immich_postgres` pgdata |
| `/local/storage/seafile/mysql` | `seafile-mysql` |

So point plans at the specific subdirectories in the table above — never at
`/local/storage`, `/local/storage/immich` or `/local/storage/seafile`.

`/mnt/storage/dumps` is visible at both `/local/dumps` and
`/local/storage/dumps`. Harmless with the sources above, but exclude it from any
plan that widens to a parent.

Never list `/local/backup` as a source, and exclude `/mnt/backup/@timemachine`.

## Not covered yet

- **Borg UI's own `/data`** — holds `.secret_key`, which unlocks every stored
  repo passphrase. It cannot be backed up into a repo Borg UI manages, so it
  goes to the offsite target or a plain `tar` on a schedule. The passphrases
  themselves belong somewhere off this machine regardless.
- **Plane** — all named volumes under `/var/lib/docker/volumes`, so nothing of
  it is reachable from this container yet. `plane_pgdata` needs a dump hook and
  `plane_uploads` needs archiving; the rest (redis, rabbitmq, logs, proxy) is
  disposable.
- **Retention/prune** — no policy set on any repo yet.
