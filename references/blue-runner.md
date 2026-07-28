# The `blue` Task Runner — a reusable Guix config-repo pattern

`blue` is the name of the **task runner** used by one popular Guix config repository (the `Guix-configs` family), but the _pattern_ it embodies is repository-agnostic. **Any** Guix configuration repo benefits from having a single entry point that wraps `guix` for safe, repeatable, reproducible workflows. Read this file to understand the convention; see `repo-guix-configs-example.md` for one concrete instance.

## What a `blue`-style runner does

A config repo that follows this pattern keeps system + home configuration as source files (often an Org-mode `config.org` tangled into Scheme, or plain `.scm` files), and provides a small CLI that wraps the underlying `guix` commands so you never invoke raw `guix system reconfigure` by hand. Typical responsibilities:

- **tangle / generate** — turn the source (Org Noweb blocks, or a generator) into a real `config.scm` / `home-config.scm` in a scratch dir.
- **lint / `check`** — fast syntactic validation (bracket balance, missing blocks) before any expensive build.
- **`home`** — `guix home reconfigure` on the generated home config (user only, no sudo).
- **`rebuild`** — `guix system reconfigure` + `guix home reconfigure` together (needs sudo).
- **`build-iso` / `image`** — `guix system image` to produce a Live/install ISO (builds only, does not mutate the running system).
- **`stow`** — reconcile dotfiles that deploy by symlink (see `dotfiles-general.md`).
- **`structor` / `gen-docs` / `upgrade`** — repo-maintenance helpers.

The key value: **one command, predictable behavior, and a safe default.** The runner encodes which operations are sudo-gated and which are not, so an automated agent (or a forgetful human) doesn't accidentally hang on a password prompt or mutate a live system.

## The two sudo boundaries (load-bearing rule)

This is the single most important invariant for any `blue`-style runner:

| Operation                 | Mutates live system? | Needs sudo? | Safe for an unattended agent?  |
| ------------------------- | -------------------- | ----------- | ------------------------------ |
| `check` / `lint`          | no                   | no          | ✅ yes                         |
| `home`                    | user env only        | no          | ✅ yes                         |
| `stow`                    | user dotfiles only   | no          | ✅ yes                         |
| `build-iso` / image       | no (build only)      | **no**      | ✅ yes (can run in background) |
| `rebuild` / `reconfigure` | **yes (system)**     | **yes**     | ❌ no — ask a human            |

> **Why `blue build-iso` / `guix system image` does NOT need sudo:** the `image` path only _builds_ an image artifact; it never reconfigures the running system. This has been verified in practice (twice, no sudo, build proceeded). Contrast with `blue rebuild` / `guix system reconfigure`, which _do_ write to the live system and therefore require root.

**Agent rule of thumb:** if the command could touch `/etc`, the bootloader, or a running system service, don't run it unattended — shell out to the human. `check`, `home`, `stow`, `build-iso` are the agent-safe set.

## Run it from the repo root

A `blue`-style runner discovers its configuration (e.g. `blueprint.scm`) from the **current working directory**. Running it from a subdirectory — especially a git submodule that has no runner config of its own — fails with a confusing `No command with this name` / `&external-error` that looks like the runner itself broke.

```bash
# ✅ always
cd /path/to/your-config-repo && blue home

# ❌ from a submodule / subdir cwd
cd /path/to/your-config-repo/dotfiles/mutable/emacs && blue home
#   → external-error, looks like blue itself broke
```

## `check` is a smoke test, not a validator

`blue check` (or whatever your runner's lint step is called) typically only balances brackets **per source block**. It will NOT catch:

- a locally misplaced paren whose _total_ still balances (a real `guix build` then fails with `invalid field specifier` / `wrong-type-arg`);
- wrong service field names (a field removed upstream);
- wrong module paths (`use-modules` pointing at the wrong module);
- list-of-services vs single-service mistakes in `append` chains.

For semantic verification, probe the record type directly with the locked channels:

```bash
guix time-machine --channels=source/channel.lock -- repl <<'EOF'
(use-modules (gnu services networking))
(format #t "~a~%"
  (module-variable (resolve-module '(gnu services networking))
                   'network-manager-configuration))
;; #<<record-type ...>>  → the field set is queryable
;; #<variable ... value: #f> → defined but uninitialized (rare)
;; unbound → the symbol really isn't there
EOF
```

## How to adopt this pattern in your own repo

You don't need `blue` specifically. The pattern is:

1. Keep your config as **source** (Org + Noweb, or plain Scheme) committed to git — never edit the deployed `/etc/config.scm` or `~/.config` files by hand. _Edit source → re-run the runner → verify._
2. Provide **one** command that generates + lints + applies. Name it whatever you like (`blue`, `make`, `./deploy`, `just`).
3. Encode the **sudo boundary** in the runner so it's impossible to accidentally reconfigure a live system from an unattended context.
4. Use **channel locking** (`channels.lock`) so every build is reproducible — see `beginner-home.md` §10.5.
5. For dotfiles, pick a deploy strategy (Guix Home `home-dotfiles-service-type` symlinks, or GNU Stow) and document the "edit source, don't edit the live symlink" rule — see `dotfiles-general.md`.

`blue` itself is implemented as a `blueprint.scm` defining subcommands; the concrete command list for the `Guix-configs` instance is in `repo-guix-configs-example.md`.
