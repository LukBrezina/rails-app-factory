# appsmoothly.com provisioning

One command per customer, up or down:

```sh
infra/customer up acme acme-owner@example.com
infra/customer down acme
```

`up` creates everything: an Infomaniak VPS (Caddy on public 80/443 → Authelia
email login with passkeys → the factory's browser terminal), a GCS bucket
whose 30-day retention makes backups undeletable even with stolen keys, a
Mailgun sending domain + SMTP credential, and **all DNS records** in the
Designate zone (customer A + wildcard, Mailgun SPF/DKIM/tracking). `down`
destroys the box, its credentials, mail domain and DNS — the bucket stays on
purpose (the backup history is the one thing teardown must not shred; purge it
after retention with `gcloud storage rm -r gs://appsmoothly-<name>`).

All credentials live in **one file**: `cp .env.example .env`, fill it in, and
`infra/customer` sources it itself. Run from your laptop only — fleet
credentials never touch customer boxes.

## One-time bootstrap

1. **Infomaniak**: create TWO Public Cloud application credentials in the
   console — one for tofu (the `OS_*` values in `.env`) and one for the admin
   box's backup cron (`TF_VAR_backup_credential_*`). Two because Keystone
   forbids an application credential from creating another one, so tofu can't
   mint the second itself. Verify the flavor/image/network names in
   `variables.tf` against your project:
   `openstack flavor list / image list / network list` (also `admin_flavor`).
2. **Google**: a service account with Storage Admin, its JSON key path in
   `.env`, then the state bucket (state can't create its own home):

   ```sh
   gcloud storage buckets create gs://appsmoothly-tofu-state --location=europe-west6 --uniform-bucket-level-access
   gcloud storage buckets update gs://appsmoothly-tofu-state --versioning
   ```
3. **Mailgun**: API key into `.env`.
4. **Nameservers** (once ever): after the first `tofu init && tofu apply`
   creates the `appsmoothly.com` Designate zone, look up its assigned
   nameservers (`openstack recordset list appsmoothly.com.` — the NS records)
   and set them as appsmoothly.com's nameservers at the domain registrar.
   Every customer record after that is fully automatic. (Designate on
   Infomaniak is BETA — free during beta; if it misbehaves, records are
   plain A/TXT/CNAME you can mirror manually at any DNS host.)

## After `up` (~15 min first boot — ruby compiles)

```sh
ssh ubuntu@<ip> tail -f /var/log/appsmoothly-provision.log   # done: …provision.done
ssh ubuntu@<ip> sudo cat /root/authelia-admin-password.txt
```

Open `https://terminal.<name>.appsmoothly.com`, sign in as `admin`, register a
passkey, sign Claude + GitHub in on the Get started page, **+ ADD APP** (or
connect a template repo), GO LIVE — server and address are prefilled, backups
are already on. Let the customer in:
`ssh ubuntu@<ip> sudo add-user customer@example.com`.

## What lands on the box

| piece | where | why |
|---|---|---|
| Caddy | host, ports 80/443 | TLS + routing: `{cust}` → kamal-proxy :8080, `auth.` → Authelia, `terminal.` + `p-<port>.` previews → forward_auth then upstream |
| Authelia | docker, 127.0.0.1:9091 | file-backend users (`/etc/authelia/users_database.yml`), passkeys, mails via Mailgun |
| factory | systemd, 127.0.0.1:3000, user `claude` | env in `/etc/appsmoothly.env` (`RAF_DOMAIN` = behind-Caddy mode; `RAF_S3_*`/`RAF_SMTP_*` make backups + email work out of the box) |
| kamal-proxy | docker, 127.0.0.1:8080 | pinned there by the factory's first deploy (`proxy boot_config`); Caddy terminates TLS |
| litestream | kamal accessory (per app) | streams SQLite WAL to the bucket every 30 s — data survives the box |
| backup-code | `/etc/cron.daily` | nightly `git bundle` of every app (all branches) → `code/` in the bucket — code survives the box |
| add-user | `/usr/local/bin` (root) | Authelia user management until a proper workspace-user script exists |

Kamal deploys to `localhost` (the `claude` user's key is root-authorized,
loopback only).

## The admin box + machine images

`tofu apply` also creates **appsmoothly-admin**: a tiny always-on box that is
deliberately NOT a customer box — no Caddy, no Authelia, no factory, nothing
listening but key-only SSH. It exists for two things:

- **Stable IP.** Customer boxes accept SSH from it (and from your
  `admin_cidr`), so when your home IP changes you jump through it instead of
  re-applying: `ssh -J ubuntu@<admin-ip> ubuntu@<customer-ip>`.
- **The backup cron.** Infomaniak's OpenStack has no backup *scheduler*
  ("there is no integrated automated backup", their docs), but whole-machine
  images are in the API. `/etc/cron.daily/backup-fleet` on the admin box
  images every `appsmoothly-*` server (self-discovering — new customers are
  covered automatically), keeping the last 7. Log:
  `/var/log/backup-fleet.log`. It holds exactly one credential: the second
  application credential — no GCP, no Mailgun, no tofu state, so owning the
  admin box never means owning the platform.

Restore is pure provider machinery, none of this repo's code involved:
`openstack server rebuild --image <backup-image> appsmoothly-<name>`.
`infra/backup-fleet` (the laptop script) stays for ad-hoc images before risky
changes. Boxes can be unresponsive for a couple of minutes while imaging —
hence a nightly cron. Infomaniak's SwissBackup (agent-in-instance to their
separate backup infra) remains the managed alternative if this ever needs to
be provider-hosted; it's per-device and console-managed, so it's not wired
into the one-command flow.

Layered recovery, worst case first: machine image (whole box, provider-side)
→ bucket (litestream data + nightly code bundles + Authelia users/passkeys
tar under `box/`) → git history inside each app.

## Still deliberate gaps

- fail2ban / unattended-upgrades / a sudo-whitelisted user-management script —
  the guardrails phase before strangers get accounts.
- Billing, metering, git remotes: not POC.

## First-box smoke test, in risk order

1. `infra/customer up` runs clean; the Designate zone + records exist
   (`openstack recordset list appsmoothly.com.`).
2. Authelia login works on your phone (passkey on mobile Safari) and a
   password-reset mail arrives (proves Mailgun + its DNS).
3. Terminal loads, session starts, preview link (`p-<port>.`) serves.
4. GO LIVE: first deploy pins kamal-proxy to loopback (`docker port
   kamal-proxy`), then `https://<name>.appsmoothly.com` serves the app; the
   registry "remote port forwarding failed" warning is harmless noise.
5. Ask Claude in a session for restore points (`litestream snapshots`), then
   rewind five minutes (`bin/restore-prod` quoting is the least-tested code).
6. Force `sudo /etc/cron.daily/backup-code`, confirm `code/*.bundle` and
   `box/authelia-*.tgz` in the bucket, and `git clone` one bundle locally.
7. On the admin box: `sudo /etc/cron.daily/backup-fleet`, wait for the image
   to go active (`openstack image list`), then the full drill on a throwaway
   change: `openstack server rebuild --image ... appsmoothly-<name>`. Also
   confirm the jump path: `ssh -J ubuntu@<admin-ip> ubuntu@<customer-ip>`.
8. From outside: only 80/443 answer. Then `infra/customer down` + `up` again —
   the whole point.
