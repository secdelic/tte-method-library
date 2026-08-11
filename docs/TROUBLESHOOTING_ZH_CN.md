# Target Trial Emulation Statistical Analysis Method Library v1.0.0 故障排查表

> 适用版本：`1.0.0` / `v1.0.0` / `998e3c0a83656eae5e3ee8dae909e2edcd2625ec`。
>
> 排查原则：先保留错误原文、当前目录、R 版本、`.libPaths()`、包版本、输入/config hash 和输出日志，再做最小修复。不要先升级全部包、改统计源码、放宽阈值或改 expected values。

## 1. 环境与安装

| 问题/表现 | 可能原因 | 检查 | 正确处理 | 禁止处理 |
|---|---|---|---|---|
| `Rscript` 找不到；PowerShell 提示“无法将 Rscript 识别为…” | R 未安装，或 R `bin` 未加入 PATH | `Get-Command Rscript -ErrorAction SilentlyContinue`；检查实际安装目录 | 安装 R 4.5.1；重新打开 PowerShell；或用 `& "<实际R目录>\bin\Rscript.exe" --version` | 不要随便下载未知来源的 `Rscript.exe`；不要把示例中的 D 盘路径当成所有电脑固定路径 |
| 输入 `R` 后执行了 PowerShell 历史命令 | PowerShell 内置 alias `R` 通常指向 `Invoke-History` | `Get-Command R`；`Get-Alias R -ErrorAction SilentlyContinue`；`Get-Command Rscript` | 用 `Rscript`；交互式 R 使用完整 `R.exe` 路径 | 不要以 `R` 命令是否工作判断 R 是否安装 |
| R 版本不是 4.5.1 | PATH 指向另一 R 版本 | `Rscript --version`；`Get-Command Rscript | Format-List Source` | 调整 PATH，或在项目命令中显式使用 R 4.5.1 的 `Rscript.exe` | 不要在未验证数值回归的情况下用其他 R 版本做正式分析 |
| `renv::restore()` 找不到 `renv` | 首次部署尚未安装 bootstrap `renv` | `Rscript -e "requireNamespace('renv', quietly=TRUE)"` | 在 R 4.5.1 中执行 `install.packages("renv")`，然后 `renv::restore(prompt=FALSE)`；restore 后核对锁定版 `renv 1.2.2` | 不要删除 `renv.lock`；不要用整套最新版依赖代替 lockfile |
| `renv::restore()` 下载失败 | 网络、代理、CRAN 镜像、系统依赖或临时服务问题 | 保留 restore 完整日志；检查 `getOption("repos")`；确认网络；Linux 查看 CI 中系统依赖 | 修复网络/代理/系统依赖后重试同一 lockfile；必要时更换可信 CRAN 镜像并记录 | 不要修改 lockfile 版本来“消除”下载错误；不要复制来源不明的 package library |
| restore 后 `.libPaths()` 仍只有 user/system library | v1.0.0 的 `.Rprofile` 仅在 `renv/activate.R` 存在时激活；固定仓库没有该文件 | `Rscript -e ".libPaths()"`；`Test-Path .\renv\activate.R`；`Rscript -e "renv::status()"` | 显式在仓库根运行 `renv::restore(project='.', prompt=FALSE)`；按 renv 的项目使用方式启动 R，并再次核对包版本。若部署策略未自动激活，应由项目管理员记录明确的项目库启动命令 | 不要在手册或项目中假设不存在的 `renv/activate.R` 已存在；不要静默使用全局不同版本包 |
| `Package 'WeightIt' is required` | WeightIt 未安装在当前 `.libPaths()`，或项目库未激活 | `Rscript -e ".libPaths(); requireNamespace('WeightIt', quietly=TRUE); if(requireNamespace('WeightIt',quietly=TRUE)) packageVersion('WeightIt')"` | 优先 `renv::restore(packages="WeightIt", prompt=FALSE)`；预期锁定版本 `1.7.0`；随后运行 Quick Start/数值回归 | 不要立即 `install.packages("WeightIt")` 获取最新版后直接做正式分析；不要把包检查从源码删掉 |
| package 版本不一致 | 使用了 user/system library 或 lockfile 未完整恢复 | `Rscript -e "packageVersion('WeightIt'); packageVersion('mice'); packageVersion('cobalt'); packageVersion('ggplot2')"`；`renv::status()` | 以 `renv.lock` 为准恢复；关键版本见快速参考；保留修复前后日志 | 不要运行无条件 `update.packages()`；不要改 `renv.lock` 迎合当前 library |
| Quick Start 提示 `Run this script from the repository root` | 当前目录不含 `runtime/load_library.R` | `Get-Location`；`Test-Path .\runtime\load_library.R` | `Set-Location` 到克隆仓库根后再运行 | 不要修改脚本中的 root check |

