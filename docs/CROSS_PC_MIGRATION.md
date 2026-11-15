# Windows 跨电脑安装与迁移

本集成分支 `codex/portable-workflow-sync-v1` 从远端 main 建立，保留原提交历史，
整合 Word 与项目工作空间。它是待审阅软件分支，不是 main 合并、正式发布或科学批准。

## 已同步内容与边界

| 内容 | 实际来源与状态 |
|---|---|
| 统计、诊断、表格、图表、SCI Figure Style、中文手册 | main `57ac90c8597d1a4195dd3303cfb5fcdc658a867a`，包含已合并 PR #1/#2/#3/#5/#6 |
| 可选 Word 装配与作者修改保护 | 原 PR #7 `70b53b186ac8cf302ba2d07e10b5525f5cda1fe5`，代码已整合；原 PR 仍独立且未合并 |
| 项目初始化、独立批次、配置快照、运行索引与 Word 连接 | 原 PR #8 `baff1a1add79f10df9d160e62b0e096cbf54606f`，代码已整合；原 PR 保留 |
| CCW 科学 Authority 与验证准备 | PR #4 / `feature/ccw-production-validation`，仍独立，不合并、不采用其未决科学定义 |
| 后续本地 CCW 开发源码 | [隔离快照](../development/ccw_candidates/README.md)：47 个源文件及 1 个未定稿模板；不注册、不执行、不宣称可独立恢复原 canary |

生产 Registry 仍只有 `BASELINE_BINARY_RISK` 和 `MI_PS_CONTINUOUS_ATE`。
CCW、LMTP 等原有 experimental/development 状态不提升。生成 Word 不等于论文写作、
因果识别审查或作者采用。历史临床项目、私有配置、患者级表及未授权报告均未迁入 Git。

本地旧中文文档已逐项比对，内容已在 main；旧图件调用器与图片属于此前合成演示，
其绘图能力已有 main 的原生构造器、fixture 和生成入口覆盖，不覆盖较新的样式代码。
旧 Quick Start 工作文件含追加的非代码输出，未作为可运行源码迁入；Git 中的正常入口保留。
其他本地发布检查记录、内部评审 ZIP、审批身份记录与运行证据不作为软件依赖上传。
没有删除或改写这些本地材料。

## 依赖

| 依赖 | 要求 |
|---|---|
| Git | 能从 GitHub 克隆；不需要把凭据写入项目 |
| Python | 支持 3.11–3.13，推荐 3.12；项目入口只需标准库 |
| R | 4.5.1，与现有 `renv.lock` 一致 |
| R 包 | 恢复原 `renv.lock`，不更新统计包版本或锁文件；bootstrap 使用锁中的 renv 1.2.2 |
| 可选 Word 包 | 原 [requirements](../reporting/requirements.txt) 加 [constraints](../reporting/constraints.txt)：python-docx 1.2.0、lxml 6.0.2、Pillow 12.0.0、typing_extensions 4.15.0 |
| Windows 编译工具 | 若精确版本没有可用二进制包，安装与 R 4.5 对应的 Rtools45；依据实际包构建错误处理 |
| 本地 Word 排版检查 | 装配 DOCX 不需要 Office；视觉验收需另备 Word 或 LibreOffice 及相应字体。中文模板使用 SimSun，英文使用 Arial |

Python constraints 是本次可复现安装配置，不是所有 Python/操作系统组合的通用保证。
安装需要访问公开软件源；统计及报告示例不下载研究资料、不访问数据库或模型服务。
Windows 不需要 Linux 的 apt 依赖；GitHub Linux CI 保留原系统依赖安装。

## 新电脑安装

在 PowerShell 中执行。目录名可自行选择，不含本机个人绝对路径依赖：

```powershell
git clone --branch codex/portable-workflow-sync-v1 https://github.com/secdelic/tte-method-library.git tte-method-library
Set-Location tte-method-library
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup_windows.ps1 -WithWord
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke_test_windows.ps1
```

`setup_windows.ps1` 按 Python launcher、PATH 和 R 的安装注册信息发现解释器；
也接受 `-Python`、`-Rscript` 显式指定本机可执行文件。先用 `-CheckOnly` 可只检查版本。
它创建仓库私有 `.venv/`，按声明安装可选 Word 包，恢复并核对全部锁定 R 包，检查可写权限。
它不全局安装 Python 包、不更改全局 PATH、不放宽统计合同、不上传任何报告。
R 包显式安装到当前 checkout 的 renv 库；核验版本及所在位置。与锁定版本一致的
R 自带 base/recommended 包可以由固定 R 安装提供，不接纳任意全局附加包替代项目依赖。
R 的生成式激活脚本留在本机，原 `.Rprofile`、`.gitignore` 与 `renv.lock` 保持原字节。
现有环境已经严格恢复时才使用 `-SkipRRestore`；即使跳过恢复仍要通过版本核对。

