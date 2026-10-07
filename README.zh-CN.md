<div align="center">

# keel

**给任意 Git 仓库装上一套工程规范：一条命令安装，按项目取舍，升级时保留你的修改。**

[![CI](https://github.com/brizenchi/keel/actions/workflows/ci.yml/badge.svg)](https://github.com/brizenchi/keel/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/brizenchi/keel?sort=semver)](https://github.com/brizenchi/keel/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) · 简体中文

</div>

keel 给仓库补齐那些不起眼、但不可或缺的工程基础：成文的规范、CI 质量门禁、密钥扫描、
Conventional Commits 提交规范、GitHub 分支规则、Dependabot，以及给 AI 编程助手的规则。
需要哪些就选哪些，生成的每个文件都是仓库里普通的、可以随便改的文件。

```console
$ keel init
? Components to install
  ◉ docs            规范文档（docs/standards/）
  ◉ ci              CI 中的语言检查（.github/workflows/keel.yml）
  ◉ commit-lint     PR 标题必须符合 Conventional Commits
  ◉ secrets         密钥扫描：gitleaks 配置 + CI 任务
  ◉ hooks           本地提交钩子：密钥扫描 + 格式化（lefthook.yml）
  ◯ ai              AI 规则：AGENTS.md、CLAUDE.md、Claude Code Hooks
  …
```

## 特点

- **自己选，不强加**：13 个相互独立的组件。安装时不勾选，对应的文件就不会生成；之后关掉，文件会被删除。
- **文件归你**：生成的都是普通文件。`keel update` 会做三方合并，升级时保留你的修改，真正冲突的地方像 git 合并冲突一样标出来。`PROJECT.md`、`CODEOWNERS` 这类文件首次安装后就不再改动。
- **以 CI 为准**：检查在 GitHub Actions 里通过带版本号的[可复用 workflow](docs/workflows.md) 运行。本地钩子只做必须在代码离开电脑前完成的事：密钥扫描和格式化。
- **和 Git 深度整合**：`keel github` 一次配好分支规则（必需的检查、只允许 squash、线性历史）、密钥扫描和推送保护、Dependabot 提醒、私密漏洞报告，可以重复执行。
- **结果确定**：安装就是用 [Copier](https://copier.readthedocs.io/) 渲染模板，过程中没有 AI 参与。同样的回答，生成同样的文件。
- **支持 Go、Node / TypeScript、Python**，也支持包含多个模块的 monorepo。

## 安装

需要 `git` 和 [uv](https://docs.astral.sh/uv/)（或 pipx）。

```bash
curl -fsSL https://raw.githubusercontent.com/brizenchi/keel/main/install.sh | sh
```

这会把 `keel` 这个脚本放到 `~/.local/bin/keel`。每个项目里也会有一份 `.keel/bin/keel`，
团队成员不装全局命令也能直接用。

## 快速开始

```bash
cd your-repo            # 工作区要干净（没有未提交的改动）
keel init               # 勾选组件，回答几个问题
git diff                # 检查生成了什么
keel hooks              # 安装本地钩子（需要 lefthook、gitleaks）
keel github --dry-run   # 预览 GitHub 设置；确认后去掉 --dry-run 再执行
git add -A && git commit -m "chore: install keel"
```

## 日常使用

| 要做的事 | 命令 |
| --- | --- |
| 查看安装了什么、有没有新版本、还缺什么 | `keel status` |
| 检查本机工具 | `keel doctor` |
| 开关组件 | `keel enable ai` · `keel disable dependabot` |
| 修改某个配置 | `keel set default_branch=develop` |
| 新增要检查的模块 | `keel add go_modules dir=services/api` |
| 交互式重新回答所有问题 | `keel config` |
| 升级到最新版本 | `keel update` |
| 检查提交信息 | `keel lint-commit -m "feat(api): add search"` |

所有会改动文件的命令都要求工作区干净，执行完会列出改动的文件，每次调整都是一份可以 review 的 diff。

## 自定义

| 想要…… | 做法 |
| --- | --- |
| 调整任何生成的文件 | 直接改。`keel update` 会保留你的修改 |
| 记录项目自己的约定 | `docs/standards/PROJECT.md` 和 `AGENTS.md` 的 *Project-specific rules* 部分 |
| 增加自己的 CI 检查 | 写在另一个 workflow 文件里；把检查名追加到 `.keel/required-checks.txt`，再运行 `keel github` |
| 部署要等 keel 的检查通过 | `keel set ci_mode=reusable`，在自己的流水线里调用 `./.github/workflows/keel.yml`，部署任务加上 `needs:` |
| 让所有项目一起改 | fork 或者给 keel 提 PR，发布新版本后，各项目执行 `keel update` |

## 文档

- [命令参考](docs/cli.md)
- [组件说明](docs/components.md)
- [配置项](docs/configuration.md)
- [可复用 workflow](docs/workflows.md)
- [从 dev-standards 1.x 迁移](docs/migration.md)

## 版本

发布以 `vX.Y.Z` 标签标记，遵循语义化版本。生成的 workflow 引用 `@v2`（跟随最新 2.x 版本的分支），
项目里实际安装的版本记录在 `.keel/answers.yml`。变更记录见 [CHANGELOG.md](CHANGELOG.md)。

## 参与贡献

欢迎提 issue 和 PR，见 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

## 许可证

[MIT](LICENSE) © brizenchi
