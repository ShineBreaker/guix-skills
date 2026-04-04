;; This is an operating system configuration template for a "desktop" setup
;; with KDE where the root partition is encrypted with LUKS, and a
;; swap file.

(use-modules (gnu)
             (guix utils)
             (nonguix)
             (gnu system nss)
             (gnu services desktop)
             (gnu services sddm)
             (gnu services xorg)
             (gnu packages gnome))

(define guix-channels (include "./channels.lock"))

(define %my-os
  (operating-system
    (host-name "antelope")
    (timezone "Europe/Paris")
    (locale "en_US.utf8")

    (kernel linux)
    (firmware (cons* linux-firmware %base-firmware))

    ;; Choose US English keyboard layout.  The "altgr-intl"
    ;; variant provides dead keys for accented characters.
    (keyboard-layout (keyboard-layout "us" "altgr-intl"))

    ;; Use the UEFI variant of GRUB with the EFI System
    ;; Partition mounted on /boot/efi.
    (bootloader (bootloader-configuration
                  (bootloader grub-efi-bootloader)
                  (targets '("/boot/efi"))
                  (keyboard-layout keyboard-layout)))

    ;; Specify a mapped device for the encrypted root partition.
    ;; The UUID is that returned by 'cryptsetup luksUUID'.
    (mapped-devices
     (list (mapped-device
             (source (uuid "12345678-1234-1234-1234-123456789abc"))
             (target "my-root")
             (type luks-device-mapping))))

    (file-systems (append
                   (list (file-system
                           (device (file-system-label "my-root"))
                           (mount-point "/")
                           (type "ext4")
                           (dependencies mapped-devices))
                         (file-system
                           (device (uuid "1234-ABCD" 'fat))
                           (mount-point "/boot/efi")
                           (type "vfat")))
                   %base-file-systems))

    ;; Specify a swap file for the system, which resides on the
    ;; root file system.
    (swap-devices (list (swap-space
                          (target "/swapfile"))))

    ;; Create user `bob' with `alice' as its initial password.
    (users (cons (user-account
                   (name "bob")
                   (comment "Alice's brother")
                   ;; 注意： 这样写的话会导致非常严重的安全问题，尤其是当你打算把 config 上传到 Github 等 Git托管的时候
                   ;; 所以仅适用于设置一个固定的默认密码，防止进入系统之后无法进入账户。
                   ;; 可以利用 `echo "你的密码" | guix shell openssl -- openssl passwd -6 -stdin`
                   ;; 来生成一个 hash 化的密码，然后将下面一行直接改成 "(password "刚刚生成的密码")" 即可
                   (password (crypt "alice" "$6$abc"))
                   (group "students")
                   (supplementary-groups '("wheel" "netdev" "audio" "video")))
                 %base-user-accounts))

    ;; 添加 groups 的步骤，通常情况下你不会需要这个，但是必须得有
    ;;     (groups (cons* %base-groups))
    (groups (cons* (user-group
                     (name "students"))
                   %base-groups))

    ;; This is where we specify system-wide packages.
    (packages (append (list
                       ;; force user mounts
                       gvfs)
                      %base-packages))

    ;; 使用 KDE Plasma 作为桌面环境 ( KDE 的操作习惯更加贴近 Windows )
    ;; 在这里添加了一些用于利用 guix time-machine 来锁定 channel 的功能
    ;; 具体的原理其实就是让 channel 指向一个固定了 commit 的新文件，从而避免 channel 被更新
    ;; 利用 guix time-machine --channel ./channels.scm -- describe --format=channels ./channels.lock 来生成锁文件
    ;; 推荐利用包装器 ( 比如说 `just` 来自动化这一个流程)
    (services (append (list
      (simple-service 'home-channels home-channels-service-type
                      guix-channels)
      (service plasma-desktop-service-type))
     (modify-services %desktop-services
       (guix-service-type config =>
                          (guix-configuration (inherit config)
                                             (channels guix-channels)
                                             (guix (guix-for-channels
                                                    guix-channels)))))))

    ;; Allow resolution of '.local' host names with mDNS.
    (name-service-switch %mdns-host-lookup-nss)))

((compose (nonguix-transformation-guix))
 %my-os)
