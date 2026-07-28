## Section 16: Building a Live / install ISO

A self-authored Live ISO is built with `guix system image` (the `image` type, e.g. `iso9660`). Many config repos wrap this behind a task-runner subcommand such as `blue build-iso`. **The `image` path only builds — it never mutates the running system — so it does NOT need sudo** (verified in practice: built twice with no sudo). This is in contrast to `guix system reconfigure`, which does require root.

```bash
# Via a task runner (background-safe, 30+ min; no sudo)
cd /path/to/your-config-repo
blue build-iso            # default variant
blue build-iso xfce       # explicit variant

# Raw, for debugging (the runner may swallow the real backtrace)
guix time-machine --channels=source/channel.lock -- repl -- \
  path/to/build-image.scm dist/<name>.x86_64-linux.iso \
  tmp/live-iso.scm --image-type=iso9660 2>&1 | tee /tmp/iso-build.log
```

> The repo-specific command list and `live-installation-os` entry points for one concrete repo are in `repo-guix-configs-example.md`.

### 16.1 Module-attribution trap

`make-installation-os` lives in guix core's `(gnu system install)`, **not** in a third-party channel's file-systems module. The ISO's live-modules block must `(use-modules (gnu system install) …)`:

```scheme
;; CORRECT
(use-modules (gnu system install) (guix gexp) (guix modules) …)

;; WRONG — leads to `unbound variable: make-installation-os`
(use-modules (some-channel services file-systems) …)
```

`%installation-services` already enables `kmscon` on tty1 (with `login-program installer`). Don't add `(service kmscon-service-type …)` redundantly; don't write `(delete kmscon-service-type)` and think it's "disabling" it — both are no-ops for already-default-true (or absent) entries.

To confirm the symbol's home in your locked guix commit: `grep -n 'make-installation-os' $(guix describe --format=channels | grep -A1 guix | …)`.

### 16.2 ISO autologin (lightdm/xfce example)

For an ISO that boots into a desktop, `lightdm-configuration` needs the seat set consistently:

```scheme
(seat-configuration
  (autologin-user "live")
  (user-session "xfce"))          ; bare name, no .desktop suffix
```

…and a top-level `(allow-empty-passwords? #t)` on `lightdm-configuration` itself when the auto-login user has `(password "")`.

### 16.3 The `with-imported-modules` rule

If you write an ISO-time package with `trivial-build-system` whose gexp-builder uses `(guix build utils)` (for `mkdir-p`, `call-with-output-file`, etc.), wrap the gexp in `with-imported-modules`:

```scheme
(arguments
 (list #:builder
   (with-imported-modules '((guix build utils))
     #~(begin
         (use-modules (guix build utils))
         …))))
```

Without it, `trivial-build-system` does not import `(guix build utils)` into the build sandbox, and the drv fails with `no code for module (guix build utils)`. Note `with-imported-modules` adds a layer — balance the extra closing paren or the bracket check will report one too many open parens.

### 16.4 Verified ISO pitfalls (real build debugging)

These traps actually broke real builds, not theory:

- **`make-installation-os` lives in `(gnu system install)` — NOT a third-party channel's file-systems module.** In `guix repl` this module is _not_ auto-imported; `use-modules` it explicitly or you'll wrongly see `unbound variable: make-installation-os`. The `guix system image` path (via time-machine) auto-enables channel modules, so the build itself is unaffected.
- **kmscon is DEFAULT-ENABLED on tty1** inside `%installation-services` (login-program `installer`). So `(service kmscon-service-type …)` is redundant-but-harmless, while `(delete kmscon-service-type)` is a **no-op** (deleting a service not in _your_ base set). Don't read `(delete kmscon …)` as "kmscon was disabled" — it wasn't.
- **`live-modules` use-modules ordering matters:** if you pull in both a desktop-services module and a third-party channel module, put the channel module _after_ the guix desktop module — the channel's own use-modules chain may depend on the latter.
- **`#:efi-only?` is a keyword arg of `make-installation-os`, not a field.** Drop the `:` and the error points at `(gnu system install)`, misleading you.
- **The OS value must be a bare trailing value.** After `(define %live-installation-os …)`, the file must end with `%live-installation-os` on its own line — `guix system image` expects an operating-system value, not a definition.
- **`(cons* …)` vs `(append …)` mismatch** — if a `<<noweb>>` block expands to `(list …)` of services and you wrap it in `cons*`, you get _"services field must contain a list of services"_. Flatten with `append`.
- **Tangle target must NOT reuse the host config's output.** A live-ISO `(define %live-installation-os …)` tangled into the same file as the host `operating-system` pollutes the host config and the system reconfigure then errors with `multiple definition` / `unbound variable: %system`. Use a **separate** output file for the ISO.
- **The lint step does not catch cross-tangle pollution** (a `:tangle` block referenced by another Noweb block). After tangle, diff the output and confirm the ISO file's tail is the ISO OS value, not the host's.
- **`slim` auto-login path:** a live user with `(password #f)` still logs into the slim desktop (slim skips pam), but `sudo` rejects it (pam_unix requires re-auth). To get a usable `sudo` from the live desktop, set a real password `(password (crypt "live" "$6$abc"))`. Empty-password sudo only works if `base-pam-services #:allow-empty-passwords? #t` is in effect (the `make-installation-os` default).
- **Upstream #7373 blocks only the installer's finish step, not ISO building.** The installer deadlocks when it spawns `guix system init` (a Guile `safe-clone`/`primitive-fork` interaction). This affects the _install-to-disk_ tail of a live session, not the ISO build itself — building an ISO proceeds fine. If you must build an older guix to work around it, roll back to a commit _before_ the regression, not just to an older Guile.
