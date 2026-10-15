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
本仓已 **vendor 所需标准库**到 `std/`（version/bytes/blake3/rans/tzp/zlib 等），组件仓自包含、
可独立编译：

```bash
tiec main.tie -o pkg.exe --no-cache   # --no-cache 保证产出，避免 tiec 缓存跳过
```

## 内容 / Contents

- `main.tie` CLI 主入口（`tie init/new/add/install/build/run` 端到端）
- `deps` / `lock` / `manifest` 依赖解析、锁文件与清单
- `fetch` / `pack` / `publish` / `search` git/registry 三源与发布搜索
- `std/` vendor 标准库（blake3 指纹 / rANS 熵层 / tzp 容器等）
- `docs/PACKAGE.md` 包管理域设计裁决（版本约束 / 解析树 / 注册中心后端 / 脚手架）
- `probe/` 探针演示（p.9.2.2 / p.9.2.5）

## 里程碑 / Milestones

- **p.9.2.2 包管理器正式落地**：依赖解析树（BFS+传递+MVS+冲突→锁）、版本约束
  （`x.y.z`/`^x.y`/`>=x.y`/`*`，不满足即报错）、上传（pack/publish）与拉取
  （path/git/registry 三源）。安全校验历经 FNV-1a → TSHA1-f → **blake3**
  （全生态哈希基线），篡改即拒绝。
- **打包链路换代：tzp / .tpkg**：分发包 = `.tpkg`（tzp 归档容器，rANS 熵层；
  `std/tzp` · `std/rans`）；安装/解包走 `tzp_unpack`（替代系统 tar / untar_gz；
  registry 链路不再依赖外部工具）；签名指纹 = blake3。包内容 = 源码 + `tieir`
  + `signature` 三件套。
- **p.9.2.5 脚手架 `tpkg new`**：项目模板（src/ + 清单 + README + .gitignore + LICENSE）
  + 初始化（可选 git init）。
- **多模板脚手架（35 档）**：`tpkg new --kind=<档>` 覆盖规范六域 35 档；
  `--template=<名>` 用户模板（~/.tpkg/templates/，`{{name}}` 字符串替换）；
  `tpkg template list` 列出官方档与用户模板；清单缺省 `main` 按 kind 推导。
- **变体引擎**：档内场景开关（`--static` / `--serverless` / `--sdk` / `--robotics` 等，
  与 ch05 各档变体行一致）；互斥变体生成时拒绝（如 `--static`×`--ssr`）；
  `cli --script` 生成轻档（根扁平单文件）。
- **领域示例文件**：每档生成 1-3 个代表性示例（六型内容：td/md/csv/cir/case 数据与
  prog/libfn 代码骨架——如 circuit 的 SPICE 网表、data 的 CSV 样例、cli 的子命令与冒烟测试）。

## License

本仓库按 **Tie Public License v2.0（TPL 2.0）** 授权发布（全文见 [LICENSE](LICENSE)）：
你可自由使用、修改并分发本软件源码，包括用于商业产品，仅需保留版权声明并附本许可证。

EN: This repository is released under the **Tie Public License v2.0 (TPL 2.0)**
(full text in [LICENSE](LICENSE)): you may freely use, modify, and redistribute
the source code, including in commercial products, provided you retain the
copyright notice and a copy of the license.
