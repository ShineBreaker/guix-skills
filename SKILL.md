---
name: guix-skills
description: "Guix System + a config-repo task-runner (blue-style) configuration & troubleshooting assistant. Triggers: 'guix config', 'guix reconfigure failed', 'nvidia/amd/intel gpu guix', 'luks encryption guix', 'guix home', 'wifi/bluetooth/audio not working on guix', 'guix substitute/pull error', 'blue rebuild/home/build-iso' (or any config-repo task runner), 'channel.lock', 'dotfiles', 'guix system image' / ISO build, 'age-encrypted secrets', 'shepherd service'. Self-contained: nonguix beginner walkthrough (Tier 1), the reusable blue task-runner pattern + dotfiles dual-track (Tier 2), advanced ISO/FHS/age (Tier 3), and a hardened foot-guns library of verified gotchas. Generic across environments — adapts to any Guix config repo, not tied to one machine."
version: 3.1
license: MIT
metadata:
  hermes:
    tags: [guix, guix-system, nonguix, guix-home, blue, task-runner, iso-build, dotfiles, shepherd, channel-lock]
---

# Guix System Configuration & Troubleshooting

Self-contained assistant for (a) setting up Guix System on modern hardware via
a non-free channel, and (b) operating a **Guix configuration repository** that
follows the `blue`-style task-runner pattern (tangled source + a single CLI
that wraps `guix` for safe, repeatable, reproducible workflows). It is written
to be **generic across environments** — the examples use one real repo
(`Guix-configs`) as a concrete instance, but the patterns apply to any Guix
config repo. It does **not** delegate to any other skill.

The material is split into three tiers; the map below tells you which
`references/` file to load for each. **SKILL.md itself is only the map plus the
few rules you must never skip.** Templates, field tables, worked examples, and
error transcripts live under `references/` and `examples/`.

## When to load each reference

| Tier | Topic | Load | When |
|------|-------|------|------|
| 1 | Newcomer walkthrough: non-free channel, bootloader, filesystems, users, desktop env, GPU, networking, audio, printers, LUKS, Guix Home, channel lock, packages | `references/beginner-foundation.md` (§1–§8.6) · `references/beginner-home.md` (§9 LUKS + §10 Home + §10.5 channels) · `references/beginner-packages.md` (§11) | User is setting up Guix from scratch or asks a generic "how do I configure X in Guix" question |
| 2 | Config-repo patterns: the `blue` task-runner convention, tangle/lint discipline, dotfiles dual-track, `home-shepherd`/`system-shepherd` debugging, working from a repo | `references/blue-runner.md` (the runner pattern) · `references/dotfiles-general.md` (dual-track) · `references/repo-workflow.md` (generic repo habits) · `references/repo-guix-configs-example.md` (one concrete instance) | Editing anything under a config repo's `source/` / `dotfiles/`, or running its task runner |
| 3 | Advanced: Live/install ISO self-build, FHS container, age-encrypted secrets, repo layout | `references/iso-build.md` (§16) · `references/advanced.md` (§17–§19) | Building a Live ISO, emulating FHS for an Electron/AppImage binary, or handling secrets/dotfiles in a repo |
| — | Verified gotcha library (the foot-guns) + the Examples-directory map | `references/foot-guns.md` (§20 + §21) | **Scan at the start of any non-trivial task** |
| — | Cheat-sheets: command reminders, upstream-doc URLs, on-demand diagnostics | `references/quick-ref.md` | Need a command reminder or the right upstream manual page |

## Rules you must not skip (config repos + Guix)

These are the highest-leverage invariants. Read them before acting on a config
repo's source or running its runner.

1. **Never run a system reconfigure unattended.** `guix system reconfigure` /
   a runner's `rebuild` need sudo and will hang a non-interactive session on a
   password prompt. Agent-safe set: the runner's `check` / `lint`, `home`,
   `stow`/`dotfiles`, and `build-iso` / `guix system image` (the image path
   **does not** need sudo — it only builds, never mutates the live system).
   Ask a human to run the sudo-gated ones.
2. **Run the runner from the repo root.** A `blue`-style runner discovers its
   config from the cwd; running it from a subdir/submodule fails with a
   misleading "no such command".
3. **Edit source, then verify the deployment picked it up.** Live
   `~/.config/<app>/<file>` is a symlink to a store copy (immutable track) or to
   the repo source (mutable track) — never edit the live file. After the home
   step, `md5sum` the source vs `~/.config/…` (or `readlink`) to confirm the
   store hash moved. (See `references/dotfiles-general.md`.)
4. **The lint step is a paren smoke test, not a validator.** It misses locally
   misplaced parens, wrong field names, and wrong module paths. For semantics,
   probe the record type with `guix time-machine -C channel.lock -- repl`
   (see `references/blue-runner.md`).
5. **Lock your channels.** Build against `channel.lock` so every result is
   reproducible (see `references/beginner-home.md` §10.5).

## The `blue` task runner — a reusable pattern

`blue` names the runner used by one popular config-repo family, but the
*pattern* (one CLI wrapping `guix` for tangle/lint/home/image/stow, with a
built-in sudo boundary) is repository-agnostic. Read
`references/blue-runner.md` for the convention and "how to adopt it in your own
repo"; `references/repo-guix-configs-example.md` shows one concrete instance.

## On the example templates

`examples/*.scm` are **starter templates, not** a live config. A real repo's
`config.org` / `config.scm` has diverged from them. Don't copy example code
into a live config without reading its current comments first.

## Self-contained provenance

The foot-guns library (`references/foot-guns.md`) and `references/iso-build.md`
§16.4 fold in pitfalls that were **reproduced in real build/debug sessions**
(e.g. `make-installation-os` module location, kmscon no-op, `slim`
empty-password/sudo interaction, btrfs dedup EACCES, mirror-signature Gotcha
§20.9). They are distilled into this skill so no other skill or external note
is needed to act safely. Upstream manuals are referenced by URL only (see
`references/quick-ref.md`) and should be `web_extract`-ed on demand.
