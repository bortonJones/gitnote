# GitNote

[English](README.md) | [简体中文](README.zh-CN.md)

A lightweight offline-first GitHub repository file reader for mobile, focused on Markdown knowledge bases.

GitNote is an Android-first Flutter app for:

- Syncing files from a GitHub repository or subdirectory
- Local caching
- Offline reading
- Directory browsing
- Quick sharing

GitNote is not:

- A note-taking platform
- A collaboration system
- A rich text editor
- A universal file manager

GitNote has one simple goal:

> Let you read your own Markdown knowledge base lightly, quickly, and comfortably after leaving your computer.

------

# Features

- GitHub repository sync
- Offline-first reading
- Local cache
- Markdown reading
- Mermaid diagram rendering in Markdown
- Text file reading
- Image preview
- Directory tree browsing
- Incremental sync via `sha`
- Pull-to-refresh
- Receive progress for large files
- File share, save, and properties actions
- Lightweight package size
- Fast startup
- Share files to other apps

------

# Screenshots

> TODO

Recommended screenshots:

- Repository setup page
- Directory tree page
- Markdown reader page
- Offline reading
- Share action

------

# Use Cases

## AI Prompt Repository

```text
/prompts
  coding.md
  translate.md
  agent.md
```

## Technical Documentation

```text
/docs
  api.md
  deploy.md
  architecture.md
```

## Personal Knowledge Base

```text
/notes
  frontend.md
  linux.md
  ai.md
```

## Novel / World Building

```text
/world
  races.md
  timeline.md
  map.md
```

------

# Supported File Types

GitNote can preview:

- `.md`
- `.markdown`
- Text files such as `.txt`, `.log`, `.json`, `.yaml`, `.yml`, `.csv`, `.xml`
- Images such as `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`
- Markdown embedded images
- Mermaid code blocks in Markdown

GitNote will continue focusing on:

> Lightweight text-based knowledge reading.

------

# File Type Philosophy

GitNote is intentionally minimal.

The project will not evolve into:

- Office Viewer
- Rich Text Editor
- Universal File Manager

Therefore GitNote does not provide built-in preview rendering for:

- PDF
- DOCX
- Excel
- PPT

For these file types, GitNote may only provide:

- Receive/cache
- Download
- Share
- Open with external apps

This is a long-term product philosophy, not a temporary limitation.

------

# Getting Started

## Environment

- Flutter SDK 3.29.x
- JDK 17
- Android SDK

------

## Run

```bash
flutter pub get
flutter run
```

Build APK:

```bash
flutter build apk
```

------

# Repository Setup

When launching GitNote for the first time, configure:

- Repository URL
- Branch
- Token (optional)
- Root Path (optional)

Example:

```text
Repository:
https://github.com/owner/repo

Branch:
main

Root Path:
docs
```

------

# Sync Strategy

GitNote uses:

- Repository tree sync
- On-demand file caching
- Incremental updates via `sha`

Current workflow:

1. Sync directory tree
2. Browse repository
3. Open a supported file
4. Cache locally
5. Read offline later

GitNote does not download the entire repository on first launch.

------

# Local Cache Structure

```text
/app_data/github_notes/{repoKey}/
  index.json
  files/
    README.md
    docs/xxx.md
    assets/image.png
```

------

# Notes

- GitHub token is currently stored via `shared_preferences`
- If GitHub Trees API returns `truncated=true`, GitNote will stop syncing and show a repository-too-large warning
- Mermaid diagrams are rendered through an embedded WebView and load Mermaid.js from CDN, so diagram rendering requires network access

------

# Roadmap

Planned:

- Full-text search
- Better offline experience
- Multi-repository support
- GitLab support
- Gitee support
- Better sharing experience

Not planned:

- Rich text editing
- Office document rendering
- Team collaboration system
- Cloud document platform

------

# Philosophy

GitNote is designed to be:

- Lightweight
- Fast
- Offline-first
- Markdown-first
- Git workflow friendly

GitNote is closer to:

> A mobile Git Markdown reader

than:

> A full-featured note-taking platform.

------

# License

MIT
