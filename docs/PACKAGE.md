# tpkg 包管理域设计裁决（p.9.2.2 / p.9.2.5）

*EN: tpkg package-management design decisions (p.9.2.2 / p.9.2.5).*

本文记录 p.9.2.2「包管理器正式落地」的三项硬裁决（版本约束形态、依赖解析树、
注册中心后端）与 p.9.2.5「脚手架 tie new」的模板结构，以及在当前编译环境下的
已知限制与落地方式。

## 1. 版本约束形态（决策）/ Version-constraint forms

语义化版本，约束支持**子集**（与平标准库 `std/version.tie` 的 `satisfies`
完全对齐，`fetch.tie` / `deps.tie` 经 `ft.version_ok` 复用同一底层）：

| 形态 | 语义 | 示例 |
|---|---|---|
| 精确 `x.y.z` | `v == x.y.z` | `1.2.3` |
| 区间 `^x.y` | `x.y.0 <= v < (x+1).0.0` | `^1.2` |
| 下界 `>=x.y` | `v >= x.y.0` | `>=1.0` |
| 任意 `*` | 恒真 | `*` |

- **不在本轮支持**：`=1.2.3`（精确写 `1.2.3` 即可，语义等价）、`>=1.2 <2`
  双端区间（`^` 已覆盖"同主版本最首次兼容"最常见场景）。tie 约束语法无 `--`
  前缀，`^`/`>=`/`*` 之外的字节前缀一律视为非法，`tie add` 时 `mf`/`dp`
  给出格式警告。
- 选择依据：平 std 的 `satisfies` 只实现这四种；保持 CLI 与 std 单一实现源，
  避免绑定点分裂。后续若要双端区间，统一在 `std/version.tie` 扩展后由
  `fetch.tie` 透传，tpkg 不改语义。

*EN: Subset = exact `x.y.z` / caret `^x.y` / gte `>=x.y` / any `*`, matching
`std/version.tie::satisfies`. `=` and dual-ended ranges are deferred (exact
spelled without `=`; `^` covers the common "same-major latest-compat" case).*

## 2. 依赖解析树 / Dependency resolution tree

- 清单声明依赖 `{ name: spec }`（td / tie.pkg）。
- **算法**：`deps.resolve` 用 **BFS + 队头指针**（无递归，规避 tie 无递归约束）
  递归解析传递依赖；同包名按 `name+spec` 去重（防环/防重复处理）；深度上限 3。
- **版本选择**：**MVS 最小版本选择**（Go 风格，P2c）——约束解析取满足全部约束的
  **最低**版本，可复现、幂等。
- **冲突裁决**：同名再次出现且来源/约束不兼容时，registry 源按**全部累积约束集**
  重新选版（`resolve_from_constraints`），无交集则报错
  `依赖冲突: <name> 无满足全部约束的版本`；path/git 非版本源要求来源一致，否则
  冲突。冲突结果为**解析失败**（install 退出非 0）。
- 解析产物写回 `tie.lock`（根项目 + 每个依赖的精确版本/来源/原 spec）；再来一次
  `install` 时锁与当前清单一致 → 幂等恢复，不重拉。

*EN: BFS (no recursion) resolution over the transitive graph; per `name+spec`
dedup; MVS minimal-version selection; conflict → re-resolve over the union of
constraints else hard error; results persisted to `tie.lock` for idempotent
recovery.*

## 3. 注册中心后端（决策）/ Registry backend

- **当前默认 = 文件/目录注册表（暂存后端）**：`TIE_REGISTRY` 指向一个目录，
  布局 `packages/<name>/<ver>.tar.gz` + `index.tie`（行 `name|version|desc`）。
  `tie search/info` 读 index；`tie install` 下载 tar.gz 解压安装；发布方
  `tie pack|publish` 产出带 TSHA1-f 指纹的签名分发单元。
- **线上服务端形态（注明，未落服务端代码）**：把上述目录用任意静态 HTTP 服务
  承载（如 `python -m http.server`）即得线上基址；`fetch`/`search` 用 `http_get`
  拉 index、`http_get_file` 下包，支持 `TIE_REGISTRY=http://host:port`。
  完整线上（鉴权/上传 API/索引推送）随后续里程碑，前端 CLI 无需改动即可切换。
