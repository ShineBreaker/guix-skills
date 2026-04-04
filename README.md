# Guix 配置与排错助手

一个专为 Guix 新手和进阶用户设计的 AI 助手，帮助你快速搭建可用的 Guix 系统并解决常见问题。

## 简介

这个 skill 专注于 Guix 系统配置和问题排查，特别针对现代硬件兼容性（通过 nonguix 实现）。无论你是刚从其他 Linux 发行版转过来，还是刚开始接触 Guix，都能在这里找到实用的配置模板和排错指南。

## 主要功能

- **现代硬件兼容性配置（nonguix）**
  - 非自由内核和固件支持
  - CPU 微码更新
  - 确保笔记本和台式机都能正常工作

- **KDE Plasma 桌面环境（推荐给新手）**
  - 最友好的入门选择
  - 完整的桌面体验
  - 良好的硬件兼容性

- **guix time-machine channel 锁定**
  - 确保配置可复现
  - 避免更新导致的意外问题

- **NVIDIA/AMD/Intel GPU 配置**
  - 专有驱动和开源驱动支持
  - 双显卡切换方案

- **网络硬件配置（WiFi/蓝牙）**
  - Intel、Broadcom、Realtek 无线网卡
  - 蓝牙设备支持

- **音频和打印机配置**
  - PipeWire/PulseAudio 音频服务
  - CUPS 打印服务

- **LUKS 磁盘加密**
  - 全盘加密配置
  - 安全启动方案

- **Guix Home 用户级配置**
  - 用户环境管理
  - 点文件配置

- **常用软件和服务配置**
  - Docker、SSH、数据库等服务
  - 日常应用软件

- **编程语言环境（Python/Node.js/Rust等）**
  - 隔离的开发环境
  - 可复现的项目配置

- **四大场景排错**
  - 引导问题（GRUB、启动失败）
  - 硬件驱动问题（显卡、WiFi、蓝牙）
  - 配置错误（语法错误、服务失败）
  - 包管理问题（substitute 失败、channel 错误）

## 使用方法

1. **自动激活**：编辑 `.scm` 文件时自动激活此 skill
2. **手动调用**：在对话中输入 `/guix` 手动调用

## 前置条件

- 已安装 Guix 系统（或准备安装）
- 了解基本的 Scheme 语法（可选，skill 会提供模板）

## 参考资料

- [Nonguix 文档](../../docs/nonguix.org) - 现代硬件支持的核心文档
- [Guix 参考手册](../../docs/GNU Guix Reference Manual.md) - 官方完整文档
- [配置示例](../../examples/) - 可直接使用的配置模板
  - `bare-bones.scm` - 最小化配置
  - `desktop.scm` - GNOME/Xfce 桌面配置
  - `desktop-kde.scm` - KDE Plasma 桌面配置（推荐）
  - `lightweight-desktop.scm` - 轻量级窗口管理器配置
  - `home-config.scm` - Guix Home 用户配置
  - `channel.scm` - 频道定义模板

## 外部链接

- [Nonguix 项目](https://gitlab.com/nonguix/nonguix)
- [Guix 官方手册](https://guix.gnu.org/manual/)
- [Nonguix Substitute 服务器](https://substitutes.nonguix.org/)
