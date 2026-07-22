## Section 20: Common foot-guns (verified gotcha library)

These are traps that have actually broken real Guix configs / ISO builds.
Scan this list at the start of any non-trivial task. Repo-specific
instantiations live in `repo-guix-configs-example.md`; the generic dual-track
dotfile rule is in `dotfiles-general.md`.

### 20.1 "I edited the dotfile but my change isn't there"

On the **immutable** (Guix Home stow) track, `~/.config/<app>/<file>` is a
symlink to a `/gnu/store/<hash>-…` copy. If you ran the home step but the hash
didn't move, your edit didn't take. Verify:

```bash
md5sum <repo>/dotfiles/immutable/<app>/<file>
md5sum ~/.config/<app>/<file>
readlink ~/.config/<app>/<file>     # if the store hash hasn't changed, neither did your file
```

(General rule + mutable-track variant: `dotfiles-general.md`.)

### 20.2 The lint step says "unbalanced parens" but you didn't touch parens

The bracket counter can be poisoned by an upstream error. Reproduce in
isolation — stash your change, re-run the lint, and see if the baseline also
errors:

```bash
cd /path/to/your-config-repo
git stash push -m "verify-baseline" -- <your-source-file>   # e.g. source/config.org / config.scm
blue check 2>&1 | head -5          # or your runner's lint command
# If baseline errors too → unrelated issue, fix separately
git stash pop
```

Do **not** panic-edit `channel.lock` or global variable files. Note: the lint
step only balances per-block parens — it cannot catch a _locally_ misplaced
paren whose total still balances; a real `guix build` then fails with `invalid
field specifier` / `wrong-type-arg`. The bracket counter is a smoke test, not a
semantic check.

### 20.3 `(delete kmscon-service-type)` does nothing

`make-installation-os` already enables `kmscon` on tty1 with
`login-program installer` (see §16.1). Deleting it in `modify-services` is either
a no-op (if you didn't have a `cons*` for it) or quietly removes the only copy
(if you did). **Verify the underlying base before using `(delete ...)`.** Read
`gnu/system/install.scm` to confirm.

### 20.4 `(password "")` looks innocent but sudo still asks for it

`make-installation-os` sets `base-pam-services #:allow-empty-passwords? #t` —
empty passwords ARE accepted, so sudo with no password works (use `su` if you
need to). If you switch to `(password #f)` to disable the account, that's a
different signal (account-locked), and sudo will reject with "no auth available"
rather than auto-allow.

### 20.5 substitute URL + local repo source mix badly

If you `guix pull` mid-edit while your `channel.lock` points to commit X, but
your cached substitute is for commit Y, the build can pick up an inconsistent
closure. Always pull / build with the lock:

```bash
guix time-machine --channels=source/channel.lock -- pull
```

### 20.6 Guix git-fetch in CI sandboxes fails with EACCES to `/etc/gitconfig`

`guix-daemon` only passes a whitelist of env vars to build sandboxes;
`GIT_CONFIG_NOSYSTEM` isn't on the list. Result: `git init` in the sandbox dies
with EACCES, guix falls back to bordeaux/SWH mirrors, and the package fails to
fetch. **The reliable workaround is to convert `git-fetch` origins to
`url-fetch`** (GitHub release tarball). On a local system this issue doesn't
surface unless you have an unusual seccomp/apparmor setup, but recipes that
include `git-fetch` may still surprise you in CI.

### 20.7 Daemon "port conflict" assumed from `/proc/net/*`

In sandboxes without `sudo`/`ss`, you'll see `nobody`-uid listeners on 53 / 67 /
etc. from `/proc/net/udp` and be tempted to conclude "another service has the
port". **Almost certainly wrong** — it could be `systemd-resolved`,
`NetworkManager`'s dnsmasq, avahi, libvirt's dnsmasq, or a leftover from a
previous failed start. Always cross-check:

```bash
pgrep -af '<keyword>'                  # see the actual cmdline
ls -l /proc/<pid>/cmdline              # the truth
sudo ss -tlnup 'sport = :<port>'       # if you have it
```

If you see `dnsmasq failed to create listening socket for 10.42.0.1: address
already in use`, that's a NetworkManager hot-spot conflict — fix by binding the
conflicting local DNS daemon to `127.0.0.1:53` only, not `0.0.0.0:53`.

### 20.8 system reconfigure failure cascade

When the lint step reports `unbalanced parens` and the reconfigure reports
`wrong-number-of-args in position N`, the bracket error is downstream of an
`(include "./channel.lock")` failure or a missing `use-modules`. Address the
upstream cause (field name, module path, malformed gexp) first; the bracket
count will normalize.

### 20.9 SJTUG is a mirror, not a signer

If you add SJTUG (or any mirror) to `substitute-urls`, you do **not** need its
key — a mirror re-serves upstream-signed packages and verification uses the
**upstream** key. Add the mirror's URL, don't add the mirror's key.

### 20.10 `guix-daemon` substitute deduplication EACCES on btrfs

A `privileged? #f` guix-daemon (CapEff=0) on a btrfs store hits `EACCES` from
`rename-file` inside the deduplication pass (`deduplication.scm:124`
`replace-with-link`) during `guix substitute`. This is **not** nar corruption,
not a read-only mount, not `privileged? #f` itself — it's the post-restore dedup
pass. Fix: add `--disable-deduplication` to the daemon's `extra-options`
(restart the daemon manually, reconfigure, then later bake it into your config).
`--no-substitutes` also avoids it but forces full local builds. Leftover
`guix-directory-*` junk needs `sudo rm -rf` to clear (plain `guix gc` won't
collect it). _Verified 2026-07-08._

## Section 21: Examples directory — what each one is for

The skill ships a few starter `.scm` templates (under `examples/`) that
demonstrate one canonical pattern each. They are **starter templates, not** a
live config — check each file's header for the WARNING line.

| File                       | What it demonstrates                                                             |
| -------------------------- | -------------------------------------------------------------------------------- |
| `examples/bare-bones.scm`  | Minimal headless/server: dhcpcd + openssh + nonguix transformation               |
| `examples/desktop.scm`     | KDE Plasma + LUKS (a common beginner choice)                                     |
| `examples/home-config.scm` | `home-environment` shape: bash aliases + minimal packages                        |
| `examples/channel.scm`     | Channel declarations with nonguix (+ optionally a desktop channel) introductions |

**Important:** a real config repo's live `config.org` / `config.scm` has
diverged from these templates. Don't copy example code back into a live config
without reading its current comments first.