- **p.7.2.5 keelpkg 文件注册树为上游正式目标**：`compiler/keel/keel_registry_cli.tie`
  （namespace `keelpkg`）实现 `publish/info/versions`，布局
  `<root>/<pkg>/index.td` + `<root>/<pkg>/<ver>/pkg.zd` + `info.td` + `pkg.zd.fp`
  （tsha1f 指纹）。tpkg 的安全校验与之一致（TSHA1-f 指纹模型），后端树格式可在
  tpkg 侧注册一个 keelpkg 式的读取适配后对齐。

### 3.1 与 keel_auditor / keelpkg 的复用

- **TSHA1-f 指纹**：`pack.tie` 用标准库 `std/tsha1.tie` 的 `tsha1f(bytes, 48)`
  对 `.tieir` 计算单文件指纹（p.9.2.2 起由 FNV-1a 升级），签名 `fp` 字段存储；
  `verify` 重算比对 → 篡改即拒绝——与
  `compiler/keel/keel_auditor_fingerprint_tree`（per-file tsha1f）及
  `keelpkg .zd.fp` 同一指纹模型（复用思路，不内联 keel 实现，仅统一指纹算法）。
- **标准库**：为让组件仓自包含可独立编译，`version.tie` / `bytes.tie` /
  `tsha1.tie`（含 `base48.tie`、`tsha1_w48.tie`）vendor 进本仓 `std/`，import
  改为 `./std/...`。

*EN: default backend = file/dir registry (tar.gz + index.tie over `TIE_REGISTRY`),
servable over HTTP for the online form; keelpkg's td/zd file tree is the upstream
formal target. TSHA1-f fingerprint reused from `keel_auditor`/`keelpkg` model.*

## 4. 当前环境的已知限制 / Known limitation (this toolchain)

- **`untar_gz` 对中大体量 gzip 包解压失败**（tiec 内置解压器对部分 gzip 流 bug，
  独立于 tpkg）。因此**在线 HTTP registry 的二进制 fetch 在本环境不可测**
  （下包后 untar 失败、解析中止）。已验证的链路全部离线可用：
  path 源解析安装（`copy_dir`，不经 untar）、版本约束解析与不满足报错、
  打包发布（tar.gz）、TSHA1-f 篡改拒绝。file/za 后端 + keelpkg 文件树是绕开该
  限制的正式路径（不经 gzip tar）。

*EN: `untar_gz` mis-handles larger gzip archives in the current tiec build, so
online-HTTP binary fetch is untestable here; all offline paths (path-source
resolve/install, constraint checks, pack, TSHA1-f tamper rejection) are verified.
The file/`keelpkg` registry tree (no gzip tar) is the formal path around it.*

## 5. 脚手架模板结构（p.9.2.5）/ Scaffold template (p.9.2.5)

`tpkg new <project>` 生成的骨架（参数化项目名注入）：

```
<project>/
├── src/
│   └── main.tie          // hello world，可被 tiec 编译运行
├── tie.pkg              // 清单（name=<project>,main=src/main.tie）
├── README.md            // 项目说明
├── .gitignore           // 忽略 .tie/ 产物、*.exe、*.tar.gz
└── LICENSE              // 引用 TPL 2.0（生成简要说明，非全文避免膨胀）
```

- 清单键 `tie.pkg`（沿用既有 install/resolve 机器与注册表的读取面；"pkg.td"
  曾考虑为清单名，但因整套解析/注册链均键于 `tie.pkg`，为一致性保留 `tie.pkg`）。
- 入口放 `src/main.tie`，`tie.pkg` 的 `main` 指向它；`tpkg run` / `tiec` 可编译。
- 可选 `--git` 在生成后 `git init`。

*EN: scaffold = `src/main.tie` + manifest `tie.pkg` (kept over `pkg.td` for
consistency with the resolve/registry chain) + README + .gitignore + LICENSE;
entry under `src/`, parameterized by project name; optional `git init`.*