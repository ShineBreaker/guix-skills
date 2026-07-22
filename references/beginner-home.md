## Section 9: LUKS Disk Encryption

### Complete LUKS Setup

Reference `examples/desktop.scm` lines 36-54:

```scheme
(use-modules (gnu system uuid))

(operating-system
  ;; Define the encrypted device mapping
  (mapped-devices
   (list (mapped-device
           (source (uuid "12345678-1234-1234-1234-123456789abc"))
           (target "my-root")
           (type luks-device-mapping))))

  ;; File systems reference the mapped device
  (file-systems (append
                 (list (file-system
                         ;; Use the decrypted device label
                         (device (file-system-label "my-root"))
                         (mount-point "/")
                         (type "ext4")
                         ;; IMPORTANT: Declare dependency on mapped device
                         (dependencies mapped-devices))
                       (file-system
                         (device (uuid "1234-ABCD" 'fat))
                         (mount-point "/boot/efi")
                         (type "vfat")))
                 %base-file-systems))
  ;; ...
)
```

### Finding the LUKS UUID

```bash
# Get UUID of encrypted partition
cryptsetup luksUUID /dev/sda2
```

### Swap File with Encrypted Root

Reference `examples/desktop.scm` lines 58-59:

```scheme
(swap-devices (list (swap-space
                      (target "/swapfile"))))
```

The swap file resides on the encrypted root filesystem, so it's automatically encrypted.

### Important Notes

- `/boot/efi` must remain unencrypted (FAT32) for UEFI boot
- The initrd will prompt for the LUKS passphrase at boot
- Consider using a keyfile for automatic decryption (advanced)

> **Done when:** `mapped-devices` has a `luks-device-mapping`, the root `file-system` declares `(dependencies mapped-devices)`, and `/boot/efi` is unencrypted.

## Section 10: Guix Home — User-Level Configuration

### What is Guix Home?

Guix Home manages user-level configuration separately from the system. It handles:

- User packages
- Shell configuration (bash, zsh, fish)
- Dotfiles management
- User services

Reference `examples/home-config.scm` for a working example.

### Basic Home Configuration

```scheme
(use-modules (gnu home)
             (gnu packages)
             (gnu services)
             (guix gexp)
             (gnu home services shells))

(home-environment
  ;; User-level packages
  (packages (specifications->packages
             (list "git"
                   "emacs"
                   "vim"
                   "htop")))

  ;; User services
  (services
   (list
    ;; Bash configuration
    (service home-bash-service-type
             (home-bash-configuration
              (aliases '(("ll" . "ls -l")
                        ("la" . "ls -a")))
              (bashrc (list (plain-file "bashrc-extra"
                                       "export EDITOR=emacs\n"))))))))
```

### Guix Home Commands

```bash
# Apply home configuration
guix home reconfigure /path/to/home-config.scm

# Test in a container (safe)
guix home container /path/to/home-config.scm

# Roll back to previous generation
guix home roll-back

# List generations
guix home list-generations
```

### Relationship with System Config

- **System config** (`/etc/config.scm`): System-wide settings, services, kernel
- **Home config**: User-specific packages, shell settings, dotfiles

Both can install packages. Use system config for system-wide tools, home config for personal preferences.

> **Done when:** the `home-environment` has `packages` and `services`, and `guix home reconfigure` succeeds.

`reference:` https://guix.gnu.org/manual/en/html_node/Home-Configuration.html

## Section 10.5: Channel Configuration & `guix time-machine` (Reproducibility)

### Why Channel Locking Matters

Without channel locking, `guix pull` may update packages and break your configuration. Locking ensures reproducibility: your config will produce the same system every time.

### Define Your Channels

Reference `examples/channel.scm`:

```scheme
(use-modules (guix channels))

(define guix-channels
  (append (list (channel
                  (inherit (car %default-channels))
                  (branch "master"))

                (channel
                 (name 'nonguix)
                 (branch "master")
                 (url "https://gitlab.com/nonguix/nonguix")
                 (introduction
                  (make-channel-introduction
                   "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
                   (openpgp-fingerprint
                    "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
                (channel
                 (name 'rosenthal)
                 (url "https://codeberg.org/hako/rosenthal.git")
                 (branch "trunk")
                 (introduction
                  (make-channel-introduction
                   "7677db76330121a901604dfbad19077893865f35"
                   (openpgp-fingerprint
                    "13E7 6CD6 E649 C28C 3385  4DF5 5E5A A665 6149 17F7")))))

          %default-channels))

guix-channels
```

**Channel explanations:**

- **guix**: The default GNU Guix channel with free software.
- **nonguix**: Non-free software (kernel, firmware, NVIDIA drivers). **Almost always required on modern hardware.**
- _extra channels_ (e.g. a desktop/tooling channel): optional. The example above includes one such channel (`rosenthal`) as a placeholder — replace it with whatever extra channels your setup needs, or drop it. The only near-mandatory addition for typical laptops/desktops is **nonguix**.

### Generate the Lock File

Create a pinned channel lock file:

```bash
guix time-machine --channel ./channels.scm -- describe --format=channels > ./channels.lock
```

This creates `channels.lock` with exact commit hashes for all channels. Use a task runner like `blue` (see Tier 2) to automate this.

### Use Locked Channels in Your Config

All example configs use this pattern. Reference `examples/desktop.scm`:

```scheme
;; Load locked channels
(define guix-channels (include "./channels.lock"))

(operating-system
  ;; ... other config ...

  (services (append (list
    ;; Propagate channels to user-level guix
    (simple-service 'home-channels home-channels-service-type
                    guix-channels))
   (modify-services %desktop-services
     ;; Lock system-level guix to same channels
     (guix-service-type config =>
       (guix-configuration (inherit config)
         (channels guix-channels)
         (guix (guix-for-channels guix-channels))))))))
```

**This ensures both system and user guix use identical pinned channels.**

> **Done when:** `source/channel.lock` exists, the config `(include …)`s it, and both `guix-service-type` and `home-channels-service-type` reference the locked channels.

`reference:` https://guix.gnu.org/manual/en/html_node/Channels.html and https://guix.gnu.org/manual/en/html_node/Invoking-guix.html (search "time-machine").
