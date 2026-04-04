---
name: guix
description: Guix System configuration assistant — helps beginners create working configs and troubleshoot issues, with nonguix for modern hardware support
when_to_use: |
  Use when the user needs help with GNU Guix configuration or troubleshooting.
  Examples: "guix config", "guix reconfigure failed", "my wifi doesn't work on guix",
  "nvidia driver guix", "amd gpu guix", "guix home config", "luks encryption guix",
  "guix system configuration", "how to set up guix", "guix boot error",
  "guix substitute error", "guix pull failed", "help with my config.scm",
  "guix bluetooth", "guix printer", "guix python", "guix development environment",
  "guix install software", "guix services", "guix audio not working",
  "how to set up programming environment in guix", "guix docker",
  "guix shell", "guix manifest"
allowed-tools:
  - Read
  - Edit
  - Bash(guix:*)
  - Bash(grep:*)
  - Bash(test:*)
  - Bash(cat:*)
  - Bash(ls:*)
paths:
  - "**/*.scm"
effort: high
---

# Guix System Configuration and Troubleshooting

This skill helps you configure GNU Guix System for modern hardware and troubleshoot common issues. It covers everything from basic setup to advanced configurations like NVIDIA drivers, LUKS encryption, and reproducible builds with channel locking.

## Section 1: Overview & Quick Start

### What This Skill Covers

This skill provides comprehensive guidance for:

- Setting up Guix System with modern hardware support (nonguix)
- Configuring desktop environments (KDE Plasma recommended for beginners)
- Setting up GPU drivers (NVIDIA, AMD, Intel)
- Configuring networking (WiFi, Ethernet, Bluetooth)
- Setting up LUKS disk encryption
- Managing user environments with Guix Home
- Troubleshooting boot, hardware, configuration, and package issues

### CRITICAL FIRST STEP: Set Up Nonguix Channel

**Without nonguix, most modern hardware WILL NOT WORK.** This includes WiFi cards, GPUs, and CPUs that need proprietary firmware.

Create `~/.config/guix/channels.scm` with this content (from `docs/nonguix.org` lines 49-59):

```scheme
(cons* (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        ;; Enable signature verification:
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
       %default-channels)
```

Then run:

```bash
guix pull
```

This downloads the nonguix channel which provides:
- Non-free Linux kernel (`linux` package)
- Proprietary firmware (`linux-firmware`)
- CPU microcode updates (`microcode-initrd`)
- NVIDIA proprietary drivers

## Section 2: Essential System Configuration (Nonguix Foundation)

Every Guix System configuration for modern hardware MUST include these nonguix components. Reference `examples/bare-bones.scm` for a minimal working example.

### Required Imports

```scheme
(use-modules (gnu)
             (guix utils)
             (nonguix)                          ; For nonguix-transformation-guix
             (nongnu packages linux)            ; For linux kernel
             (nongnu system linux-initrd))      ; For microcode-initrd
```

### Core Operating-System Fields

```scheme
(operating-system
  ;; Use non-free Linux kernel from nonguix
  (kernel linux)

  ;; Enable CPU microcode updates (security critical)
  (initrd microcode-initrd)

  ;; Include all non-free firmware
  (firmware (cons* linux-firmware %base-firmware))

  ;; ... rest of configuration
)
```

**Why each field matters:**

- `(kernel linux)`: Uses the standard Linux kernel with proprietary drivers instead of Linux-libre (which lacks proprietary firmware)
- `(initrd microcode-initrd)`: Loads CPU microcode updates early in boot to fix security vulnerabilities and CPU bugs
- `(firmware (cons* linux-firmware %base-firmware))`: Includes firmware blobs for WiFi, GPU, Bluetooth, and other hardware

### The Nonguix Transformation Wrapper

Wrap your operating-system definition with the nonguix transformation:

```scheme
(define %my-os
  (operating-system
    ;; ... your configuration
))

((compose (nonguix-transformation-guix))
 %my-os)
```

This applies necessary transformations to packages for compatibility with non-free components.

## Section 2.5: Channel Configuration & guix time-machine (Reproducibility)

### Why Channel Locking Matters

Without channel locking, `guix pull` may update packages and break your configuration. Locking ensures reproducibility: your config will produce the same system every time.

### Define Your Channels

Reference `examples/channel.scm` for the channel definitions:

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
- **guix**: The default GNU Guix channel with free software
- **nonguix**: Non-free software (kernel, firmware, NVIDIA drivers)
- **rosenthal**: Additional packages not in official channels

### Generate the Lock File

Create a pinned channel lock file:

