# Guix 配置与排错助手 (`guix-skills`)

一个自包含的 Guix System 配置 / 排错助手，面向**任何使用 Guix 的人**，不绑定某一台机器或某一个仓库。覆盖两块：

1. **新手从零搭建 Guix System**（非自由频道 + 桌面 + GPU + LUKS + Guix Home + channel 锁定）；
2. **操作遵循 `blue` 式任务运行器模式的 Guix 配置仓库**（tangle 源码 + 统一 CLI 封装 `guix`，安全可复现）。

`blue` 来自某个流行配置仓库家族，但本 skill 讲的是它背后的**通用模式**——任何 Guix 配置仓库都能套用。文中用 `Guix-configs` 这个真实仓库作为「具体实例」举例，但所有模式都泛化、可迁移。

## 渐进式分层（progressive disclosure）

`SKILL.md` 只是「路由 + 不可跳过规则」的薄文件（~120 行），细节下沉到 `references/`，模板留在 `examples/`。

```
guix-skills/
├── SKILL.md              # 薄路由：何时加载哪个 reference + 5 条不可跳过规则
├── README.md             # 本文件
├── references/           # 按需加载（agent 不每次全读）
│   ├── beginner-foundation.md  # Tier1 §1–§8.6：非自由频道/bootloader/fs/users/桌面/GPU/网络/音频/打印
│   ├── beginner-home.md       # Tier1 §9 LUKS + §10 Guix Home + §10.5 channel 锁定
│   ├── beginner-packages.md   # Tier1 §11：软件/服务/locale/语言环境
│   ├── blue-runner.md         # 【通用】blue 式任务运行器模式 + 如何移植到你自己的仓库
│   ├── dotfiles-general.md    # 【通用】dotfiles 双轨（不可变/可变）的通用模式与验证
│   ├── repo-workflow.md       # 【通用】从配置仓库工作时的跨切面习惯
│   ├── repo-guix-configs-example.md  # 【具体实例】Guix-configs 家族某仓库的命令表/目录布局/age 路径
│   ├── iso-build.md           # Tier3 §16：Live ISO 构建（guix system image）+ §16.4 实测踩坑库
│   ├── advanced.md            # Tier3 §17–§19：FHS 容器 / age 加密 / 典型仓库布局
│   ├── foot-guns.md           # §20 验证过的反模式库 + §21 examples 目录地图
│   └── quick-ref.md           # 命令速查 + 上游手册 URL + 按需诊断命令
└── examples/             # 5 个「起点模板」（非真实 live 配置，带 WARNING 头）
    ├── bare-bones.scm / channel.scm / desktop.scm
    ├── desktop-kde.scm / home-config.scm
```

## 三档内容

- **Tier 1（新手）**：从零起步的完整教程。读完得到一个能用的 `config.scm`。
- **Tier 2（配置仓库模式）**：通用任务运行器（`blue-runner.md`）、dotfiles 双轨（`dotfiles-general.md`）、从仓库工作的习惯（`repo-workflow.md`）；另附 `repo-guix-configs-example.md` 作为某个具体仓库的实例。
- **Tier 3（进阶）**：Live ISO 自助打包、FHS 容器模拟、age 加密、典型仓库布局。

## 已验证经验（内嵌，不依赖其他 skill）

这些坑都来自**真实构建 / 调试会话**，已蒸馏进 skill：

- `make-installation-os` 在 `(gnu system install)`，不在第三方 channel；`guix repl` 不自动 import。
- `(delete kmscon-service-type)` 是 no-op（kmscon 默认就启用）。
- ISO tangle 目标**不能复用**主机配置输出文件，否则污染主机配置。
- `slim` 下 `(password #f)` 能进桌面但 `sudo` 被 pam 拒 → 用 `(crypt "live" "$6$abc")`。
- `guix-daemon` 在 btrfs + `privileged? #f` 下 substitute 去重 `rename-file` 报 `EACCES` → 临时 `--disable-deduplication`。
- 镜像站（如 SJTUG）列 `substitute-urls` 即可，**不需要**它的公钥。
- `blue build-iso` / `guix system image` **不需要 sudo**（已两次实测验证）；但 `guix system reconfigure` / `blue rebuild` 需要。

## 外部文档

完整 GNU Guix 手册、Nonguix 说明等「教程级参考」只在 `references/quick-ref.md` 用 URL 列出，需要时 `web_extract` 一次即可。

## 使用方法

1. **自动激活**：编辑 `.scm` 文件时（路径匹配 `**/*.scm` / `.agents/skills/guix-skills/**`）自动加载本 skill 的 `SKILL.md`。
2. **按需深入**：按上面的表 `skill_view(name='guix-skills', file_path='references/<topic>.md')` 拉对应细节。
3. **手动调用**：对话输入 `/guix-skills`。

## 前置条件

- 已安装 Guix 系统（或准备安装）
- 了解基本 Scheme 语法（可选，skill 提供模板）

## 关于 `examples/`

`examples/*.scm` 是起点模板，每个文件首部有 `;; WARNING:` 注释，提醒：**这是模板，不是某仓库的 live 配置**。要把模板模式应用到真实仓库，先看该仓库 `config.org` / `config.scm` 当前状态再决定。
