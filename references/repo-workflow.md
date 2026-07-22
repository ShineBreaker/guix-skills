# Working from a Guix config repo (generic)

This file covers the cross-cutting habits that apply to **any** Guix
configuration repository that follows the task-runner + tangled-source pattern
(introduced in `blue-runner.md`). Repo-specific detail for one concrete instance
is in `repo-guix-configs-example.md`.

## Generate, then lint, before you apply

If the repo keeps its config as **source** (Org Noweb blocks tangled into
Scheme, or a generator), never edit the deployed `/etc/config.scm` or
`~/.config` files by hand. The loop is always:

1. Edit the **source** file (e.g. `config.org`, or a `.scm` in the repo).
2. Run the runner's generate + lint step (e.g. `blue check`) — fast, no sudo.
3. Apply via the runner (`blue home`, or `blue rebuild` with sudo).
4. **Verify the deployment actually picked up your edit** — see
   `dotfiles-general.md` for the md5sum / `readlink` check.

## Channel locking is the reproducibility contract

Every build should pin channels (`channels.lock`). The generic rationale and the
`guix time-machine --channel … -- describe --format=channels > channels.lock`
recipe live in `beginner-home.md` §10.5. When debugging a record type or field
name, always probe against the **locked** channels, not whatever `guix pull`
left in your cache — see `blue-runner.md` for the `guix repl` probe.

## Shepherd: two daemons, two privilege levels

`home-shepherd` (per-user) and the system Shepherd are separate. General rule:

- **System services** need sudo to inspect/restart → an unattended agent should
  not touch them; ask a human.
- **Home services** need no sudo → an agent may `herd restart`/`herd status`
  them, but note that re-running the home runner does **not** auto-restart an
  already-running home-shepherd — you must `herd restart <service>` yourself and
  confirm via `herd status`.

See `repo-guix-configs-example.md` §"Shepherd debugging" for repo-specific
gotchas (cached PID, `WAYLAND_DISPLAY` non-inheritance).

## Keep generations until you're sure

`guix system` / `guix home` keep generations. Don't delete old ones until the
new configuration is confirmed working — roll-back is your safety net.

## Where to go next

- Editing dotfiles → `dotfiles-general.md`
- Building a Live ISO → `iso-build.md`
- FHS container for an Electron/AppImage binary → `advanced.md` §17
- Repo's actual command list & directory layout → `repo-guix-configs-example.md`
- Verified gotchas library → `foot-guns.md`
