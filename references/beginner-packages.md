## Section 11: Common Software & Services Configuration

### Finding and Installing Packages

```bash
# Search for packages
guix search package-name
guix search "description text"

# Install to user profile
guix package --install package-name
guix package -i package-name
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
                   %desktop-services)
)
```

### Programming Language Environments

For development environments, use `guix shell` instead of installing globally:

```bash
# Basic Python environment
guix shell python python-pip

# With development tools
guix shell python python-pip --development
```

**Example manifest.scm:**

```scheme
(specifications->manifest
  (list "python"
        "python-pip"
        "python-numpy"
        "python-requests"))
```

**Container environments:**

```bash
# Create isolated container
guix shell --container --network python python-pip

# With preserved home directory
guix shell --container --network --preserve=HOME python
```

**FHS emulation** for tools expecting Filesystem Hierarchy Standard layout:

```bash
guix shell --emulate-fhs node npm
```

### Nonguix Substitute Server

Pre-built binaries save significant compilation time. The nonguix substitute server provides pre-built packages for nonguix channel software.

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
                   %default-authorized-guix-keys)))))))
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

**First-Time Reconfigure:**

```bash
sudo guix archive --authorize < signing-key.pub
sudo guix system reconfigure /etc/config.scm \
  --substitute-urls='https://ci.guix.gnu.org https://bordeaux.guix.gnu.org https://substitutes.nonguix.org'
```

**Check Build Status:** visit https://cuirass.nonguix.org/

`reference:` https://substitutes.nonguix.org/ — nonguix substitute server.

---
