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

```bash
tiec main.tie -o pkg.exe
```

## 内容 / Contents

- `main.tie` CLI 主入口（`tie init/add/install/build/run` 端到端）
- `deps` / `lock` / `manifest` 依赖解析、锁文件与清单
- `fetch` / `pack` / `publish` / `search` git/registry 三源与发布搜索

## License

本仓库按 **Tie Public License v2.0（TPL 2.0）** 授权发布（全文见 [LICENSE](LICENSE)）：
你可自由使用、修改并分发本软件源码，包括用于商业产品，仅需保留版权声明并附本许可证。

EN: This repository is released under the **Tie Public License v2.0 (TPL 2.0)**
(full text in [LICENSE](LICENSE)): you may freely use, modify, and redistribute
the source code, including in commercial products, provided you retain the
copyright notice and a copy of the license.
