# GitNote

[English](README.md) | [简体中文](README.zh-CN.md)

一个轻量、离线优先的移动端 GitHub Markdown 阅读器。

GitNote 是一个 Android 优先的 Flutter 应用，用于：

- 同步 GitHub 仓库中的 Markdown 文档
- 本地缓存
- 离线阅读
- 目录浏览
- 快速分享

GitNote 不是：

- 笔记平台
- 协同办公系统
- 富文本编辑器
- 万能文件管理器

GitNote 的目标始终很简单：

> 让你离开电脑后，依然可以轻量、快速、舒服地阅读自己的 Markdown 知识库。

------

# 功能特性

- GitHub 仓库同步
- 离线优先阅读
- 本地缓存
- Markdown 阅读
- 目录树浏览
- 基于 `sha` 的增量同步
- 下拉刷新
- 轻量安装包
- 快速启动
- 分享 Markdown 到其他应用

------

# 截图

> TODO

建议补充以下截图：

- 仓库设置页
- 目录树页面
- Markdown 阅读页
- 离线阅读
- 分享操作

------

# 使用场景

## AI Prompt 仓库

```text
/prompts
  coding.md
  translate.md
  agent.md
```

## 技术文档

```text
/docs
  api.md
  deploy.md
  architecture.md
```

## 个人知识库

```text
/notes
  frontend.md
  linux.md
  ai.md
```

## 小说 / 世界观设定

```text
/world
  races.md
  timeline.md
  map.md
```

------

# 支持的文件类型

GitNote 重点支持：

- `.md`
- `.txt`
- Markdown 内嵌图片

GitNote 会继续专注于：

> 轻量的文本型知识阅读。

------

# 文件类型理念

GitNote 有意保持简洁。

这个项目不会演变成：

- Office 查看器
- 富文本编辑器
- 通用文件管理器

因此 GitNote 不会内置支持以下文件的渲染：

- PDF
- DOCX
- Excel
- PPT

对于这些文件类型，GitNote 未来最多可能提供：

- 下载
- 分享
- 使用外部应用打开

这是长期产品理念，不是临时限制。

------

# 快速开始

## 环境要求

- Flutter SDK 3.29.x
- JDK 17
- Android SDK

------

## 运行

```bash
flutter pub get
flutter run
```

构建 APK：

```bash
flutter build apk
```

------

# 仓库配置

首次启动 GitNote 时，需要配置：

- 仓库 URL
- 分支
- Token（可选）
- 根路径（可选）

示例：

```text
Repository:
https://github.com/owner/repo

Branch:
main

Root Path:
docs
```

------

# 同步策略

GitNote 使用：

- 仓库目录树同步
- 按需文件缓存
- 基于 `sha` 的增量更新

当前流程：

1. 同步目录树
2. 浏览仓库
3. 打开 Markdown 文件
4. 缓存到本地
5. 后续离线阅读

GitNote 不会在首次启动时下载整个仓库。

------

# 本地缓存结构

```text
/app_data/github_notes/{repoKey}/
  index.json
  files/
    README.md
    docs/xxx.md
```

------

# 注意事项

- GitHub token 当前通过 `shared_preferences` 存储
- 如果 GitHub Trees API 返回 `truncated=true`，GitNote 会停止同步并显示仓库过大的提示

------

# 路线图

计划支持：

- 全文搜索
- 更好的离线体验
- 多仓库支持
- GitLab 支持
- Gitee 支持
- 更好的分享体验

暂无计划：

- 富文本编辑
- Office 文档渲染
- 团队协作系统
- 云文档平台

------

# 产品理念

GitNote 的设计目标是：

- 轻量
- 快速
- 离线优先
- Markdown 优先
- 贴近 Git 工作流

GitNote 更接近：

> 一个移动端 Git Markdown 阅读器

而不是：

> 一个全功能笔记平台。

------

# 许可证

MIT
