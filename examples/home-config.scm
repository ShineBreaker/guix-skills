;; 这是一个基本的Guix Home配置示例

(use-modules (gnu home)
             (gnu packages)
             (gnu services)
             (guix gexp)
             (gnu home services shells))

(home-environment
  ;; 用户级软件包
  (packages (specifications->packages
             (list "git"
                   "emacs"
                   "vim"
                   "htop")))

  ;; 用户服务配置
  (services
   (list
    ;; Bash配置
    (service home-bash-service-type
             (home-bash-configuration
              (aliases '(("ll" . "ls -l")
                        ("la" . "ls -a")))
              (bashrc (list (plain-file "bashrc-extra"
                                       "export EDITOR=emacs\n"))))))))