```bash
guix time-machine --channel ./channels.scm -- describe --format=channels > ./channels.lock
```

This creates `channels.lock` with exact commit hashes for all channels. Use a task runner like `just` to automate this.

### Use Locked Channels in Your Config

All example configs use this pattern. Reference `examples/desktop-kde.scm` lines 91-100:

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
         (guix (guix-for-channels guix-channels)))))))
```

**This ensures both system and user guix use identical pinned channels.**

### Channel Locking Workflow

1. Edit `channels.scm` to define your channels
2. Run the lock command to generate `channels.lock`
3. All `.scm` configs include `channels.lock`
4. System uses pinned channels automatically

## Section 3: Bootloader Configuration

### UEFI Setup (Modern Systems)

Most modern systems use UEFI. Reference `examples/desktop.scm` lines 29-34:

```scheme
(use-modules (gnu packages bootloaders))

(bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (targets '("/boot/efi"))
              (keyboard-layout keyboard-layout)))
```

**Requirements:**
- EFI System Partition (ESP) mounted at `/boot/efi`
- Partition type: FAT32 (vfat)
- Typically 512MB size

### Legacy BIOS Setup

For older systems without UEFI. Reference `examples/bare-bones.scm` lines 26-28:

```scheme
(bootloader (bootloader-configuration
              (bootloader grub-bootloader)
              (targets '("/dev/sdX"))))
```

**Identify the correct device:**
- Run `lsblk` to list block devices
- Use the whole disk (e.g., `/dev/sda`), not a partition
- Be careful: wrong target can overwrite other OS bootloaders

### Finding Your Boot Mode

```bash
# Check if running in UEFI mode
ls /sys/firmware/efi
# If directory exists, you're in UEFI mode
```

## Section 4: File Systems Configuration

### Basic ext4 Root Partition

Reference `examples/bare-bones.scm` lines 32-36:

```scheme
(file-systems (cons (file-system
                      (device (file-system-label "my-root"))
                      (mount-point "/")
                      (type "ext4"))
                    %base-file-systems))
```

### Complete Setup with EFI Partition

Reference `examples/desktop.scm` lines 44-54:

```scheme
(file-systems (append
               (list (file-system
                       (device (file-system-label "my-root"))
                       (mount-point "/")
                       (type "ext4")
                       (dependencies mapped-devices))  ; For LUKS
                     (file-system
                       (device (uuid "1234-ABCD" 'fat))
                       (mount-point "/boot/efi")
                       (type "vfat")))
               %base-file-systems))
```

### Finding UUIDs

```bash
# List all partitions with UUIDs
blkid

# Get UUID for a specific partition
blkid -s UUID -o value /dev/sda1
```

### Labels vs UUIDs

- **Labels** (`file-system-label`): Human-readable, easier to manage
- **UUIDs** (`uuid`): Unique, won't change if disk is reordered

Create labels with: `mkfs.ext4 -L my-root /dev/sda1`

## Section 5: User Accounts & Groups

### Creating User Accounts

Reference `examples/desktop.scm` lines 62-68:

```scheme
(users (cons (user-account
               (name "bob")
               (comment "Alice's brother")
               ;; WARNING: Plain text passwords are insecure for public repos
               ;; Generate hash with: echo "password" | guix shell openssl -- openssl passwd -6 -stdin
               (password (crypt "alice" "$6$abc"))
               (group "students")
               (supplementary-groups '("wheel" "netdev" "audio" "video")))
             %base-user-accounts))
```

### Essential Supplementary Groups

| Group | Purpose |
|-------|---------|
| `wheel` | sudo access |
| `netdev` | Network management (NetworkManager) |
| `audio` | Audio device access |
| `video` | Video/GPU access |

### Custom Groups

Reference `examples/desktop.scm` lines 71-73:

```scheme
(groups (cons* (user-group
                 (name "students"))
               %base-groups))
```

### Setting Passwords Securely

**Option 1: Hashed password (recommended)**

```bash
# Generate password hash
echo "your-password" | guix shell openssl -- openssl passwd -6 -stdin

# Use output in config:
(password "<generated-hash>")
```

**Option 2: Initial password (change on first login)**

```scheme
(password (crypt "temporary" "$6$abc"))
```

Then run `passwd` after first login.

## Section 6: Desktop Environment & Services

### Option A: KDE Plasma (RECOMMENDED for Beginners)

**Why KDE is recommended:**
- Most familiar for users coming from Windows
- Good hardware compatibility
- SDDM display manager works well with NVIDIA
- Comprehensive settings GUI

Reference `examples/desktop-kde.scm`:

```scheme
(use-modules (gnu services desktop)
             (gnu services sddm))

(operating-system
  ;; ... other config ...

  (services (append (list
    (simple-service 'home-channels home-channels-service-type
                    guix-channels)
    ;; KDE Plasma desktop
    (service plasma-desktop-service-type))
   (modify-services %desktop-services
     (guix-service-type config =>
       (guix-configuration (inherit config)
         (channels guix-channels)
         (guix (guix-for-channels guix-channels)))))))
```

SDDM is the default display manager for KDE and works reliably.

### Option B: GNOME + Xfce

Reference `examples/desktop.scm`:

```scheme
(use-modules (gnu services desktop)
             (gnu services xorg)
             (gnu packages gnome))

(services (append (list
  (simple-service 'home-channels home-channels-service-type
                  guix-channels)
  (service gnome-desktop-service-type)
  (service xfce-desktop-service-type)
  (set-xorg-configuration
    (xorg-configuration
      (keyboard-layout keyboard-layout))))
 (modify-services %desktop-services
   (guix-service-type config =>
     (guix-configuration (inherit config)
       (channels guix-channels)
       (guix (guix-for-channels guix-channels)))))))
```

**Note:** GDM (GNOME Display Manager) has known issues with NVIDIA. Consider replacing with SDDM if using NVIDIA.

### Option C: Lightweight Desktop (Window Managers)

Reference `examples/lightweight-desktop.scm`:

```scheme
(use-modules (gnu packages ratpoison)
             (gnu packages suckless)
             (gnu packages wm))

;; Add window manager packages
(packages (append (list
                   ratpoison i3-wm i3status dmenu
                   xterm)
                  %base-packages))

;; Uses %desktop-services for networking, etc.
(services (modify-services %desktop-services ...))
```

Available window managers: i3, ratpoison, EXWM (Emacs), dwm, and more.

### Option D: Headless/Server

Reference `examples/bare-bones.scm`:

```scheme
(use-modules (gnu services networking)
             (gnu services ssh))

(services (append (list
  (simple-service 'home-channels home-channels-service-type
                  guix-channels)
  (service dhcpcd-service-type)
  (service openssh-service-type
    (openssh-configuration
      (openssh openssh-sans-x)
      (port-number 2222))))
 (modify-services %base-services
   (guix-service-type config =>
     (guix-configuration (inherit config)
       (channels guix-channels)
       (guix (guix-for-channels guix-channels)))))))
```

### Service Sets Explained

- `%base-services`: Minimal services ( Shepherd, syslog, etc.)
- `%desktop-services`: Full desktop (X11/Wayland, NetworkManager, Bluetooth, etc.)

## Section 7: GPU Configuration (NVIDIA + AMD + Intel)

### GPU Detection

First, identify your GPU:

```bash
lspci | grep -i vga
lspci | grep -i nvidia
lspci | grep -i amd
```

### AMD GPU (Easiest Path)

AMD GPUs work out-of-the-box with free Mesa drivers. Just ensure firmware is included:

```scheme
(use-modules (nongnu packages linux))

(operating-system
  (kernel linux)
  (firmware (cons* linux-firmware %base-firmware))  ; Includes AMD firmware
  ;; ... rest of config
)
```

No special nonguix configuration needed. Mesa drivers provide 3D acceleration.

### Intel Integrated GPU

Intel graphics also work out-of-the-box with Mesa:

```scheme
(firmware (cons* linux-firmware %base-firmware))
```

Intel GPUs use the `i915` kernel driver included in the standard Linux kernel.

### NVIDIA Proprietary Driver (Complex)

NVIDIA requires special configuration. Reference `docs/nonguix.org` lines 359-375.

**Step 1: Import required modules**

```scheme
(use-modules (nonguix transformations)
             (nongnu packages linux)
             (nongnu packages nvidia))
```

**Step 2: Define your OS with appropriate kernel**

```scheme
(define %my-os
  (operating-system
    (kernel linux-6.12)  ; Check nonguix docs for compatible versions
    (firmware (cons* linux-firmware %base-firmware))
    ;; ... rest of config
))
```

**Step 3: Apply NVIDIA transformation**

```scheme
((nonguix-transformation-nvidia
  #:driver nvda-580           ; Choose appropriate driver version
  #:configure-xorg? #t)       ; For Xorg display managers
 %my-os)
```

**NVIDIA transformation parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `#:driver` | `nvda-580` | Driver version (nvda-580, nvda-590, nvda-470, etc.) |
| `#:open-source-kernel-module?` | `#f` | Use open source kernel modules (Turing+ GPUs) |
| `#:kernel-mode-setting?` | `#t` | Required for Wayland and rootless Xorg |
| `#:configure-xorg?` | `#f` | Configure Xorg for display managers |
| `#:remove-nvenc-restriction?` | `#f` | Remove NVENC encoding restrictions |

**Driver compatibility** (from `docs/nonguix.org` lines 244-254):

| GPU Generation | Driver Package |
|----------------|----------------|
| GeForce 50 series (Blackwell) | nvda-580, nvda-590, nvda-595 |
| GeForce 40 series (Ada) | nvda-580, nvda-590, nvda-595 |
| GeForce 30 series (Ampere) | nvda-580, nvda-590, nvda-470 |
| GeForce 16/20 series (Turing) | nvda-580, nvda-590, nvda-470 |
| GeForce 10 series (Pascal) | nvda-580, nvda-470, nvda-390 |

**Three NVIDIA scenarios:**

1. **Headless server:**
   ```scheme
   ((nonguix-transformation-nvidia
     #:driver nvda-580
     #:kernel-mode-setting? #f)
    %my-os)
   ```

2. **Xorg with display manager:**
   ```scheme
   ((nonguix-transformation-nvidia
     #:driver nvda-580
     #:configure-xorg? #t)  ; or sddm-service-type for specific DM
    %my-os)
   ```

3. **Pure Wayland:**
   ```scheme
   ((nonguix-transformation-nvidia #:driver nvda-580)
    %my-os)
   ```

**GDM replacement for NVIDIA:**

GDM has known issues with NVIDIA. Replace with SDDM (from `docs/nonguix.org` lines 388-411):

```scheme
(use-modules (gnu services sddm)
             (gnu services xorg))

(define %my-os
  (operating-system
    ;; ... other config ...
    (services
     (cons* (service sddm-service-type)  ; Add SDDM
            (modify-services %desktop-services
              (delete gdm-service-type))))  ; Remove GDM
    ;; ...
))

((nonguix-transformation-nvidia
  #:driver nvda-580
  #:configure-xorg? sddm-service-type)
 %my-os)
```

**Application-level NVIDIA setup:**

For `guix shell` with NVIDIA:

```bash
guix shell mesa-utils nvda@580 --with-graft=mesa=nvda@580 -- glxinfo
```

**Switchable graphics (NVIDIA + Intel/AMD):**

Use `prime-run` for PRIME render offload:

```bash
prime-run steam
prime-run firefox
```

## Section 8: Networking Hardware (WiFi + Ethernet + Bluetooth)

### Intel WiFi (Most Common)

Intel WiFi cards need `iwlwifi-firmware`. Add to your firmware list (from `docs/nonguix.org` lines 87-89):

```scheme
(use-modules (nongnu packages linux))

(firmware (cons* iwlwifi-firmware
                 linux-firmware
                 %base-firmware))
```

Common Intel WiFi cards: AX200, AX210, 9560, 8265, etc.

### Broadcom Wireless

Broadcom requires proprietary kernel module and blacklisting (from `docs/nonguix.org` lines 188-199):

```scheme
(use-modules (nongnu packages linux))

(operating-system
  (kernel linux)
  ;; Blacklist conflicting modules
  (kernel-arguments '("modprobe.blacklist=b43,b43legacy,ssb,bcm43xx,brcm80211,brcmfmac,brcmsmac,bcma"))
  ;; Load proprietary Broadcom driver
  (kernel-loadable-modules (list broadcom-sta))
  (firmware (cons* broadcom-bt-firmware
                   %base-firmware))
  ;; ...
)
```

### Realtek WiFi

Most Realtek chips work with `linux-firmware`. Newer chips may need `rtw89-firmware`:

```scheme
(firmware (cons* rtw89-firmware
                 linux-firmware
                 %base-firmware))
```

### Ethernet

Ethernet typically works out-of-the-box with `linux-firmware`. Most common chipsets (Intel, Realtek) are supported.

### Bluetooth

Enable Bluetooth service for desktop (from `docs/nonguix.org`):

```scheme
(use-modules (gnu services desktop))

(services (cons* (service bluetooth-service-type)
                 %desktop-services))
```

Ensure firmware includes BT blobs:

```scheme
(firmware (cons* linux-firmware %base-firmware))
```

### Network Diagnostic Commands

```bash
# Check if WiFi is blocked
rfkill list

# Check network interface status
ip link

# Check firmware loading messages
dmesg | grep -i firmware

# Check WiFi driver
lspci -k | grep -A3 Network

# Scan WiFi networks
iwlist scan

# Check Bluetooth status
bluetoothctl
```

## Section 8.5: Audio Configuration

### PipeWire (Recommended)

PipeWire is included in `%desktop-services` on recent Guix. It provides:
- Modern audio server (replaces PulseAudio and JACK)
- Better Bluetooth audio support
- Lower latency

### PulseAudio (Legacy)

Still available if needed:

```scheme
(use-modules (gnu services sound))

(services (cons* (service pulseaudio-service-type)
                 %desktop-services))
```

### ALSA (Base Layer)

ALSA is always available as the base audio layer.

### Audio Troubleshooting

**User must be in `audio` group:**

```scheme
(supplementary-groups '("wheel" "netdev" "audio" "video"))
```

**Check audio status:**

```bash
# PipeWire status
wpctl status

# PulseAudio status
pactl info

# Check for muted channels
alsamixer

# List audio devices
aplay -l
```

## Section 8.6: Printer & Scanner Setup

### CUPS Printing Service

Enable CUPS for printing:

```scheme
(use-modules (gnu services cups))

(services (cons* (service cups-service-type
                          (cups-configuration
                            (web-interface? #t)))
                 %desktop-services))
```

Access CUPS web interface at: `http://localhost:631`

### SANE for Scanners

Install `sane-backends` package for scanner support:

```scheme
(packages (cons* sane-backends
                 %base-packages))
```

### Proprietary Printer Drivers

Some printers require proprietary drivers. Check the nonguix channel for additional printer support.

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

## Section 11: Common Software & Services Configuration

### Finding and Installing Packages

```bash
# Search for packages
guix search package-name
guix search "description text"

# Install to user profile
guix package --install package-name
guix package -i package-name

# Install to specific profile
guix package --install package-name --profile=/path/to/profile
```

### System-Level vs User-Level Packages

**System-level** (in `/etc/config.scm`):
- Essential system tools
- Services that need system-wide availability
- Packages for all users

**User-level** (in Guix Home or `guix package`):
- Personal applications
- Development tools
- User preferences

### Essential System Services

Reference `docs/GNU Guix Reference Manual.md` for complete service documentation.

**SSH Server:**

```scheme
(use-modules (gnu services ssh))

(services (cons* (service openssh-service-type
                          (openssh-configuration
                            (port-number 2222)
                            (permit-root-login #f)))
                 %base-services))
```

**NTP Time Sync:**

```scheme
(use-modules (gnu services networking))

(services (cons* (service ntp-service-type)
                 %base-services))
```

**Power Management (Laptops):**

```scheme
(use-modules (gnu services pm))

(services (cons* (service tlp-service-type)
                 (service upower-service-type)
                 %desktop-services))
```

**Docker:**

```scheme
(use-modules (gnu services docker))

(services (cons* (service docker-service-type)
                 %desktop-services))
```

**Virtualization:**

```scheme
(use-modules (gnu services virtualization))

(services (cons* (service libvirt-service-type)
                 %desktop-services))
```

### Desktop Applications

Common packages available in Guix:

```scheme
(packages (append (list
                   ;; Browsers
                   icecat chromium
                   ;; Office
                   libreoffice
                   ;; Media
                   mpv vlc ffmpeg
                   ;; Graphics
                   gimp inkscape
                   ;; File management
                   gvfs)
                  %base-packages))
```

**Note:** Many Electron apps may not be in Guix proper. Check nonguix channel.

### Font Configuration

```scheme
(use-modules (gnu packages fonts))

(packages (append (list
                   font-dejavu
                   font-gnu-freefont
                   font-liberation)
                  %base-packages))
```

### Locale and Internationalization

```scheme
(operating-system
  ;; System locale
  (locale "en_US.utf8")

  ;; Additional locales
  (locale-definitions
   (list (locale-definition
          (source "en_US")
          (charset "UTF-8"))
         (locale-definition
          (source "zh_CN")
          (charset "UTF-8"))))

  ;; Input methods
  (services (cons* (service fcitx-service-type)
                   %desktop-services))
)
```

Reference `docs/GNU Guix Reference Manual.md` for complete locale configuration.

## Section 12: Programming Language Environments

### General Principle: Use `guix shell`

For development environments, use `guix shell` instead of installing globally. This provides:
- Reproducible environments
- Isolation from system packages
- Easy project-specific dependencies

### Python

```bash
# Basic Python environment
guix shell python python-pip

# With development tools
guix shell python python-pip --development

# Create a manifest for your project
```

**Example manifest.scm for Python:**

```scheme
(specifications->manifest
  (list "python"
        "python-pip"
        "python-numpy"
        "python-requests"))
```

Use with: `guix shell --manifest=manifest.scm`

### Node.js

```bash
# Basic Node.js
guix shell node

# For npm compatibility issues, use FHS emulation
guix shell --emulate-fhs node npm
```

**Note:** The npm ecosystem may have limited packages in Guix. Consider using `guix shell --emulate-fhs` for better compatibility.

### Rust

```bash
guix shell rust cargo
```

### Go

```bash
guix shell go
```

### C/C++

```bash
# Full toolchain
guix shell gcc-toolchain make cmake pkg-config

# With common libraries
guix shell gcc-toolchain make cmake pkg-config gtk+ libxml2
```

### Java/JVM

```bash
# OpenJDK
guix shell openjdk@17

# Clojure
guix shell clojure

# Scala
guix shell scala
```

### Guile Scheme

Guile is Guix's native language:

```bash
guix shell guile
```

Useful for customizing Guix configurations beyond templates.

### Reproducible Development Environments

**Create a manifest.scm:**

```scheme
(specifications->manifest
  (list "python"
        "python-flask"
        "python-sqlalchemy"
        "git"))
```

**Create a channels.scm for pinning:**

```scheme
(list (channel
       (name 'guix)
       (url "https://git.savannah.gnu.org/git/guix.git")
       (commit "abc123...")))
```

**Use together:**

```bash
guix shell --channels=channels.scm --manifest=manifest.scm
```

### Container Environments

Fully isolated development environment:

```bash
# Create isolated container
guix shell --container --network python python-pip

# With preserved home directory
guix shell --container --network --preserve=HOME python
```

### FHS Emulation

For tools expecting Filesystem Hierarchy Standard layout:

```bash
guix shell --emulate-fhs node npm
```

This creates a `/usr/bin`, `/lib`, etc. structure that some tools expect.

## Section 13: Nonguix Substitute Server

### Why Use Substitutes?

Pre-built binaries save significant compilation time. The nonguix substitute server provides pre-built packages for nonguix channel software.

### Configure Substitute Server

Reference `docs/nonguix.org` lines 510-545:

```scheme
(operating-system
  (services (modify-services %desktop-services
              (guix-service-type config => (guix-configuration
                (inherit config)
                (substitute-urls
                 (append (list "https://substitutes.nonguix.org")
                   %default-substitute-urls))
                (authorized-keys
                 (append (list (local-file "./signing-key.pub"))
                   %default-authorized-guix-keys))))))
```

Download the signing key:

```bash
curl -O https://substitutes.nonguix.org/signing-key.pub
```

Or embed directly:

```scheme
(authorized-keys
 (append (list (plain-file "non-guix.pub"
                           "...key contents..."))
   %default-authorized-guix-keys))
```

### First-Time Reconfigure

The substitute server is only used after reconfiguration. For the first run, explicitly specify:

```bash
sudo guix archive --authorize < signing-key.pub
sudo guix system reconfigure /etc/config.scm \
  --substitute-urls='https://ci.guix.gnu.org https://bordeaux.guix.gnu.org https://substitutes.nonguix.org'
```

### Check Build Status

Visit https://cuirass.nonguix.org/ to check nonguix build status.

## Section 14: Troubleshooting — Boot & Installation Issues

### Symptom: System Doesn't Boot After Reconfigure

**Fix 1: Boot Previous Generation**
- At GRUB menu, select "Advanced options"
- Choose a previous generation
- Once booted, investigate the issue

**Fix 2: Roll Back from Live USB**
```bash
# Boot from Guix installation USB
# Mount your root partition
sudo mount /dev/sda2 /mnt
# Roll back
guix system roll-back --root=/mnt
```

### Symptom: Black Screen / No Display After Boot

**Fix: Add nomodeset kernel argument**

```scheme
(kernel-arguments (cons* "nomodeset" %default-kernel-arguments))
```

This disables kernel mode setting, allowing basic VGA fallback.

**Fix: Check firmware loading**
- Ensure `(kernel linux)` and `(firmware (cons* linux-firmware %base-firmware))` are set
- Check `dmesg | grep -i firmware` for loading errors

### Symptom: GRUB Not Found / UEFI Boot Entry Missing

**Fix 1: Verify bootloader target**
```scheme
(bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (targets '("/boot/efi"))))  ; Must be mounted
```

**Fix 2: Check UEFI entries**
```bash
# List UEFI boot entries
efibootmgr

# Reinstall GRUB
sudo guix system reconfigure /etc/config.scm
```

### Symptom: Kernel Panic

**Fix 1: Check file-system UUIDs**
```bash
# Verify UUIDs match your actual partitions
blkid
```

**Fix 2: Verify LUKS mapped-devices**
- Ensure `cryptsetup luksUUID` matches your config
- Check `(dependencies mapped-devices)` is set in file-system

### Symptom: Nonguix Installation Image Won't Boot

**Fix: Generate custom image**

Reference `docs/nonguix.org` lines 104-105:

```bash
guix system image --image-type=iso9660 /path/to/nonguix/nongnu/system/install.scm
```

### General Rollback Workflow

```bash
# List all system generations
guix system list-generations

# Roll back to previous generation
guix system roll-back

# Delete old generations
guix system delete-generations 1 2 3
```

## Section 15: Troubleshooting — Hardware Driver Issues

### Symptom: WiFi Not Working

**Step 1: Check firmware**
```scheme
(firmware (cons* linux-firmware %base-firmware))
```

**Step 2: Intel WiFi specific**
```scheme
(use-modules (nongnu packages linux))
(firmware (cons* iwlwifi-firmware linux-firmware %base-firmware))
```

**Step 3: Broadcom specific**
```scheme
(kernel-arguments '("modprobe.blacklist=b43,b43legacy,ssb,bcm43xx"))
(kernel-loadable-modules (list broadcom-sta))
(firmware (cons* broadcom-bt-firmware %base-firmware))
```

**Step 4: Check hardware block**
```bash
rfkill list
rfkill unblock wifi
```

### Symptom: NVIDIA GPU Not Working / No Acceleration

**Fix 1: Verify transformation applied**
```scheme
((nonguix-transformation-nvidia
  #:driver nvda-580
  #:configure-xorg? #t)
 %my-os)
```

**Fix 2: Check driver version matches GPU**
- Reference the compatibility table in `docs/nonguix.org` lines 244-254
- Older GPUs need nvda-470 or nvda-390

**Fix 3: Wayland issues**
- Try Xorg with `#:configure-xorg? #t`
- Or disable kernel mode setting: `#:kernel-mode-setting? #f`

**Fix 4: Switchable graphics**
```bash
prime-run application-name
```

### Symptom: AMD GPU Issues

**Fix 1: Ensure firmware included**
```scheme
(firmware (cons* linux-firmware %base-firmware))
```

**Fix 2: Check kernel messages**
```bash
dmesg | grep -i amdgpu
```

AMD GPUs should work automatically with Mesa drivers.

### Symptom: Bluetooth Not Working

**Fix 1: Enable service**
```scheme
(services (cons* (service bluetooth-service-type)
                 %desktop-services))
```

**Fix 2: Check firmware**
```scheme
(firmware (cons* linux-firmware %base-firmware))
```

**Fix 3: Pair devices**
```bash
bluetoothctl
scan on
pair XX:XX:XX:XX:XX:XX
connect XX:XX:XX:XX:XX:XX
```

### Symptom: Sound Not Working

**Fix 1: User in audio group**
```scheme
(supplementary-groups '("wheel" "netdev" "audio" "video"))
```

**Fix 2: Check audio server**
```bash
# PipeWire
wpctl status

# PulseAudio
pactl info
```

**Fix 3: Check for muted channels**
```bash
alsamixer
# Press F6 to select sound card
# Unmute with M key
```

### Symptom: Printer Not Detected

**Fix 1: Enable CUPS service**
```scheme
(services (cons* (service cups-service-type)
                 %desktop-services))
```

**Fix 2: Check web interface**
- Visit `http://localhost:631`
- Add printer through web UI

**Fix 3: Install proprietary drivers**
- Check nonguix channel for proprietary printer drivers

### Diagnostic Commands

```bash
# Check kernel drivers in use
lspci -k

# Check firmware loading
dmesg | grep -i firmware

# List loaded kernel modules
lsmod

# Show current system configuration
guix system describe
```

## Section 16: Troubleshooting — System Configuration Errors

### Symptom: guix system reconfigure Fails with Syntax Error

**Fix 1: Test build without applying**
```bash
guix system build /etc/config.scm
```

**Fix 2: Check Scheme syntax**
- Ensure parentheses match
- Check quoting: `'symbol` vs `"string"`
- Verify module imports

**Fix 3: Test in VM**
```bash
guix system vm /etc/config.scm
```

### Symptom: guix system reconfigure Fails with "Unknown Package"

**Fix 1: Update package list**
```bash
guix pull
```

**Fix 2: Search for correct name**
```bash
guix search package-name
guix search "description"
```

**Fix 3: Verify nonguix channel**
- Check `~/.config/guix/channels.scm` exists
- Run `guix pull` to update channels

### Symptom: Service Fails to Start

**Fix 1: Check service status**
```bash
herd status
herd status service-name
```

**Fix 2: Check logs**
```bash
ls /var/log/
cat /var/log/messages
```

**Fix 3: Restart service**
```bash
sudo herd restart service-name
```

### Symptom: /etc/config.scm Modifications Lost After Reboot

**Explanation:** `/etc` is managed by Guix. Changes are not persistent.

**Fix:** Edit the source config and reconfigure:
```bash
sudo nano /etc/config.scm  # Edit your actual config
sudo guix system reconfigure /etc/config.scm
```

### Pre-Flight Check Workflow

Before applying major changes:

```bash
# 1. Dry run build
guix system build config.scm

# 2. Test in VM
guix system vm config.scm

# 3. Apply configuration
sudo guix system reconfigure config.scm
```

## Section 17: Troubleshooting — Package Management Issues

### Symptom: guix pull Fails

**Fix 1: Check connectivity**
```bash
ping git.savannah.gnu.org
```

**Fix 2: Use fallback building**
```bash
guix pull --fallback
```

**Fix 3: Check channels.scm**
- Verify URLs are correct
- Check introduction fingerprints

**Fix 4: Allow downgrades**
```bash
guix pull --allow-downgrades
```

### Symptom: Substitute Download Fails / Timeout

**Fix 1: Check substitute URLs**
```scheme
(substitute-urls
 (append (list "https://substitutes.nonguix.org")
   %default-substitute-urls))
```

**Fix 2: Authorize substitute keys**
```bash
sudo guix archive --authorize < signing-key.pub
```

**Fix 3: Explicit substitute URLs**
```bash
guix package --install package --substitute-urls='https://ci.guix.gnu.org https://substitutes.nonguix.org'
```

**Fix 4: Check build status**
- Visit https://cuirass.nonguix.org/ for nonguix builds

### Symptom: Package Not Found

**Fix 1: Search correctly**
```bash
guix search package-name
guix search --regex "pattern"
```

**Fix 2: Update package database**
```bash
guix pull
```

**Fix 3: Check nonguix channel**
- Non-free software is in nonguix, not official Guix

### Symptom: Build Takes Very Long / Compilation

**Fix 1: Configure substitutes**
```scheme
(substitute-urls
 (append (list "https://substitutes.nonguix.org")
   %default-substitute-urls))
```

**Fix 2: Reduce output**
```bash
guix build --verbosity=0 package
```

**Fix 3: Pin kernel version**
Reference `docs/nonguix.org` lines 554-588 for version pinning to avoid frequent rebuilds.

### Symptom: Disk Space Full in /gnu/store

**Fix 1: Garbage collect**
```bash
# Remove unused packages
guix gc

# Free specific amount
guix gc --free-space=10GB
```

**Fix 2: Delete old generations**
```bash
# Remove old system generations
guix system delete-generations 1m  # Older than 1 month

# Remove old user generations
guix package --delete-generations
```

**Fix 3: Check store size**
```bash
du -sh /gnu/store
```

---

## Quick Reference: Example Files

| File | Purpose |
|------|---------|
| `examples/channel.scm` | Channel definitions with nonguix + rosenthal |
| `examples/bare-bones.scm` | Minimal headless/server config |
| `examples/desktop.scm` | GNOME + Xfce with LUKS encryption |
| `examples/desktop-kde.scm` | **KDE Plasma (recommended)** with LUKS |
| `examples/lightweight-desktop.scm` | Window managers (i3, ratpoison) |
| `examples/home-config.scm` | Guix Home user configuration |

## Quick Reference: Essential Commands

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
```

## Quick Reference: Key Documentation

- `docs/nonguix.org` — Nonguix configuration (kernel, firmware, NVIDIA, substitutes)
- `docs/GNU Guix Reference Manual.md` — Comprehensive service and package reference
- `SKILL_AUTHORING_GUIDE.md` — This skill format specification

## Important Reminders

1. **Always use nonguix for modern hardware** — Without it, WiFi, GPU, and CPU features won't work
2. **Lock your channels** — Use `guix time-machine` to create `channels.lock` for reproducibility
3. **Test before applying** — Use `guix system build` and `guix system vm` to test configs
4. **Keep generations** — Don't delete old generations until you're sure the new one works
5. **Use substitutes** — Configure nonguix substitute server to avoid long compilations
