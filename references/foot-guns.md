## Section 20: Common foot-guns (verified gotcha library)

These are traps that have actually broken real Guix configs / ISO builds. Scan this list at the start of any non-trivial task. Repo-specific instantiations live in `repo-guix-configs-example.md`; the generic dual-track dotfile rule is in `dotfiles-general.md`.

### 20.1 "I edited the dotfile but my change isn't there"

On the **immutable** (Guix Home stow) track, `~/.config/<app>/<file>` is a symlink to a `/gnu/store/<hash>-…` copy. If you ran the home step but the hash didn't move, your edit didn't take. Verify:

```bash
md5sum <repo>/dotfiles/immutable/<app>/<file>
md5sum ~/.config/<app>/<file>
readlink ~/.config/<app>/<file>     # if the store hash hasn't changed, neither did your file
```

(General rule + mutable-track variant: `dotfiles-general.md`.)

### 20.2 The lint step says "unbalanced parens" but you didn't touch parens

The bracket counter can be poisoned by an upstream error. Reproduce in isolation — stash your change, re-run the lint, and see if the baseline also errors:

```bash
cd /path/to/your-config-repo
git stash push -m "verify-baseline" -- <your-source-file>   # e.g. source/config.org / config.scm
blue check 2>&1 | head -5          # or your runner's lint command
# If baseline errors too → unrelated issue, fix separately
git stash pop
```

Do **not** panic-edit `channel.lock` or global variable files. Note: the lint step only balances per-block parens — it cannot catch a _locally_ misplaced paren whose total still balances; a real `guix build` then fails with `invalid field specifier` / `wrong-type-arg`. The bracket counter is a smoke test, not a semantic check.

### 20.3 `(delete kmscon-service-type)` does nothing

