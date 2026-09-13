# tpkg

**tie 包管理器** / *Package manager for the tie language*

tpkg 是 tie 生态的包管理器（原 tie-pkg）：依赖解析 + `tie.lock` 锁文件 +
registry 客户端交互，作为 `tie init / add / install / publish / search` 子命令的
实现后端（由 `tie` 主入口按注册表分派）。

*EN: tpkg is the package manager for the tie ecosystem (formerly tie-pkg):
dependency resolution + `tie.lock` lockfile + registry client interaction. It
backs the `tie init / add / install / publish / search` subcommands (dispatched
by the `tie` main entry).*

## 构建 / Build

tpkg 由 tiec 编译（依赖 [tie-lang/tiec](https://github.com/tie-lang/tiec)）：
本仓已 **vendor 所需标准库**到 `std/`（version/bytes/tsha1 等），组件仓自包含、
可独立编译：

```bash
tiec main.tie -o pkg.exe --no-cache   # --no-cache 保证产出，避免 tiec 缓存跳过
```

## 内容 / Contents

- `main.tie` CLI 主入口（`tie init/new/add/install/build/run` 端到端）
- `deps` / `lock` / `manifest` 依赖解析、锁文件与清单
- `fetch` / `pack` / `publish` / `search` git/registry 三源与发布搜索
- `std/` vendor 标准库（TSHA1-f 指纹等）
- `docs/PACKAGE.md` 包管理域设计裁决（版本约束 / 解析树 / 注册中心后端 / 脚手架）
- `probe/` 探针演示（p.9.2.2 / p.9.2.5）

## 里程碑 / Milestones

- **p.9.2.2 包管理器正式落地**：依赖解析树（BFS+传递+MVS+冲突→锁）、版本约束
  （`x.y.z`/`^x.y`/`>=x.y`/`*`，不满足即报错）、上传（pack/publish + TSHA1-f 签名）
  与拉取（path/git/registry 三源）。安全校验由 FNV-1a 升级为 **TSHA1-f 指纹**，
  与 keel_auditor/keelpkg 同一模型，篡改即拒绝。
- **p.9.2.5 脚手架 `tpkg new`**：项目模板（src/ + 清单 + README + .gitignore + LICENSE）
  + 初始化（可选 git init）。

## License

本仓库按 **Tie Public License v2.0（TPL 2.0）** 授权发布（全文见 [LICENSE](LICENSE)）：
你可自由使用、修改并分发本软件源码，包括用于商业产品，仅需保留版权声明并附本许可证。

EN: This repository is released under the **Tie Public License v2.0 (TPL 2.0)**
(full text in [LICENSE](LICENSE)): you may freely use, modify, and redistribute
the source code, including in commercial products, provided you retain the
copyright notice and a copy of the license.