## 2. 版本与仓库

| 问题/表现 | 可能原因 | 检查 | 正确处理 | 禁止处理 |
|---|---|---|---|---|
| `git checkout v1.0.0` 失败 | tag 未 fetch、仓库不是正式仓库或网络/clone 不完整 | `git remote -v`；`git tag --list v1.0.0`；`git status` | 确认 origin 为公开仓库；安全地 fetch tags 后重试；仍失败则重新 clone 到新目录 | 不要自行创建名为 `v1.0.0` 的本地 tag |
| `git rev-parse HEAD` 不是指定 SHA | checkout 到 main/其他 commit，或 tag 被错误替代 | `git describe --tags --exact-match HEAD`；`git rev-parse HEAD` | 停止正式分析，切换到真实 `v1.0.0`；预期 SHA 为 `998e3c0a...` | 不要继续声称结果来自 v1.0.0；不要移动 tag |
| checkout 后工作区有修改 | 用户文件、输出或源码被改动 | `git status --short`；`git diff -- <file>` | 保留用户修改；为正式分析另建干净 clone/工作区。患者数据和 output 应在研究项目外 | 不要 `git reset --hard` 清除未知修改；不要把改过的源码仍称 v1.0.0 |

## 3. 配置与输入合同

| 问题/表现 | 可能原因 | 检查 | 正确处理 | 禁止处理 |
|---|---|---|---|---|
| `Invalid execution mode` | 使用了不存在的 `FORMAL_ANALYSIS` 等字符串 | 检查调用中的 `execution_mode` | 只能使用 `SYNTHETIC_TEST`、`CANARY`、`FORMAL_CANDIDATE`；正式候选使用最后一项并执行人工 gate | 不要改源码增加未经验证的模式；不要把 `SYNTHETIC_TEST` 当正式结果 |
| `Scientific fields are not frozen` | `scientific_fields_frozen` 不是 `true` | 打开 `analysis_spec.yml`；运行合同验证 | 完成科学审核后由责任人把字段设为 `true`，记录批准者与日期 | 不要为了通过验证而在科学定义未完成时改成 `true` |
| `Unresolved researcher-supplied scientific fields` | population/time zero/treatment/outcome/estimand 仍是 `<USER_DEFINED>` 或空 | 检查错误列出的字段；对照配置字典 | 由研究者补齐并批准这些科学定义 | 不要让软件根据数据或结果自动填充 |
| `Profile is absent from analysis specification` | `profile` 不一致，或多分析文件没有对应 key | 比较运行调用、单分析 `profile`、多分析 `analyses:` key | 使用精确名称 `BASELINE_BINARY_RISK` 或 `MI_PS_CONTINUOUS_ATE`，保持三处一致 | 不要用近似拼写；不要把开发模块名当生产 profile |
| `Profile is not production-approved` | profile 不在注册表或 `production_allowed` 不是 TRUE | `Import-Csv .\runtime\production_registry.csv` | 仅用两个批准 profile；如研究需要其他模块，停止并建立独立验证计划 | 不要因存在函数/目录就绕过注册表 |
| analysis spec validation 失败 | 缺必需块、关键字段未解析、结果驱动修改为 true | 查 `diagnostics/contract_validation.csv`；对照 `CONFIG_REFERENCE_ZH_CN.md` | 最小修复配置结构；科学字段需研究者确认 | 不要删除验证器或降低合同要求 |
| variable dictionary role conflict / `role_alignment_*` 失败 | analysis spec 与字典 role 不一致 | 查 `contract_validation.csv`；按变量名比较 `role` | 由研究者确认真实 role 后统一两处；保留决策日志 | 不要根据哪个 role 更容易 PASS 来选择；软件不能判定 confounder/mediator/collider |
| `Variable dictionary is missing columns` | CSV 表头不完整或被 Excel 改名 | `Import-Csv .\config\variable_dictionary.csv | Get-Member -MemberType NoteProperty` | 从固定模板复制 17 个列名，保留 UTF-8 CSV | 不要发明替代列名；不要删除空但必需的列 |
| `declared_variables_present_in_data` 失败 / `missing columns:` | 字典列名与数据表头不一致 | `Rscript -e "names(read.csv('input/private/analysis_data.csv', check.names=FALSE))"` | 修正数据导出或字典中的真实变量名；重新冻结 SHA | 不要让 `check.names=TRUE` 静默改列名；不要删除研究需要的变量只为通过 |
| duplicate ID：`subject_id must be nonmissing and unique` 或 `analysis_id...` | 分析单位错误、重复记录或缺失 ID | R：`anyNA(d$subject_id)`、`anyDuplicated(d$subject_id)`、同查 `analysis_id`；同时核对患者/住院/ICU stay 级别 | 回到数据构建流程查明重复来源，生成符合一行一个分析单位的冻结数据 | 不要简单 `distinct()`/删除重复行而不解释；不要改运行器唯一性规则 |
| binary coding 错误：`treatment must be nonmissing binary 0/1` | treatment 含 NA、1/2、字符或其他水平 | `table(d$treatment, useNA="ifany")`；`str(d$treatment)` | 在外部数据准备流程按冻结定义映射为整数 0/1，核对 reference，更新 manifest/hash | 不要在模型运行中临时猜测编码；不要颠倒 reference 追求结果 |
| baseline outcome 错误 | outcome 非 0/1、缺失或 spec type 不是 binary | `table(d$outcome, useNA="ifany")`；检查 `outcome.type` | 按冻结 outcome 定义修复 analysis-ready 数据 | 不要插补基线 profile 的 outcome；不要改 profile 逃避数据问题 |
| MI outcome 错误 | outcome 有缺失或不是 numeric continuous | `summary(d$outcome)`；`is.numeric(d$outcome)`；`anyNA(d$outcome)` | 外部修复类型；按预设规则处理缺失。当前 MI profile 不插补 outcome | 不要把 outcome 强制转 numeric 而不检查 factor 编码；不要在此 profile 插补 outcome |
| `missingness outside audited PMM numeric covariates` | 缺失变量未批准插补、不是 numeric/double 或 `mice_method` 非 pmm | 列出 `colSums(is.na(d))`；查字典 `impute`、`mice_method`、`type` | 依据预设策略修正字典或数据；所有科学改变须重新批准 | 不要因结果更好临时开启插补；不要选择“最佳”插补集 |
| 时间解析失败：`all time fields must parse as ISO 8601 with timezone` | 格式或时区缺失 | 查看五个固定时间列；用 `as.POSIXct(..., format="%Y-%m-%dT%H:%M:%SZ", tz="UTC")`试解析 | 在数据准备阶段统一为含时区的 ISO-8601，如 `2026-01-01T00:00:00Z` | 不要让系统本地时区隐式解释；不要删时间字段 |
| time ordering 错误 | eligibility/treatment/follow-up start 未对齐 time zero，或 end 不晚于 start | 查 `structure_audit.csv`；逐行比较五个时间列 | 回到队列构建规则修复；重新冻结数据与 SHA | 不要在 R 中无依据地把时间列直接复制为 time zero |
| absolute path 被拒绝 | `input_data_contract.csv` 的 `relative_path` 使用盘符绝对路径、Unix home 绝对路径或 `..` | `Import-Csv .\config\input_data_contract.csv | Select-Object relative_path` | 写项目相对路径 `input/private/analysis_data.csv`；运行调用的 `data_path` 可由包装脚本从研究项目根安全构造 | 不要关闭 path traversal/private 目录检查；不要把患者路径写进公开仓库 |
| SHA 不一致 | 输入在冻结后改变；或合同 SHA 尚未更新 | PowerShell：`(Get-FileHash -Algorithm SHA256 <file>).Hash`；比较合同 `sha256` 与 `diagnostics/input_manifest.csv` | 停止 formal candidate，查明变更，必要时重新冻结并重新 canary | 不要只更新 SHA 来掩盖未经批准的数据变化。注意 v1.0.0 不会自动把合同 SHA 与实际文件比较，必须人工比对 |