`make-installation-os` already enables `kmscon` on tty1 with `login-program installer` (see §16.1). Deleting it in `modify-services` is either a no-op (if you didn't have a `cons*` for it) or quietly removes the only copy (if you did). **Verify the underlying base before using `(delete ...)`.** Read `gnu/system/install.scm` to confirm.

### 20.4 `(password "")` looks innocent but sudo still asks for it

`make-installation-os` sets `base-pam-services #:allow-empty-passwords? #t` — empty passwords ARE accepted, so sudo with no password works (use `su` if you need to). If you switch to `(password #f)` to disable the account, that's a different signal (account-locked), and sudo will reject with "no auth available" rather than auto-allow.

### 20.5 substitute URL + local repo source mix badly

If you `guix pull` mid-edit while your `channel.lock` points to commit X, but your cached substitute is for commit Y, the build can pick up an inconsistent closure. Always pull / build with the lock:

```bash
guix time-machine --channels=source/channel.lock -- pull
```

### 20.6 Guix git-fetch in CI sandboxes fails with EACCES to `/etc/gitconfig`

`guix-daemon` only passes a whitelist of env vars to build sandboxes; `GIT_CONFIG_NOSYSTEM` isn't on the list. Result: `git init` in the sandbox dies with EACCES, guix falls back to bordeaux/SWH mirrors, and the package fails to fetch. **The reliable workaround is to convert `git-fetch` origins to `url-fetch`** (GitHub release tarball). On a local system this issue doesn't surface unless you have an unusual seccomp/apparmor setup, but recipes that include `git-fetch` may still surprise you in CI.

### 20.7 Daemon "port conflict" assumed from `/proc/net/*`

In sandboxes without `sudo`/`ss`, you'll see `nobody`-uid listeners on 53 / 67 / etc. from `/proc/net/udp` and be tempted to conclude "another service has the port". **Almost certainly wrong** — it could be `systemd-resolved`, `NetworkManager`'s dnsmasq, avahi, libvirt's dnsmasq, or a leftover from a previous failed start. Always cross-check:

```bash
pgrep -af '<keyword>'                  # see the actual cmdline
ls -l /proc/<pid>/cmdline              # the truth
sudo ss -tlnup 'sport = :<port>'       # if you have it
```

If you see `dnsmasq failed to create listening socket for 10.42.0.1: address already in use`, that's a NetworkManager hot-spot conflict — fix by binding the conflicting local DNS daemon to `127.0.0.1:53` only, not `0.0.0.0:53`.

### 20.8 system reconfigure failure cascade

When the lint step reports `unbalanced parens` and the reconfigure reports `wrong-number-of-args in position N`, the bracket error is downstream of an `(include "./channel.lock")` failure or a missing `use-modules`. Address the upstream cause (field name, module path, malformed gexp) first; the bracket count will normalize.

### 20.9 SJTUG is a mirror, not a signer

If you add SJTUG (or any mirror) to `substitute-urls`, you do **not** need its key — a mirror re-serves upstream-signed packages and verification uses the **upstream** key. Add the mirror's URL, don't add the mirror's key.

### 20.10 `guix-daemon` substitute deduplication EACCES on btrfs

A `privileged? #f` guix-daemon (CapEff=0) on a btrfs store hits `EACCES` from `rename-file` inside the deduplication pass (`deduplication.scm:124` `replace-with-link`) during `guix substitute`. This is **not** nar corruption, not a read-only mount, not `privileged? #f` itself — it's the post-restore dedup pass. Fix: add `--disable-deduplication` to the daemon's `extra-options` (restart the daemon manually, reconfigure, then later bake it into your config). `--no-substitutes` also avoids it but forces full local builds. Leftover `guix-directory-*` junk needs `sudo rm -rf` to clear (plain `guix gc` won't collect it). _Verified 2026-07-08._

## Section 21: Examples directory — what each one is for

The skill ships a few starter `.scm` templates (under `examples/`) that demonstrate one canonical pattern each. They are **starter templates, not** a live config — check each file's header for the WARNING line.

| File                       | What it demonstrates                                                             |
| -------------------------- | -------------------------------------------------------------------------------- |
| `examples/bare-bones.scm`  | Minimal headless/server: dhcpcd + openssh + nonguix transformation               |
| `examples/desktop.scm`     | KDE Plasma + LUKS (a common beginner choice)                                     |
| `examples/home-config.scm` | `home-environment` shape: bash aliases + minimal packages                        |
| `examples/channel.scm`     | Channel declarations with nonguix (+ optionally a desktop channel) introductions |

**Important:** a real config repo's live `config.org` / `config.scm` has diverged from these templates. Don't copy example code back into a live config without reading its current comments first.

## Section 22: niri + xdg-desktop-portal + Flatpak on Guix (verified)

Portal / screen-cast / file-picker breakage on a Guix + niri desktop is almost never about the portal **backend** you picked. It is usually a D-Bus **session bus** problem: which bus an app lands on decides whether its portal calls reach a healthy backend. Scan §22.1–§22.3 before any portal/flatpak debugging; §22.4 corrects an outdated assumption; §22.5 is the defensive fix; §22.6 is a diagnosis-method trap. _Verified 2026-07-28 on niri 26.04 / xdg-desktop-portal 1.20.3._

### 22.1 Two session D-Bus buses is the *normal* topology, not a misconfiguration

A greetd-launched `dbus-run-session niri --session` creates one user bus (`/tmp/dbus-XXXX`); `home-dbus-service-type` creates another (`/run/user/1000/bus`). **Both coexist by design** — the Rosenthal channel's `%rosenthal-desktop-home-services` preset includes `(service home-dbus-service-type)`, so reference configs have two buses too. Do not "fix" this by deleting one.

The two buses carry **different environments**:

- niri's `dbus-run-session` bus gets `XDG_SESSION_TYPE=wayland` and `XDG_CURRENT_DESKTOP=niri`, because `niri --session` internally runs `dbus-update-activation-environment`. Portals D-Bus-activated on this bus are healthy.
- The `home-dbus` bus keeps the login environment (often `XDG_SESSION_TYPE=tty`). A portal backend activated there hits `gxdp_init_gtk()`, which rejects anything but `wayland`/`x11` and falls back to **"Non-compatible display server, exposing settings only"** — no FileChooser, no ScreenCast.

Consequence: an app's portal behaviour depends on **which bus it inherited**, not on `portals.conf`. Inspect the per-process bus before blaming the backend:

```bash
tr '\0' '\n' < /proc/<pid>/environ | grep -E '^DBUS_SESSION_BUS_ADDRESS|^XDG_SESSION_TYPE'
busctl --user list | grep -i portal     # shows the bus YOUR shell is on — may not be the app's
```

### 22.2 Diagnose on the bus the app actually uses (the #1 false-conclusion trap)

`busctl --user` / `gdbus` run against **your shell's** `$DBUS_SESSION_BUS_ADDRESS`. If your shell is on `/run/user/1000/bus` but the failing app is on `/tmp/dbus-XXXX` (or vice-versa), every probe hits the wrong portal stack and you draw the wrong conclusion. Pin the bus explicitly:

```bash
# Probe niri's bus directly:
DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-XXXX busctl --user call \
  org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
  org.freedesktop.portal.Settings.Read ss org.freedesktop.appearance color-scheme

# Or probe from inside a Flatpak sandbox (its proxy bridges to the launch-time bus):
flatpak run --command=sh <app> -c 'gdbus call --session \
  --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Documents.GetMountPoint'
```

A Flatpak app launched **from niri** (terminal / autostart) lands on `/tmp/dbus-XXXX`; one launched **from a shepherd service such as noctalia** lands on `/run/user/1000/bus`. That single fact can explain "file-picker broken only some of the time".

**Anti-pattern:** running `xdg-document-portal` (or any portal) in the foreground during diagnosis. It races the live instance for the `org.freedesktop.portal.Documents` name and the `/run/user/1000/doc` FUSE mount, silently corrupts the running stack, and produces misleading `Permission denied` / `rc=6` errors that look like a real fault. Read `/proc/<portal-pid>/environ` instead; never spawn a competing instance.

### 22.3 xdg-document-portal FUSE stale-mount wedge

`xdg-document-portal` owns the `/run/user/1000/doc` FUSE mount that exposes picked files into Flatpak sandboxes. If a second instance starts (a re-activation racing a lingering mount, or a foreground probe — see §22.2), it cannot mount over the live/stale mountpoint and dies:

```
fusermount3: failed to access mountpoint /run/user/1000/doc: Permission denied
error: fuse init failed: Can't mount path /run/user/1000/doc
# process exits rc=6 → callers see "NoReply: recipient disconnected"
```

Recover by clearing the mount and letting D-Bus activate a single clean instance:

```bash
fusermount -uz /run/user/1000/doc        # lazy-unmount the stale/stuck mount
busctl --user call org.freedesktop.portal.Documents \
  /org/freedesktop/portal/documents org.freedesktop.portal.Documents.List s ""  # re-activates
mount | grep /run/user/1000/doc          # expect exactly one fuse.portal line
```

### 22.4 niri ≥ 26.04 ships the GNOME portal D-Bus API — gnome screen-cast works

niri itself registers these names on the user bus (owner = the niri process): `org.gnome.Mutter.ServiceChannel`, `org.gnome.Mutter.ScreenCast`, `org.gnome.Mutter.DisplayConfig`, `org.gnome.Shell.Screenshot`, `org.gnome.Shell.Introspect`. Because of this Mutter-compat layer, `xdg-desktop-portal-gnome`'s **ScreenCast / Screenshot work under niri** — which is exactly why niri upstream recommends the gnome portal.

Any note claiming "the gnome portal can only expose Settings under niri" is **outdated** (it predates niri's Mutter-compat layer). Verify live:

```bash
busctl --user list | grep -E 'org.gnome.(Mutter|Shell)'   # owner should be niri's pid
```

One routing rule still holds: send **FileChooser to gtk**, because the gnome backend's file chooser needs nautilus. In `<desktop>-portals.conf` (e.g. `niri-portals.conf`): `org.freedesktop.impl.portal.FileChooser=gtk`.

### 22.5 Unify the graphical session onto niri's (healthy) bus — defensive fix

To make shepherd-managed graphical services (noctalia, …) and the apps **they** launch use niri's verified-healthy `/tmp` bus instead of the tty-env home-dbus bus, propagate the bus address through the same `herd set-environment` line that already propagates `XDG_CURRENT_DESKTOP` in niri's `config.kdl`:

```kdl
spawn-sh-at-startup "herd set-environment graphical-session XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP XDG_SESSION_TYPE=$XDG_SESSION_TYPE NIRI_SOCKET=$NIRI_SOCKET DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS PATH=..."
```

This reuses a proven channel (noctalia already receives `XDG_CURRENT_DESKTOP=niri` this way). Takes effect on next login. Verify afterwards:

```bash
tr '\0' '\n' < /proc/$(pgrep -x noctalia)/environ | grep DBUS_SESSION_BUS_ADDRESS
# expect: unix:path=/tmp/dbus-XXXX  (niri's bus), NOT /run/user/1000/bus
```

**Scope of "redundant" — read carefully.** The above says `environment {}` and `dbus-update-activation-environment` are redundant **for the portal / session-type variables** (`XDG_SESSION_TYPE`, `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, `DBUS_SESSION_BUS_ADDRESS`) because `niri --session` already pushes those itself.

That does **NOT** mean the IME/input-method "三件套" (`GTK_IM_MODULE`, `QT_IM_MODULE`, `XMODIFIERS`, `SDL_IM_MODULE`, `GLFW_IM_MODULE`, proxy, font vars) is redundant. niri does **not** set those — `guix-configs-workflow` §6 / `niri-gui-environment-injection.md` is still correct for IME/Electron-input problems. Keep `herd set-environment` for those variables; just don't re-add the portal/session-type ones that niri manages.

### 22.6 "Config X isn't there" — check channel service presets before concluding

A config repo's top-level `config.org` often pulls in a **channel-provided service preset** (e.g. `%rosenthal-desktop-services/tuigreet`, `%rosenthal-desktop-home-services`) that internally adds greetd, home-dbus, pipewire, and more. Reading only the top-level file yields false "X is not configured" conclusions — this exact mistake produced a wrong root-cause call during the 2026-07-28 portal investigation. When a preset symbol is referenced, **read the preset's module source** (e.g. `(rosenthal services desktop)`) before asserting what is or isn't enabled:

```bash
# locate the channel checkout, then read the preset definition
find ~/.cache/guix/checkouts -path '*rosenthal/services/desktop.scm'
grep -n 'home-dbus-service-type\|greetd-service-type' <that-file>
```

### 22.7 Portal config filename silently breaks Flatpak: generic `portals.conf` vs `<desktop>-portals.conf`

xdg-desktop-portal reads the generic `portals.conf` **unconditionally** (it is the base config). A desktop-specific `<XDG_CURRENT_DESKTOP>-portals.conf` is read **only** when that desktop appears in `XDG_CURRENT_DESKTOP`, and overrides the base per interface. On the dual-bus niri setup this distinction is load-bearing:

- Flatpak talks to the portal frontend on `/run/user/1000/bus` (`$XDG_RUNTIME_DIR/bus`). That frontend is D-Bus-activated **without** `XDG_CURRENT_DESKTOP` → it reads **only** the generic `portals.conf`.
- The niri-bus frontend (`/tmp/dbus-XXXX`, `XDG_CURRENT_DESKTOP=niri`) reads `niri-portals.conf` and works.

**The foot-gun:** name the routing file `niri-portals.conf` instead of the generic `portals.conf` and the home-bus frontend (Flatpak's) reads *nothing* → no `org.freedesktop.impl.portal.Settings` backend → Flatpak loses the appearance `color-scheme` (**dark/light following breaks**), plus FileChooser/Access routing. The niri-bus frontend still works, so the native desktop looks fine and the bug hides. darkman is innocent — both instances stay healthy with `portal: true`; the break is purely the frontend finding no routing file. This repo's documented canonical name is the generic `portals.conf` (`desktop/AGENTS.md` tree); a `portals.conf → niri-portals.conf` rename is the regression (find it with `git log --follow`).

Diagnose by comparing the two buses — home bus fails, niri bus answers:

```bash
# Flatpak's bus — expect `v u N`; rc=1 / empty = the bug
busctl --user --address="unix:path=/run/user/1000/bus" call \
  org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
  org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme
# niri's bus — works (has XDG_CURRENT_DESKTOP=niri)
busctl --user --address="unix:path=/tmp/dbus-XXXX" call \
  org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
  org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme
```

Fix: keep the routing in the **generic `portals.conf`** so both frontends load it regardless of `XDG_CURRENT_DESKTOP`. Do **not** "fix" it by pushing `XDG_CURRENT_DESKTOP=niri` into the home bus's activation environment (`dbus-update-activation-environment`) — that fights the dual-bus design and rots.

One merge detail: the **niri package itself** ships a `niri-portals.conf` into `XDG_DATA_DIRS` (`<niri-store>/share/xdg-desktop-portal/niri-portals.conf`) with `default=gnome;gtk` + Access/Notification/Secret but **no `Settings=` line**, so the user `portals.conf`'s `Settings=darkman` still wins on the niri bus (verified). If a future niri release adds a `Settings=` line there, it would override the user file on the niri bus — re-check that file if Flatpak theming breaks again after a niri update.

_Verified 2026-07-29 on niri 26.04 / xdg-desktop-portal 1.20.3: home-bus ReadOne went rc=1 → `v u 1` after restoring generic `portals.conf`; the portal tracked a live darkman mode toggle `v u 1 ↔ v u 2`._

### 22.8 noctalia `(environ)` race: missing WAYLAND_DISPLAY in set-environment breaks Flatpak filechooser + screencast

Rosenthal's `home-noctalia-service-type` starts noctalia with `#:environment-variables (environ)` — inheriting shepherd's **process-global** environment at fork time. `herd set-environment` (custom action on `graphical-session`) calls `putenv` on the shepherd process, so the update is visible to all subsequent `(environ)` calls. But `spawn-sh-at-startup` in config.kdl only fires once at niri boot.

**The foot-gun:** if the set-environment line omits `WAYLAND_DISPLAY`, noctalia's env may lack it (niri's built-in propagation via `dbus-update-activation-environment` only affects D-Bus activation env, not shepherd's process env). Without `WAYLAND_DISPLAY`, gtk portal cannot create a filechooser window → Flatpak filechooser fails. If `DBUS_SESSION_BUS_ADDRESS` also points to the home bus (race: noctalia started before set-environment ran), gnome portal's screencast backend cannot find niri's Mutter ScreenCast API (registered only on niri's /tmp bus) → screencast fails too.

**Symptoms:** Flatpak filechooser + screencast both broken simultaneously; native apps fine; `herd restart noctalia` fixes it (because by then putenv has run and shepherd global env is correct).

**Fix:** include `WAYLAND_DISPLAY=$WAYLAND_DISPLAY` in the config.kdl `herd set-environment graphical-session ...` line. Combined with `spawn-sh-at-startup "herd restart noctalia"` (fires after set-environment), noctalia always gets the full correct env on niri boot.

**Residual risk:** if `blue home` restarts noctalia mid-session AND shepherd's process-global env has been reset (shepherd process restart, rare), the race recurs. Mitigation: `herd restart noctalia` manually after such events.

```bash
# Verify noctalia's env points to niri's bus
cat /proc/$(pgrep -x noctalia)/environ | tr '\0' '\n' | grep -E 'DBUS_SESSION|WAYLAND_DISPLAY'
# Expect: DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-...  and  WAYLAND_DISPLAY=wayland-1
# If DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus → wrong bus → restart noctalia
```

_Verified 2026-07-31: adding WAYLAND_DISPLAY to set-environment line; noctalia env confirmed correct after manual restart._

### 22.9 `home-dotfiles-service-type` only reads git-staged content — unstaged edits silently ignored by `blue home`

Guix Home's `home-dotfiles-service-type` (with `directories` pointing to a repo path) uses git-aware file acquisition internally. **Unstaged working-tree modifications are NOT included in the build** — `blue home` succeeds but deploys the old content from the git index.

**The foot-gun:** edit a dotfile → `blue home` → symlink timestamp updates → but the deployed store copy still has the old content. No error, no warning. You think your fix is live but it isn't.

**Fix:** always `git add <file>` before `blue home`. Verify with `grep <your-change> "$(readlink -f ~/.config/<path>)"` after deploy.

```bash
# After editing a dotfile:
git add dotfiles/immutable/desktop/.config/niri/config.kdl
blue home
# Verify:
grep 'YOUR_CHANGE' "$(readlink -f ~/.config/niri/config.kdl)"
```

_Verified 2026-07-31: first `blue home` after editing config.kdl deployed old content (no WAYLAND_DISPLAY); after `git add` + second `blue home`, new content appeared in store._

### 22.10 Manual `herd set-environment` from a non-niri shell overwrites niri's bus address

`herd set-environment graphical-session ... DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS` expands `$DBUS_SESSION_BUS_ADDRESS` in the **calling shell's** environment. If you run this from a TTY, SSH session, or any shell on `/run/user/1000/bus`, it overwrites shepherd's global env with the home bus address — destroying the correct `/tmp/dbus-XXXX` value that niri's `spawn-sh-at-startup` set.

**The foot-gun:** after such a manual call, every subsequent `herd restart` of a graphical-session service (noctalia, hermes-backend, etc.) gives it the wrong bus → Flatpak filechooser + screencast break again.

**Why spawn-sh-at-startup is safe:** it runs inside niri's process environment (created by `dbus-run-session`), so `$DBUS_SESSION_BUS_ADDRESS` expands to `/tmp/dbus-XXXX` automatically.

**Recovery:** re-run set-environment with the explicit niri bus address (obtain from `cat /proc/$(pgrep -x niri)/environ | tr '\0' '\n' | grep DBUS_SESSION`), then `herd restart noctalia`.

**Rule:** NEVER run `herd set-environment` manually unless you explicitly pass the niri bus address as a literal string — never via shell variable expansion from a non-niri shell.

_Verified 2026-07-31: accidentally overwrote shepherd global env from home-bus shell; noctalia got /run/user/1000/bus; fixed by re-running with literal /tmp/dbus-okh26FqpoL address._
