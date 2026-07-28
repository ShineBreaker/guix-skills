# Dotfiles deployment — the dual-track pattern

Many Guix config repos split user dotfiles into two deployment strategies. This file describes the **generic pattern** so you can apply it to any repo; `repo-guix-configs-example.md` shows one concrete instance.

## Why two tracks

A dotfile you edit daily (emacs, shell, editor config) wants **edit-and-go**: change the file, it's live immediately, and git tracks the source. A dotfile that belongs to a _managed system profile_ (window-manager, desktop, system utilities) wants **reproducible deployment**: rebuilt from source on every reconfigure, frozen into the store.

These two wants pull in opposite directions, so repos split them:

| Track     | Mechanism (common)                            | After you edit the source            | Symlink points to                          |
| --------- | --------------------------------------------- | ------------------------------------ | ------------------------------------------ |
| Immutable | Guix Home `home-dotfiles-service-type` (stow) | re-run the home runner (`blue home`) | a `/gnu/store/<hash>-…` **read-only copy** |
| Mutable   | GNU Stow directly (`blue stow <pkg>`)         | live immediately                     | the repo source tree                       |

## The one hard rule

`~/.config/<app>/<file>` is **always a symlink** — either to a store copy (immutable track) or to the repo source (mutable track). **Never edit the live file.** Two failure modes if you do:

- Immutable track: your edit lands on a frozen store copy and is **blown away** on the next home reconfigure.
- Mutable track: your edit lands on the repo source and **pollutes git** with uncommitted changes you didn't mean to make.

## How to verify a deployment picked up your edit

Because the live file is a symlink, "I edited it but it didn't change" almost always means the store hash didn't move. Confirm:

```bash
# After editing the immutable-track source and re-running the home runner:
md5sum <repo>/dotfiles/immutable/<app>/<file>
md5sum ~/.config/<app>/<file>
readlink ~/.config/<app>/<file>      # if the store hash hasn't changed, neither did your file
```

If the hashes differ (or the symlink's hash is unchanged), the deployment didn't pick up your edit — re-run the home step, or check that the package is actually listed in the dotfiles service configuration.

## Adding / removing an immutable-track package

To add a new `dotfiles/immutable/<app>/` directory: register its package name in the dotfiles service config, then re-run the home runner. To remove one (so `~/.config/<app>/` no longer gets a symlink): remove it from the config **and** delete the source directory from git. Both require a home reconfigure to take effect.

## Single-file deploys

For a file that doesn't fit any package, prefer a `home-files-service-type` entry: a single-file deploy with optional `computed-substitution-with-inputs` for absolute store-path injection (e.g. daemon configs that must not rely on `$HOME` expansion at load time — see `repo-guix-configs-example.md` §15.2 for the concrete `$$bin/...$$` pattern).

## Daemon configs: don't rely on `$HOME` expansion

When a daemon (shepherd, dbus, anything not inheriting a login shell) reads a config file, paths like `~/.guix-home/profile/bin/foo` expand against `$HOME` at config-load time, which may not be what you expect. The blast radius is "service silently falls back to a different path or to tty" — and the fallback is rarely logged. Use absolute `/gnu/store/...` paths via substitution, or your runner's built-in path-expansion syntax.