## 4. 模型与诊断

| 问题/表现 | 可能原因 | 检查 | 允许的处理 | 禁止处理 |
|---|---|---|---|---|
| `Package 'cobalt' is required` / `mice` / `ggplot2` / `yaml` / `digest` | 当前 library 未恢复 | `.libPaths()`；`requireNamespace()`；`packageVersion()` | 用 `renv::restore(packages="<包名>", prompt=FALSE)`恢复锁定版，然后重跑 Quick Start/数值回归 | 不要删除 package check；不要混用任意最新版 |
| propensity model/WeightIt 报错或不收敛 | 完全/近完全分离、变量无变异、稀疏水平、数据类型或模型不当 | 保存原错误；检查 treatment 分布、协变量分布、公式、缺失；查看 `logs/warnings.csv` | 由统计人员按预设计划审查数据和模型。若科学方案需改动，记录新版本并重新 canary | 不要静默删变量、合并水平或改 estimand；不要结果驱动试遍模型 |
| SMD 不达标 / `balance threshold failed` | PS 模型未达到预设平衡、重叠不足、编码或变量定义问题 | `diagnostics/balance.csv`；最大 `abs(adjusted_smd)`；比较加权前后；检查关键协变量 | 作为分析问题提交人工统计审查；按预设替代方案或经批准的新方案处理并重新运行 | 不要把 `max_abs_smd` 放宽到刚好 PASS；不要自动加删协变量；0.10 不是普遍真理但本次阈值必须预设 |
| ESS 过低 / `total ESS threshold failed` | 极端/不稳定权重、重叠不足 | `diagnostics/weight_summary.csv` 的 total/group ESS、max weight；比较原始 n | 审查 positivity、PS 分布和策略可识别性；若预设有截断敏感性则执行并报告 | 不要把原始样本量当 ESS；不要只降低 `min_total_ess` |
| extreme weights | PS 接近 0/1、模型不稳定、稀疏数据 | `max_weight`/`maximum_weight`；必要时用 `plot_weight_distribution()`对已验证汇总作图 | 报告分布；执行预设截断敏感性；由统计人员判断主分析是否可解释 | 不要未预设就截断并把更有利结果当主分析；不要删除高权重个体 |
| positivity 问题 / `positivity threshold failed` | treatment groups 缺乏 support、设计或变量定义问题 | `positivity_violation_rate`；PS min/max；按组画 PS distribution | 返回科学/设计审查；如仍分析，明确限制和预设敏感性 | 不要把 bounds 或 violation rate 改到 PASS；不要做自动因果解释 |
| MI gate 报 `MICE logged events require review` | MICE 检测到共线、常数、预测问题等事件 | 检查返回对象（私有 `internal`/运行对象）和 `logs/warnings.csv`；记录 `mice_logged_events` | 由统计人员审阅事件；修复须保持缺失策略和变量选择的审计链 | 不要忽略 logged events；不要挑一个看起来正常的插补集 |
| complete-case sensitivity 未生成 | complete cases 少于 30 | 计算 `sum(complete.cases(d[c('outcome','treatment',covariates)]))` | 报告该预设敏感性无法执行及原因 | 不要降低源码中的 30 行条件；不要伪造空表或结果 |

