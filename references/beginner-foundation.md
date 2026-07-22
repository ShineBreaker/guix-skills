# Tier 1 — Beginner Guide

## Section 1: Overview & Quick Start

### What This Skill Covers

- Setting up Guix System with modern hardware support (nonguix)
- Configuring desktop environments (KDE Plasma recommended for beginners)
- Setting up GPU drivers (NVIDIA, AMD, Intel)
- Configuring networking (WiFi, Ethernet, Bluetooth)
- Setting up LUKS disk encryption
- Managing user environments with Guix Home
- Troubleshooting boot, hardware, configuration, and package issues

### CRITICAL FIRST STEP: Set Up Nonguix Channel

**Without nonguix, most modern hardware WILL NOT WORK.** This includes WiFi cards, GPUs, and CPUs that need proprietary firmware.

Create `~/.config/guix/channels.scm` with this content:

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

`reference:` https://gitlab.com/nonguix/nonguix — nonguix project README and channel introduction.

> **Done when:** `~/.config/guix/channels.scm` exists and `guix pull` succeeds.

## Section 2: Essential System Configuration (Nonguix Foundation)

Every Guix System configuration for modern hardware MUST include these nonguix components. Reference `examples/bare-bones.scm`.

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

`reference:` https://guix.gnu.org/manual/en/html_node/operating-system-Reference.html — full `operating-system` record reference.

> **Done when:** the OS record has `(kernel linux)`, `(initrd microcode-initrd)`, and `(firmware (cons* linux-firmware %base-firmware))`.

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

> **Be careful:** wrong target can overwrite other OS bootloaders

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

| Group    | Purpose                             |
| -------- | ----------------------------------- |
| `wheel`  | sudo access                         |
| `netdev` | Network management (NetworkManager) |
| `audio`  | Audio device access                 |
| `video`  | Video/GPU access                    |

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

Reference `examples/desktop.scm`:

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
         (guix (guix-for-channels guix-channels))))))))
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
       (guix (guix-for-channels guix-channels))))))))
```

**Note:** GDM (GNOME Display Manager) has known issues with NVIDIA. Consider replacing with SDDM if using NVIDIA.

### Option C: Lightweight Desktop (Window Managers)

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
       (guix (guix-for-channels guix-channels))))))))
```

### Service Sets Explained

- `%base-services`: Minimal services (Shepherd, syslog, etc.)
- `%desktop-services`: Full desktop (X11/Wayland, NetworkManager, Bluetooth, etc.)

`reference:` https://guix.gnu.org/manual/en/html_node/Desktop-Services.html — full desktop service list.

> **Done when:** the OS record has a desktop service set (`%desktop-services` or `%base-services`), a display manager, and the user's preferred DE/WM.

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

NVIDIA requires special configuration.

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

| Parameter                      | Default    | Description                                         |
| ------------------------------ | ---------- | --------------------------------------------------- |
| `#:driver`                     | `nvda-580` | Driver version (nvda-580, nvda-590, nvda-470, etc.) |
| `#:open-source-kernel-module?` | `#f`       | Use open source kernel modules (Turing+ GPUs)       |
| `#:kernel-mode-setting?`       | `#t`       | Required for Wayland and rootless Xorg              |
| `#:configure-xorg?`            | `#f`       | Configure Xorg for display managers                 |
| `#:remove-nvenc-restriction?`  | `#f`       | Remove NVENC encoding restrictions                  |

**Driver compatibility** (from nonguix docs):

| GPU Generation                | Driver Package               |
| ----------------------------- | ---------------------------- |
| GeForce 50 series (Blackwell) | nvda-580, nvda-590, nvda-595 |
| GeForce 40 series (Ada)       | nvda-580, nvda-590, nvda-595 |
| GeForce 30 series (Ampere)    | nvda-580, nvda-590, nvda-470 |
| GeForce 16/20 series (Turing) | nvda-580, nvda-590, nvda-470 |
| GeForce 10 series (Pascal)    | nvda-580, nvda-470, nvda-390 |

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

**GDM replacement for NVIDIA:** GDM has known issues with NVIDIA; replace with SDDM:

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

**Application-level NVIDIA setup:** for `guix shell` with NVIDIA:

```bash
guix shell mesa-utils nvda@580 --with-graft=mesa=nvda@580 -- glxinfo
```

**Switchable graphics (NVIDIA + Intel/AMD):** Use `prime-run` for PRIME render offload:

```bash
prime-run steam
prime-run firefox
```

`reference:` https://gitlab.com/nonguix/nonguix — search "NVIDIA driver" in the project README.

> **Done when:** the OS record has the correct kernel+firmware for the user's GPU, and the nonguix transformation (if NVIDIA) is applied with the right driver version.

## Section 8: Networking Hardware (WiFi + Ethernet + Bluetooth)

### Intel WiFi (Most Common)

Intel WiFi cards need `iwlwifi-firmware`. Add to your firmware list:

```scheme
(use-modules (nongnu packages linux))

(firmware (cons* iwlwifi-firmware
                 linux-firmware
                 %base-firmware))
```

Common Intel WiFi cards: AX200, AX210, 9560, 8265, etc.

### Broadcom Wireless

Broadcom requires proprietary kernel module and blacklisting:

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

Enable Bluetooth service for desktop:

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

> **Done when:** the firmware list includes the user's WiFi/BT chipset driver, and `rfkill list` shows no soft/hard blocks after boot.

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
# PipeWire
wpctl status

# PulseAudio
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