`.local/environment.json` 记录本机解释器位置，供 smoke 脚本使用；它与 `.venv/`、
`.renv-bootstrap/`、renv 缓存和 `/project/` 都被忽略。不要在电脑之间复制这些环境目录，
在新电脑重新运行 setup。没有必填 API key、数据库密码或 `.env`。

## 最小验收与输出

smoke 脚本运行原六个 R 测试脚本、旧 Quick Start、14 项固定数值检查、项目隔离测试、
原 Word 测试及源码快照完整性检查，然后用现有合成输入创建两个项目和三个分析批次，
显式启用报告。二分类项目嵌入该批次已有的 balance 图；连续结局报告不声明图件。

```text
project/SYNTHETIC_BINARY/runs/run_001/report/analysis_report.docx
project/SYNTHETIC_BINARY/runs/run_002/output/
project/SYNTHETIC_CONTINUOUS/runs/run_001/report/analysis_report.docx
```

报告为 Methods—Results—Next Steps，表格可编辑，默认用户交付只有 DOCX。
`.local/smoke/` 保存本机测试日志。旧兼容 Quick Start 仍写入 `examples/quick_start/output/`；
新项目入口的分析与报告全部位于各自 `project/<id>/runs/<run_id>/`。
合成演示拒绝覆盖已有同名项目。初次完成后，重跑检查可用 smoke 的 `-SkipProjectDemo`；
不要删除或覆盖已有批次来制造一次“新”测试。

如果只重现报告而不重拟合统计模型，使用已经完成的合成运行：

```powershell
.\.venv\Scripts\python.exe runtime/project_workspace.py report SYNTHETIC_BINARY --run-id run_001 --enable
```

本分支已包含 Word 模块，**无需额外 worktree、PR 下载或 `--reporting-library`**。
不加 `--enable` 不生成报告。配置变化或作者修改受保护；更正需明确新 `--report-version`。
独立报告入口也保持可用，读取公开的既有聚合 fixture，不执行 R：

```powershell
.\.venv\Scripts\python.exe runtime/render_report.py --config examples/word_reporting/report_config.json --enable --output project/SYNTHETIC_CONTINUOUS/runs/run_001/report/fixture_report.docx --internal-dir project/SYNTHETIC_CONTINUOUS/runs/run_001/internal/fixture_report
```

新研究先初始化项目；未完成的模板不是研究者已批准的方案：

```powershell
.\.venv\Scripts\python.exe runtime/project_workspace.py init T08
```

把已准备的私有输入及确认配置放入该项目后，按方案指定获准 Profile、执行模式及批次。
使用说明见 [项目工作空间](project_workspace.md)。不自动复制 JM1021、T08 的历史资料。

## 独立保留的 CCW 分支及缺口

获取原 PR #4 的准确版本，不改变 main 或当前集成分支：

```powershell
git fetch origin feature/ccw-production-validation
git worktree add --detach ../tte-ccw-authority b595a938c88e535b0cb12e56dfc0558b309b8c61
```

该分支只有早期 Authority/验证准备，不能据分支名推断已有 CCW 执行器。
本次隔离源码快照保全了后来未提交的实现；其封存依赖含科学批准、原始来源与执行身份，
不能当作普通安装配置重写或替换。未上传的内部记录/生成数据尚需另行判断共享及采用范围，
因此 **CCW 后续开发工作流的独立复现仍未完成**。快照仅做语法和字节完整性检查，
不以历史 AI 报告中的检查数量宣称本次运行了 CCW。它不会被 production 加载或运行。

## 验证声明

`LOCAL_CLEAN_CLONE_VALIDATION` 指当前电脑只从已推送的 GitHub 分支全新克隆，
再按上述环境和合成命令检查；原工作区的未提交代码不参与该克隆验收。
`SECOND_PC_VALIDATION` 只有在另一台电脑实际执行后才能改变，当前为 **PENDING**。
CI、当前电脑干净克隆、另一台 Windows 和真实临床研究是不同验证范围。
报告外用前仍需检查实际渲染、科学内容及作者采用；软件同步不授予投稿或发布许可。
