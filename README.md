# GitNote

GitNote 是一个 Android 优先的 Flutter App，用 GitHub API 同步仓库中的 Markdown 笔记，并提供本地缓存、目录浏览和阅读能力。

## 功能概览

- 配置单个 GitHub 仓库进行同步
- 仅同步指定仓库或子目录下的 Markdown 文件
- 目录树浏览、搜索、下拉刷新
- Markdown 内容按需下载并缓存到本地
- 基于 `sha` 做增量同步

## 环境要求

- Flutter SDK 3.29.x
- JDK 17
- Android SDK

如果你的本机路径和项目默认配置不同，需要更新 `android/local.properties`。

如果 Flutter SDK 目录属于另一个 Windows 用户，Flutter 可能会报 Git `dubious ownership`。可执行：

```bash
git config --global --add safe.directory C:/dev/flutter
```

## 使用说明

### 1. 启动应用

在项目根目录执行：

```bash
flutter pub get
flutter run
```

如果你只想做检查或验证构建，可额外执行：

```bash
flutter analyze
flutter test
flutter build apk
```

### 2. 首次进入后的仓库配置

应用首次启动时会直接进入“GitHub 仓库设置”页面，需要填写：

- `仓库链接`：完整 GitHub 仓库地址，例如 `https://github.com/owner/repo`
- `branch`：默认 `main`
- `token（可选）`：公开仓库可留空；私有仓库或需要更高 GitHub API 限额时建议填写
- `rootPath（可选）`：默认 `/`，表示同步整个仓库；也可以填写某个子目录，例如 `docs` 或 `notes/work`

点击“测试连接”时，应用会校验仓库、分支和权限是否可用。

点击“保存配置”后，应用会自动：

1. 测试连接
2. 判断仓库、分支或 `rootPath` 是否变化
3. 如果同步范围发生变化，则清空旧缓存
4. 拉取 `rootPath` 下的 Markdown 目录树
5. 写入本地索引并完成首次目录同步

保存成功后会自动进入笔记目录页。

### 3. 目录页的使用方式

进入目录页后，可以：

- 点击文件夹进入下一级目录
- 点击右上角搜索按钮，按文件名或目录名搜索
- 点击“同步”按钮，重新拉取远端目录树并按 `sha` 增量同步
- 下拉列表触发一次同步
- 点击右上角设置按钮，返回配置页修改仓库信息

目录页会显示最近同步时间。文件夹项会显示“已缓存文件数 / 总文件数”，文件项会显示该 Markdown 是否已经下载到本地。

### 4. Markdown 阅读行为

点击某个 Markdown 文件后会进入阅读页：

- 优先读取本地缓存
- 如果本地尚未缓存该文件，则即时从 GitHub 下载并写入本地
- 点击阅读页右上角刷新按钮，会强制重新拉取当前文件内容

当前版本的同步策略是“先同步目录树，文件内容按需缓存”，不是首次同步时一次性下载全部 Markdown 内容。

## 本地缓存结构

```text
/app_data/github_notes/{repoKey}/
  index.json
  files/
    README.md
    docs/xxx.md
```

`repoKey` 由 `owner_repo_branch` 生成。

## 说明

- `token` 当前保存在 `shared_preferences` 中
- 如果 Trees API 返回 `truncated=true`，当前版本会直接提示仓库过大，不继续同步
