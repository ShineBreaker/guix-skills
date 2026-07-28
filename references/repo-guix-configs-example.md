# Concrete instance — the `Guix-configs` family of repos

This file documents **one specific** repository that follows the `blue` pattern (`blueprint.scm` + `source/config.org` + dual-track dotfiles). It is an _example_, not a prescription — other repos implement the same ideas differently. Read `blue-runner.md` and `dotfiles-general.md` first for the generic pattern; this is the "here's how one real repo does it" companion.

> Paths below use `~/Projects/Config/Guix-configs` as the concrete checkout. Substitute your own checkout path wherever you see it.

## The `blue` subcommand set (this repo)

Defined in `blueprint.scm`; each wraps `guix` for a safe, repeatable workflow.

```bash
blue help              # all subcommands, each with its own listing
blue check             # fast bracket-balance lint on the tangled config
blue home              # build + activate Guix Home (user only, no sudo)
blue rebuild           # build + activate system AND home (sudo required)
blue build-iso         # build a Live ISO via `guix system image`
blue upgrade           # run scripts/check-updates/update_versions.py
blue gen-docs          # regenerate docs/packages.md from current modules
blue import-crate <c>  # import a Rust crate into rust-crates.scm
blue structor [path]   # regenerate AGENTS.md directory-tree sections
blue stow <pkg>        # reconcile a dotfiles/mutable/<pkg> via GNU Stow
```

Agent rule (see `blue-runner.md`): never run `blue rebuild` unattended; `check` / `home` / `stow` / `build-iso` are agent-safe.

## Source: `source/config.org` (Org + Noweb tangle)

The single `config.scm` is split across 100+ `#+begin_src scheme` blocks with `<<ref>>` Noweb includes. `blue check` runs `org-babel-tangle-file` plus a bracket-balance check. The bracket check is a smoke test only — see `blue-runner.md` for what it misses and the `guix repl` probe alternative.

Run `blue check` from the **repo root** before any commit that touches `config.org`.

## Dotfiles dual-track (this repo's directories)

| Track     | Directory                   | Deploy                                                                                        | Effective after                   |
| --------- | --------------------------- | --------------------------------------------------------------------------------------------- | --------------------------------- |
| Immutable | `dotfiles/immutable/<app>/` | Guix Home `home-dotfiles-service-type` (stow) → `/gnu/store/<hash>` copy symlinked to `$HOME` | `blue home` rebuilds the symlink  |
| Mutable   | `dotfiles/mutable/<pkg>/`   | GNU Stow directly (`blue stow <pkg>`)                                                         | edit-and-go (symlink is the file) |

The dotfile service hierarchy lives in the `dotfile-services` block of `config.org`:

```scheme
(service home-dotfiles-service-type
  (home-dotfiles-configuration
   (directories '("../dotfiles/immutable"))
   (layout 'stow)
   (packages '("agents" "desktop"
               "noctalia-suite" "system" "terminal" "utilities"))
   (excluded '("\\.agents/workfile($|/.*)" ...))))
```

Add a package → add its name to `packages`; remove one → remove from `packages` **and** `git rm` the directory; both need `blue home` to take effect.

For a single-file deploy, use `home-files-service-type` with `computed-substitution-with-inputs`:

```scheme
(".local/share/gnupg/gpg-agent.conf" ,(computed-substitution-with-inputs
                                       "gpg-agent.conf"
                                       (local-file "../source/files/gpg-agent.conf")
                                       (specs->pkgs "pinentry-qt")))
```

## Shepherd debugging (this repo)

`home-shepherd` (per-user) and the system Shepherd are separate daemons.

```bash
pkexec herd status nscd        # system service (sudo — agents should not run)
herd status hermes             # user service (no sudo — agents may run)
```

Two gotchas specific to home-shepherd:

1. **Cached PID is not authoritative.** `make-forkexec-constructor` doesn't `wait` for its child; if the service dies, shepherd still caches the old PID. Truth lives in `/var/log/messages` and `/proc/<pid>/cmdline`.
2. **home-shepherd does not inherit `WAYLAND_DISPLAY`.** Services that talk to wayland clients must dynamically discover `$XDG_RUNTIME_DIR/wayland-*` at start — don't hard-code it.

After editing a service definition: `blue home` does **not** restart an already-running home-shepherd, so also `herd restart <service>` and check the `命令:` line in `herd status`. If it doesn't update, you may have two home-shepherd daemons — `pgrep -af "shepherd-for-home"` ( >1 PID = parallel), kill the older one, then restart.

### Daemon config path injection (`$$bin/...$$`)

Daemon configs must not rely on `$HOME` expansion at load time. Use absolute store paths via `computed-substitution-with-inputs`, or this repo's `$$bin/x$$` syntax (expanded by the build system):

```scheme
;; WRONG — relies on $HOME expansion at unknown time
pinentry-program ~/.guix-home/profile/bin/pinentry-qt

;; RIGHT — compiled to absolute store path at build time
pinentry-program $$bin/pinentry-qt$$
```

## Age-encrypted secrets (this repo's layout)

Secrets are encrypted with `age`, stored in-tree; private keys live out-of-tree.

```
<repo>/
  dotfiles/secrets/
    .keys/age.pub              # in git; public key
    <name>.age                 # in git; ciphertext
                               #   parallel to immutable/, NOT in dotfile-services
                               #   (else blue home would deploy it to ~/.config/secrets/)
  stow/secrets/.keys/age       # private key (NOT in git; stowed to ~/.keys/age)
~/.local/share/secrets-decrypted/<name>   # decrypted plaintext (NOT in git)
```

The helper `tools/secrets` has `encrypt / decrypt / edit / show / list / recipients`. Plaintext target is `~/.local/share/secrets-decrypted/`, **never** `~/.config/` (which the dotfile service would overwrite/deploy).

`.gitignore`: exclude `.keys/` wholesale, then un-ignore `!dotfiles/secrets/.keys/*.pub` so the public key ships. Verify with `git check-ignore -v <path>` both ways. Add the `age` package to the user-packages list (`gnu/packages/golang-crypto.scm`).

> This is one repo's convention. The general "encrypt secrets with `age`, keep the private key out of git, decrypt to a non-deployed path" approach applies anywhere; adapt the directory names to your own layout.

## Live ISO build (this repo's entry points)

The ISO is generated from `tools/build-image.scm` (or `scripts/build-image.scm`), building the OS described by a separate `live-installation-os` block. Run it via the task runner (no sudo, background-safe):

```bash
cd ~/Projects/Config/Guix-configs
blue build-iso            # default variant
blue build-iso xfce       # explicit variant
```

For raw debugging (the runner swallows the real backtrace):

```bash
guix time-machine --channels=source/channel.lock -- repl -- \
  tools/build-image.scm dist/<name>.x86_64-linux.iso \
  tmp/live-iso.scm --image-type=iso9660 2>&1 | tee /tmp/iso-build.log
```

The generic pitfalls for building a live ISO with `guix system image` live in `iso-build.md` (module attribution, kmscon, slim, `with-imported-modules`).

## Channels (this repo's set, as an example)

This repo pins guix + nonguix + rosenthal (and historically bluebox/jeans). Define them in `source/channel.scm`, generate `source/channel.lock` via `guix time-machine --channel ./channels.scm -- describe --format=channels > ./channels.lock`, and `(include "./channels.lock")` from the config. The generic "why lock channels" rationale is in `beginner-home.md` §10.5.