## 5. 输出、图形与 release

| 问题/表现 | 可能原因 | 检查 | 正确处理 | 禁止处理 |
|---|---|---|---|---|
| 输出目录为空或不完整 | 运行提前失败、路径权限、当前目录错误 | 查看控制台错误；检查 `diagnostics/structure_audit.csv`、`logs/warnings.csv`；`Get-ChildItem output -Recurse` | 修复首个阻断错误后在新的输出目录重跑，保留失败日志 | 不要手工拼接“成功”输出；不要覆盖正式结果而无版本记录 |
| figure clipping/overlap | 标签过长、图高不足、字体/设备差异 | 打开实际 PDF/SVG 和 600-DPI TIFF/PNG，在目标版面尺寸检查；看 `figure_qc.csv` | 调整经批准的图高、标签或期刊配置，重新导出；重新人工 QC | 不要手工把 `publication_ready` 改 TRUE；不要只看缩略图 |
| 600 DPI 输出问题 | config dpi <600、文件格式/查看器误报、导出失败 | `figure_config.yml`；`figure_qc.csv`；检查 PNG/TIFF 像素与物理尺寸 | 保持 `raster_dpi >= 600`；重导出；同时保留 vector 文件 | 不要把屏幕截图当正式 raster；不要只改元数据标签而不重新渲染 |
| `One or more figures lack completed machine and human approval` | 初始状态本来就是 pending；或任一人工项 FAIL/缺 reviewer/date | 查看 `figure_qc.csv` 的 `machine_checks_pass`、`clipping`、`overlap`、`grayscale_pass`、`manual_review`、reviewer/date | 真实人工检查后调用 `record_figure_manual_review()`；全部 PASS 才能 `assert_publication_figures_ready()` | 不要自动批准；不要使用虚构 reviewer；不要把机器 PASS 当视觉批准 |
| 重新生成图后批准消失 | v1.0.0 有意使再生成失效旧批准 | 比较文件时间/hash 与 QC；查看 `manual_review=PENDING` | 对新文件重新做完整人工视觉检查 | 不要恢复旧 QC 行套用到新图 |
| Formal Candidate 的 `diagnostic_gate_pass=FALSE` | 任一 balance、ESS、positivity、MI event、warning 或独立数值检查失败 | `diagnostics/diagnostic_gate.csv` 与 `stopping_reasons` | 停止 release；解决科学/数据问题或记录无法完成 | 不要继续把表图当正式结果；不要只因文件已生成就视为 PASS |
| Formal release gate 失败/不完整 | 缺 `diagnostics`、`tables`、`figures`、`sensitivity` 目录或四个 config 文件；destination 已存在 | 检查 `tte_build_analysis_release()`错误；检查所需目录/文件 | 使用新的不存在 destination；先确认 gate 和人工图审查，再构建 aggregate release | 不要覆盖旧 release；不要把 patient data、`internal/`、manuscript 或 reviewer 文件拷入 |
| release 包已生成但科学批准未完成 | v1.0.0 的 `tte_build_analysis_release()`检查文件结构和禁入资产，但**不会自动核验** diagnostic gate 或 figure human approval | 在调用前显式检查 `result$gate$diagnostic_gate_pass`；运行 `assert_publication_figures_ready()`；人工检查 config/input hash | 把这些检查写进项目 SOP/包装脚本；未通过时删除候选资格并保留审计记录 | 不要把“构建函数成功”当作正式科学 release；不要声称代码授予科学批准 |
| release 缺 logs/package_versions | 构建器有意只复制 config snapshot、diagnostics、tables、figures、sensitivity 与 metadata | 查看 release manifest；原 output 的 `logs/package_versions.csv` | 以 `metadata/session_info.txt`和外部项目 execution log 保留环境；如项目需额外审计附件，须在 release 外由人工批准处理 | 不要修改 v1.0.0 release builder；不要把 `output/internal/analysis_internal.rds`放入提交包 |

## 6. 最小诊断命令集

在仓库根执行：

```powershell
git status --short
git describe --tags --exact-match HEAD
git rev-parse HEAD
Rscript --version
Get-Command R
Get-Command Rscript
Rscript -e ".libPaths()"
Rscript -e "packageVersion('WeightIt'); packageVersion('mice'); packageVersion('cobalt'); packageVersion('ggplot2')"
Rscript examples\quick_start\run_quick_start.R
Rscript validation\run_public_numerical_regression.R
```

如命令失败，记录：命令、完整错误、退出码、时间、当前目录、Git SHA、R 与包版本、输入/config SHA、已产生文件。当前无法验证的内容应明确写成：**“当前无法验证，需要进一步数据或运行结果。”**

另见：[完整中文使用说明书](USER_GUIDE_ZH_CN.md)、[中文快速参考](TTE_METHOD_LIBRARY_QUICK_REFERENCE_ZH_CN.md)、[配置字段字典](CONFIG_REFERENCE_ZH_CN.md)。
