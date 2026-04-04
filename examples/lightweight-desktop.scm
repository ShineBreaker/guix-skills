;; This is an operating system configuration template for a "desktop" setup
;; without full-blown desktop environments.

(use-modules (gnu)
             (guix utils)
             (nonguix)
             (gnu system nss)
             (gnu services desktop)
             (gnu packages bootloaders)
             (gnu packages emacs)
             (gnu packages emacs-xyz)
             (gnu packages ratpoison)
             (gnu packages suckless)
             (gnu packages wm)
             (gnu packages xorg))

(define guix-channels (include "./channels.lock"))

(define %my-os
  (operating-system
    (host-name "antelope")
    (timezone "Europe/Paris")
    (locale "en_US.utf8")

    (kernel linux)
    (firmware (cons* linux-firmware %base-firmware))

    ;; Use the UEFI variant of GRUB with the EFI System
    ;; Partition mounted on /boot/efi.
    (bootloader (bootloader-configuration
                  (bootloader grub-efi-bootloader)
                  (targets '("/boot/efi"))))

    ;; Assume the target root file system is labelled "my-root",
    ;; and the EFI System Partition has UUID 1234-ABCD.
    (file-systems (append
                   (list (file-system
                           (device (file-system-label "my-root"))
                           (mount-point "/")
                           (type "ext4"))
                         (file-system
                           (device (uuid "1234-ABCD" 'fat))
                           (mount-point "/boot/efi")
                           (type "vfat")))
                   %base-file-systems))

    (users (cons (user-account
                   (name "alice")
                   (comment "Bob's sister")
                   (group "users")
                   (supplementary-groups '("wheel" "netdev" "audio" "video")))
                 %base-user-accounts))

    ;; Add a bunch of window managers; we can choose one at
    ;; the log-in screen with F1.
    (packages (append (list
                       ;; window managers
                       ratpoison i3-wm i3status dmenu
                       emacs emacs-exwm emacs-desktop-environment
                       ;; terminal emulator
                       xterm)
                      %base-packages))

    ;; Use the "desktop" services, which include the X11
    ;; log-in service, networking with NetworkManager, and more.
    ;; 在这里添加了一些用于利用 guix time-machine 来锁定 channel 的功能
    ;; 具体的原理其实就是让 channel 指向一个固定了 commit 的新文件，从而避免 channel 被更新
    ;; 利用 guix time-machine --channel ./channels.scm -- describe --format=channels ./channels.lock 来生成锁文件
    ;; 推荐利用包装器 ( 比如说 `just` 来自动化这一个流程)
    (services (append (list
      (simple-service 'home-channels home-channels-service-type
                      guix-channels))
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
