## Quick Reference

### Example Files

| File                       | Purpose                                                       |
| -------------------------- | ------------------------------------------------------------- |
| `examples/channel.scm`     | Channel definitions with nonguix (+ optional desktop channel) |
| `examples/bare-bones.scm`  | Minimal headless/server config                                |
| `examples/desktop.scm`     | GNOME + Xfce with LUKS encryption                             |
| `examples/desktop-kde.scm` | KDE Plasma (common beginner choice)                           |
| `examples/home-config.scm` | Guix Home user configuration                                  |

### Essential Commands

```bash
# System management
guix system reconfigure /etc/config.scm
guix system build /etc/config.scm
guix system roll-back
guix system list-generations

# Package management
guix pull
guix package --install package
guix package --remove package
guix search package

# Home management
guix home reconfigure /path/to/home-config.scm
guix home roll-back

# Development environments
guix shell package1 package2
guix shell --manifest=manifest.scm
guix shell --container

# Maintenance
guix gc
guix gc --free-space=10GB

# A `blue`-style task runner (if your repo has one — see blue-runner.md)
blue help           # all subcommands
blue check          # fast bracket lint on tangled config
blue home           # rebuild user env (safe to run from repo root)
blue rebuild        # rebuild system + home (needs sudo — do NOT run unattended)
blue build-iso      # generate a Live ISO (no sudo, can run in background)
blue stow <pkg>     # reconcile dotfiles via GNU Stow
# If your repo names it differently (make / ./deploy / just), substitute accordingly.
```

### Key Documentation (load on demand)

- **Full Guix manual:** https://guix.gnu.org/manual/
- **Nonguix project:** https://gitlab.com/nonguix/nonguix
- **Nonguix substitutes:** https://substitutes.nonguix.org/
- **Cuirass Nonguix build status:** https://cuirass.nonguix.org/
- **`gnu/services` field reference:** https://guix.gnu.org/manual/en/html_node/Defining-Services.html
- **`home-environment` reference:** https://guix.gnu.org/manual/en/html_node/Home-Configuration.html
- **Channels & `guix time-machine`:** https://guix.gnu.org/manual/en/html_node/Channels.html and https://guix.gnu.org/manual/en/html_node/Invoking-guix.html

### Important Reminders

1. **For modern hardware, include a non-free channel (e.g. nonguix)** — without it WiFi, GPU, and CPU features may not work.
2. **Lock your channels** — use `guix time-machine` to create `channels.lock` for reproducibility.
3. **Test before applying** — use `guix system build` and `guix system vm` to test configs.
4. **Keep generations** — don't delete old generations until you're sure the new one works.
5. **Use substitutes** — configure a substitute server to avoid long compilations.
6. **Templates diverge from live configs** — read the live config's current comments before copying anything from `examples/`.

### On-Demand Diagnostic Commands

```bash
# Service status (system shepherd needs sudo; home-shepherd doesn't)
herd status
herd status service-name

# Verify a dotfile deployment picked up your edit
md5sum <source> ~/.config/<app>/<path>

# Network diagnostics
rfkill list
ip link
dmesg | grep -i firmware
lspci -k
iwlist scan
bluetoothctl

# Audio
wpctl status
pactl info
alsamixer

# Build trace (catches field-name and module-path errors)
guix build -c <channel.lock> /etc/config.scm

# Repl probe of a record type (against locked channels)
guix time-machine -C source/channel.lock -- repl <<'EOF'
(use-modules (gnu services networking))
(format #t "~a~%"
  (module-variable (resolve-module '(gnu services networking))
                   'network-manager-configuration))
EOF
```
