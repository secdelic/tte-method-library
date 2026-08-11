# Target Trial Emulation Statistical Analysis Method Library v1.0.0 中文正式使用说明书

版本：`1.0.0`<br>
Git tag：`v1.0.0`<br>
Commit：`998e3c0a83656eae5e3ee8dae909e2edcd2625ec`<br>
Version DOI：[`10.5281/zenodo.21879884`](https://doi.org/10.5281/zenodo.21879884)<br>
公开仓库：[`https://github.com/secdelic/tte-method-library`](https://github.com/secdelic/tte-method-library)<br>
License：MIT<br>
本手册任务：`TTE_METHOD_LIBRARY_V1_0_0_CHINESE_USER_MANUAL_V1`

## 科学职责边界（必须先读）

本方法库负责在研究者已经冻结科学方案、准备好 analysis-ready 数据之后，执行和验证下列工作：

- 输入数据结构验证；
- analysis specification 验证；
- variable dictionary 验证；
- 已批准路径的缺失数据执行；
- propensity-score weighting；
- balance diagnostics；
- production-approved TTE estimators；
- effect estimation；
- 预设 sensitivity analysis；
- publication tables；
- publication figures；
- reproducibility metadata；
- aggregate formal analysis release 的构建。

本方法库不负责：

- SQL、数据库连接或数据库提取；
- 研究问题设计、DAG 设计或因果识别策略；
- 自动判断 confounder、mediator 或 collider；
- 自动定义 treatment、outcome、time zero、grace period 或 follow-up；
- 自动选择 estimand；
- 根据结果修改模型、阈值或分析计划；
- 自动因果解释或临床建议；
- 论文 Methods、Results、Discussion 写作；
- 投稿或自动批准发布。

> **必须：科学方案由研究者预先制定并冻结，方法库只负责执行和验证，不会根据分析结果自动改变研究方案。**

方法库的结构或数值检查通过，不等于研究设计正确，不等于无未测量混杂，也不等于论文结论成立。所有科学判断和最终 release 决定必须由研究者与统计人员完成。

相关文档：[快速参考](TTE_METHOD_LIBRARY_QUICK_REFERENCE_ZH_CN.md) · [故障排查](TROUBLESHOOTING_ZH_CN.md) · [配置字段字典](CONFIG_REFERENCE_ZH_CN.md) · [中文文档导航](zh_CN/README.md)

## 1. 方法库简介

`Target Trial Emulation Statistical Analysis Method Library` 是一个面向研究者已指定目标试验模拟（target trial emulation, TTE）及相关因果推断分析的统计执行库。它不是 CRAN R package；`DESCRIPTION` 明确其为 governed software project。使用时从 `runtime/load_library.R` source 项目内函数。

设计理念是：

1. 研究设计与统计执行分离；
2. 科学字段先冻结，代码后执行；
3. production profile 由注册表控制；
4. 输入、配置、版本、依赖和输出保留 hash/metadata；
5. 自动检查失败时停止正式 release，而不是自动“修正”科学方案；
6. 机器图形 QC 后仍保留人工视觉批准。

适用对象包括 ICU/临床数据库研究人员、医学统计人员、使用 MIMIC/eICU 等数据但已在外部完成提取的研究者，以及有基础 R 经验、需要可重复执行固定 TTE 方案的团队。

适用前提：研究者已经确定 cohort、treatment、outcome、time zero、follow-up、baseline confounders、estimand、missing-data strategy 和 sensitivity plan，并已生成满足 v1.0.0 合同的 CSV。

不适用情形包括：需要软件替代研究设计；需要从数据库直接提取；需要未批准的 longitudinal/CCW/LMTP 等主分析；需要自动模型搜索；需要自动撰写或提交论文。

## 方法库当前可正式使用的范围

生产资格只看 `runtime/production_registry.csv`：

| Profile | Production | Estimand | Outcome | Missing data | Variance | 正式范围摘要 |
|---|---|---|---|---|---|---|
| `BASELINE_BINARY_RISK` | TRUE | ATE | binary | none | `fixed_weight_influence_curve` | baseline TTE、PS weighting、weighted risks、RD/RR、SMD、ESS、SE、95% CI |
| `MI_PS_CONTINUOUS_ATE` | TRUE | ATE | continuous | mice | `weightit_m_estimation_plus_rubin` | PMM、within-imputation weighting/M-estimation、Rubin + Barnard-Rubin、pooled ATE/SE/95% CI |

模块成熟度：

| 模块 | v1.0.0 readiness | 正式主分析 |
|---|---|---|
| CCW | Development / synthetic validation | 不批准 |
| LMTP | Development / selected validation | 不批准 |
| Longitudinal TTE | Synthetic prototype | 不批准 |
| PATH | Development | 不批准 |
| Three-timepoint TTE | Synthetic prototype | 不批准 |
| Multilevel propensity score | Development | 不批准 |

> `AVAILABLE IN LIBRARY != PRODUCTION-APPROVED`。目录、函数、示意图或 dependency 的存在，不能替代 production registry 与独立验证。

## 2. 核心运行逻辑

```text
研究者/GPT协助冻结科学方案
        ↓
准备 analysis-ready 数据（数据库提取在方法库外）
        ↓
analysis_spec.yml
        +
variable_dictionary.csv
        +
input_data_contract.csv
        +
figure_config.yml
        ↓
合同、结构与时间顺序验证
        ↓
Diagnostic Canary（execution_mode="CANARY"）
        ↓
人工确认 scientific / statistical / privacy / visual gates
        ↓
Formal Candidate（execution_mode="FORMAL_CANDIDATE"）
        ↓
预设 Sensitivity Analysis
        ↓
Tables + Figures + 人工视觉批准
        ↓
Aggregate Formal Analysis Release
        ↓
交给独立写作工作流
```

每一步的作用：

- **冻结科学方案：** 防止看到结果后改变定义或模型。
- **analysis-ready 数据：** 把数据库结构转为 estimator 所需的一行一个分析单位的固定 CSV；本库不做 SQL。
- **四件套配置：** 分别记录科学规格、变量角色、输入合同和图形合同。
- **结构验证：** 检查必需字段、角色对齐、ID、二元编码、时间顺序、缺失路径等。
- **Canary：** 以冻结候选输入检查执行性、收敛、权重、balance、ESS、positivity、输出合同；仍是 audit-only。
- **人工确认：** 研究者/统计人员审查诊断和方案；软件从不设置 `scientific_approval_granted_by_code=TRUE`。
- **Formal Candidate：** 对最终冻结输入和配置重新执行；v1.0.0 没有字面名为 `FORMAL_ANALYSIS` 的 execution mode。
- **Sensitivity：** 只执行 profile 实现中的预设路径。
- **表图：** 输出 aggregate 表和多格式图；图必须人工视觉审核。
- **Release：** 构建不含患者数据和内部 R 对象的 aggregate 包；构建成功本身不等于科学批准。
- **写作：** 在本方法库之外进行，并保持 Results/Table/Figure 一致。

## 3. 系统要求

### 3.1 已固定或已验证的环境

- R：`4.5.1`（来自 `renv.lock` 和 GitHub Actions）。
- Git：用于 clone、checkout tag 和验证 commit；仓库未声明最低 Git 版本。
- `renv`：lockfile 固定 `1.2.2`。
- Windows：本手册重点平台；本轮在 Windows + R 4.5.1 的干净 `HEAD` 导出副本实际执行通过。
- Linux：GitHub Actions 使用 Ubuntu runner、R 4.5.1、setup-renv，执行 parse、tests、Quick Start、数值验证、文档/metadata/privacy/release dry run。
- macOS：原则上使用相同 R/tag/lockfile 流程；固定仓库没有 macOS CI 证据，因此真实项目在 macOS 上必须自行运行 Quick Start、数值回归和项目 Canary 后才能使用。

### 3.2 磁盘与网络

v1.0.0 没有声明硬性的最小磁盘空间。代码仓库本身较小，但 R、149 个 lockfile package、编译缓存、项目私有输入、多格式 600-DPI 图和版本化输出会占用额外空间。**建议**在部署前分别检查系统盘、R library/cache 盘和研究项目盘；不要把一个未经验证的固定容量写成软件保证。

依赖恢复通常需要访问 CRAN，Linux 还可能需要 CI 所列系统库。正式统计运行本身读取本地 CSV/config，不连接数据库、不执行 SQL，也不应向外部网络发请求。患者数据不得通过依赖安装或运行步骤上传。

## 4. Windows 安装指南

### 4.1 Git 检查

```powershell
git --version
Get-Command git
```

能输出版本与实际路径后再 clone。

### 4.2 R 检查

优先使用：

```powershell
Rscript --version
Get-Command Rscript
```

**注意：** PowerShell 常把 `R` 解析为 `Invoke-History` alias：

```powershell
Get-Command R
Get-Command Rscript
```

因此不要用下面命令是否工作来判断 R 安装：

```powershell
R
```

如 PATH 未配置，可使用实际安装路径：

```powershell
& "<R-4.5.1实际安装目录>\bin\Rscript.exe" --version
```

例如某台电脑可能安装在 D 盘，但这不是所有用户的固定路径。必须先查明本机路径。

## 5. 获取固定 v1.0.0

```powershell
git clone https://github.com/secdelic/tte-method-library.git
Set-Location .\tte-method-library
git checkout v1.0.0
git rev-parse HEAD
git describe --tags --exact-match HEAD
```

预期 HEAD：

```text
998e3c0a83656eae5e3ee8dae909e2edcd2625ec
```

预期 tag：`v1.0.0`。该 tag 是 annotated tag，解引用后指向上述 commit。

论文分析不要直接使用不断变化的 `main`。`main` 可能在将来增加文档、修复或功能；如果不同研究者在不同日期 clone `main`，不能保证得到相同代码。固定 tag + commit + version DOI 才能明确软件版本。

若 `git status --short` 显示源码被修改，不要直接清除未知改动。为正式分析新建干净 clone，并把研究输入保留在独立私有项目中。

## 6. R 环境恢复

`renv.lock` 是项目依赖的冻结清单，记录 R 版本、package 来源和版本。它的目的是让不同电脑恢复同一依赖组合，而不是让每台电脑使用“当前最新版”。

在仓库根启动 R 4.5.1：

```r
install.packages("renv")
renv::restore(project = ".", prompt = FALSE)
```

然后检查：

```r
.libPaths()
renv::status()
packageVersion("renv")
packageVersion("WeightIt")
packageVersion("mice")
```

关键冻结版本：

| Package | 版本 |
|---|---:|
| renv | 1.2.2 |
| WeightIt | 1.7.0 |
| mice | 3.19.0 |
| cobalt | 4.6.3 |
| ggplot2 | 4.0.3 |
| yaml | 2.3.12 |
| digest | 0.6.39 |

### 6.1 project library 与 user library

- **project library：** 为本项目恢复的依赖集合，应与 lockfile 对齐。
- **user/system library：** R 的通用包目录，可能含不同版本。
- `.libPaths()` 决定本次 R 会在哪里找包；第一个路径通常最优先。

固定 v1.0.0 有 `.Rprofile`，但其逻辑只有在 `renv/activate.R` 存在时才 source。tag 中没有 `renv/activate.R`，所以不能假设 clone 后自动激活。必须显式 restore、检查 `.libPaths()` 和实际 package version。若团队采用自定义 `R_LIBS_USER` 或 renv root，应写入项目 execution log，并在新电脑上重跑数值回归。

## 7. 常见包缺失处理

若出现：

```text
Package 'WeightIt' is required
```

先运行：

```r
.libPaths()
requireNamespace("WeightIt", quietly = TRUE)
packageVersion("WeightIt")
```

优先恢复 lockfile 中单个包：

```r
renv::restore(project = ".", packages = "WeightIt", prompt = FALSE)
```

预期版本为 `1.7.0`。同理可对 `mice`、`cobalt`、`ggplot2`、`yaml`、`digest`执行单包 restore。

**不要**先执行无条件 `update.packages()`或安装所有最新版。包能加载不等于版本正确；版本漂移后必须先恢复，再执行 Quick Start 与 numerical regression。

## 8. Quick Start

Quick Start 使用固定 seed 的合成数据，执行 `BASELINE_BINARY_RISK` 的 `SYNTHETIC_TEST`。它不使用患者数据、不连接数据库、不联网。

从仓库根运行：

```powershell
Rscript examples\quick_start\run_quick_start.R
```

PATH 有问题时：

```powershell
& "<R-4.5.1实际安装目录>\bin\Rscript.exe" `
  "examples\quick_start\run_quick_start.R"
```

初学者建议先用单行命令。PowerShell 换行符是行尾反引号 `` ` ``，不是反斜杠加反引号。

成功消息：

```text
Synthetic production Quick Start PASS
```

实际 v1.0.0 成功运行会在 `examples/quick_start/output/`产生下列主要文件：

```text
diagnostics/
  balance.csv
  contract_validation.csv
  diagnostic_gate.csv
  independent_validation.csv
  input_manifest.csv
  structure_audit.csv
  weight_summary.csv
tables/
  primary_effects.csv
  primary_effects.html
  table1.csv
  table1.html
figures/
  covariate_balance.{pdf,svg,tiff,png}
  primary_effect_difference.{pdf,svg,tiff,png}
  primary_effect_ratio.{pdf,svg,tiff,png}
  figure_qc.csv
sensitivity/
  sensitivity_results.csv
internal/
  analysis_internal.rds
logs/
  package_versions.csv
  warnings.csv
```

本轮在固定 `HEAD` 的临时干净副本实际得到 `28` 个文件。Quick Start PASS 只证明合成基线路径在当前环境可执行，不证明某个真实研究的设计或数据可用。

## 9. 正式研究项目不要放在方法库目录

推荐分离：

```text
ResearchProject/
├─ input/
│  └─ private/
├─ config/
│  ├─ analysis_spec.yml
│  ├─ variable_dictionary.csv
│  ├─ input_data_contract.csv
│  └─ figure_config.yml
├─ runtime/
│  └─ run_project.R
├─ output/
│  ├─ diagnostics/
│  ├─ tables/
│  ├─ figures/
│  ├─ sensitivity/
│  ├─ internal/
│  └─ logs/
└─ project_metadata/
```

方法库是 **immutable analysis engine**；研究项目是 **project-specific execution workspace**。患者 CSV、内部 R 对象、研究审批和项目 secret 不得放入 GitHub 方法库。

研究项目外部调用示例：

```r
library_root <- normalizePath("<固定v1.0.0方法库目录>", mustWork = TRUE)
research_root <- normalizePath("<私有ResearchProject目录>", mustWork = TRUE)

source(file.path(library_root, "runtime", "load_library.R"))
tte_source_library(library_root)

result <- tte_run_analysis(
  profile = "BASELINE_BINARY_RISK",
  data_path = file.path(research_root, "input", "private", "analysis_data.csv"),
  config_dir = file.path(research_root, "config"),
  output_dir = file.path(research_root, "output", "canary_001"),
  execution_mode = "CANARY",
  project_root = library_root
)

if (!isTRUE(result$gate$diagnostic_gate_pass)) {
  stop(result$gate$stopping_reasons)
}
```

`input_data_contract.csv` 中仍使用以研究项目为基准的 `input/private/...`相对路径；不要写公开仓库中的患者绝对路径。

## 10. `analysis_spec.yml` 完整讲解

完整逐字段表见[配置字段字典](CONFIG_REFERENCE_ZH_CN.md)。每个字段都应按以下六问审核：

1. **它是什么：** 研究设计、统计参数、治理状态还是运行阈值；
2. **谁决定：** 研究者、临床专家、统计人员或数据负责人；
3. **示例是什么：** 只使用与当前 profile 相容的值；
4. **常见错误是什么：** 占位符、时间泄漏、reference 错误、结果驱动修改；
5. **方法库检查什么：** 结构、部分字段解析、冻结状态、角色对齐和 profile-specific 输入；
6. **方法库不判断什么：** 科学合理性、因果识别和临床意义。

### 10.1 必须由研究者冻结的核心块

| 块 | 研究者必须明确 | v1.0.0 会做的检查 | 不会替你做的判断 |
|---|---|---|---|
| `design` | baseline 设计与分析人群 | 字段存在、输出记录 population | 设计能否识别目标因果效应 |
| `population` | ID、cluster、eligibility variables | role 对齐；固定 ID 唯一检查 | 该用患者、住院还是 stay 级 |
| `time_zero` | 变量与操作定义 | time 字典对齐；ISO 时间与对齐 | time zero 是否有临床偏倚 |
| `treatment` / `strategies` | 0/1 reference、两策略定义 | treatment 非缺失 0/1 | 自动定义治疗或宽限期 |
| `grace_period` | 是否存在、界值、单位 | 结构存在 | 自动启用 CCW；当前生产路径不执行宽限期 |
| `follow_up` | start/end/admin end/unit | start=time zero；end>start | 自动截断或定义 competing event |
| `outcome` | 变量、类型、时间窗、定义 | 与 profile 的 binary/continuous 要求一致 | 自动定义 outcome |
| `estimand` | ATE 与 effect measure | 两个注册 profile 均为 ATE | 根据结果选 ATE/ATT/ATO |
| `baseline_confounders` | 经 DAG/知识批准的变量 | 字典 role、time-zero 可用性 | confounder/mediator/collider 判定 |
| `time_varying_confounders` | 如有，预先声明 | role 对齐 | 使 baseline profile 变成 longitudinal profile |

### 10.2 执行与治理块

- `missing_data`：基线为 `none`；MI 为 `mice`，并冻结 `m`、`maxit`、seed。
- `weighting`：记录 method、estimand、PS 模型和 truncation；生产执行仍由 profile 固定。当前实现实际用字典批准 covariates 构造 PS 公式，必须人工与 `propensity_model` 字符串核对。
- `variance`：基线固定 fixed-weight influence-curve；MI 固定 WeightIt M-estimation + Rubin。`confidence_level`模板为 0.95，代码固定生成 95% CI。
- `sensitivity`：必须预设；列表不是任意调度器。基线截断由 `runtime_thresholds`开关执行，MI complete-case sensitivity 在可执行时生成。
- `figures`：记录 config 和 requested；正式 runtime 自动适配的是 balance 与主效应 forest 输出，其他图需合适的已验证 aggregate 输入。
- `governance`：记录 creator、approver、date、hash；`result_dependent_changes_allowed`必须为 `false`。
- `runtime_thresholds`：预设 positivity、SMD、ESS、group n 和 truncation gate；阈值不是普遍真理，但一旦冻结不能为了 PASS 结果驱动修改。

## 11. `variable_dictionary.csv` 完整讲解

正式模板的 17 个必需列是：

```text
variable,label,role,type,unit,reference,levels,measurement_time,
availability_time,relation_to_time_zero,missing_code,valid_min,valid_max,
impute,mice_method,include_in_model,notes
```

核心用法：

- `variable` 与实际 CSV 列名一致且唯一；
- `role` 只能使用批准枚举；
- `reference` 和 `levels` 由研究者明确，不依赖默认排序；
- `measurement_time` 是“何时测量”；`availability_time` 是“何时可被研究决策/模型获得”；
- `relation_to_time_zero` 对 baseline confounder 必须为 `before` 或 `at`；
- `impute=TRUE`、`mice_method=pmm` 只允许在 MI profile 经批准的 numeric/double PS covariates；
- `include_in_model=TRUE` 表示研究者批准纳入，不是软件自动筛选。

例：一个检验值在 time zero 前采血，但结果在治疗后返回。其 measurement time 在前，availability time 在后。即使数据库列看似“baseline”，也可能不应作为 time-zero 可用协变量。方法库不会自动识别这种临床时间关系。

**注意：** `valid_min`、`valid_max`、`missing_code`在模板中用于合同与审计，但 v1.0.0 不会替你完成所有范围检查或任意缺失编码转换。数据准备流程仍需执行 range/missingness audit。

## 12. `input_data_contract.csv`

12 个正式字段：`dataset_id`、`relative_path`、`format`、`analysis_unit`、`required`、`primary_key`、`time_structure`、`contains_patient_level_rows`、`expected_columns`、`sha256`、`approved_by`、`notes`。

必须满足：

- 当前只允许 CSV；
- 路径必须相对且位于 `input/private/`；
- 禁止绝对路径与 `..`；
- required 数据必须声明 primary key；
- 两个生产 profile 使用 baseline 一行一个分析单位；
- 实际输入必须有唯一、非缺失 `subject_id` 与 `analysis_id`；
- treatment 为非缺失 0/1；
- 五个固定时间字段满足顺序合同。

SHA-256 冻结示例：

```powershell
(Get-FileHash -Algorithm SHA256 ".\input\private\analysis_data.csv").Hash
```

**必须人工比对：** v1.0.0 会把实际 input SHA 写入 `diagnostics/input_manifest.csv`，但当前合同验证器不会自动比较 `input_data_contract.csv` 中填入的 SHA，也不会按 `expected_columns`逐项核对表头。正式候选前必须由项目 SOP 完成比较。

## 13. `figure_config.yml`

默认合同：单栏 85 mm、双栏 178 mm、默认高 110 mm、基础字体 8 pt、最小字体至少 7 pt、PDF/SVG vector、TIFF/PNG raster、至少 600 DPI、白底、colorblind-aware palette、shape/linetype redundancy、grayscale compatible、无 3D/装饰渐变/AI decoration。

**注意：** v1.0.0 exporter 会实际读取尺寸、格式、DPI、背景等字段；自动绘图函数则使用自身默认 base size/font 和内部固定 palette。修改 `typography`或 `palette.colors`不保证自动改变所有实际图形，必须检查调用路径和最终渲染，不能只看 YAML。

“vector”指 PDF/SVG 等可缩放图；“raster”指 TIFF/PNG 像素图。期刊尺寸不同可在查看结果前按官方指南修改并冻结，但必须保持 QC 规则。不要为强化观察到的效应而选择颜色、坐标或尺寸。

机器通过后，`figure_qc.csv` 仍为：

```text
clipping=PENDING_MANUAL_REVIEW
overlap=PENDING_MANUAL_REVIEW
grayscale_pass=PENDING_MANUAL_REVIEW
manual_review=PENDING
publication_ready=FALSE
```

人工真实检查后调用 `record_figure_manual_review()`，全部 PASS 且 decision=`APPROVED` 才能变成 `manual_review=APPROVED`、`publication_ready=TRUE`。随后用 `assert_publication_figures_ready()`做阻断检查。

## 14. `BASELINE_BINARY_RISK` 操作指南

### 14.1 方法库当前可正式使用的范围

`BASELINE_BINARY_RISK` 的生产注册行：ATE、binary outcome、无缺失数据、fixed-weight influence-curve variance、数值已验证。适用于 baseline TTE、二元固定时点 outcome、propensity-score weighting、weighted treated/control risk、RD、RR、SMD、ESS、SE 与 95% CI。

虽然某些底层代码可接受 ATO，生产注册表只批准本 profile 的 ATE。`AVAILABLE IN LIBRARY != PRODUCTION-APPROVED`。

### 14.2 输入要求

- 一行一个分析单位；`subject_id` 与 `analysis_id` 各自唯一、非缺失；
- 五个 ISO-8601 含时区时间字段；
- `treatment` 为 0/1；
- `outcome` 为非缺失 0/1；
- 所有批准 PS baseline confounders 非缺失、在 time zero 前或当时可用；
- `estimand.name=ATE`；
- runtime thresholds 预先冻结。

### 14.3 运行链

```text
contract/structure validation
→ logistic propensity model (WeightIt method="glm")
→ ATE weights
→ balance / SMD / ESS / positivity
→ weighted treated and control risks
→ RD and RR
→ fixed-weight influence-curve SE and 95% CI
→ prespecified weight-truncation sensitivity（如开启）
→ tables / figures / QC
```

### 14.4 关键检查

- `structure_audit.csv`：必须 `structural_pass=TRUE`。
- `diagnostic_gate.csv`：必须 `diagnostic_gate_pass=TRUE`，但代码不会授予科学批准。
- `balance.csv`：逐变量查看 unadjusted/adjusted SMD；不仅看最大值。
- `weight_summary.csv`：n、事件数、公式、total/group ESS、max weight、positivity violation rate。
- `primary_effects.csv`：区分 risk treated、risk control、RD、RR，检查 estimand、population、variance method 和 release status。
- `sensitivity_results.csv`：仅在预设 truncation 开启时生成相应结果。

### 14.5 SMD、ESS、positivity 与 weighted risk

标准化均数差（standardized mean difference, SMD）用于比较协变量分布；应同时看最大 absolute SMD、关键协变量和加权前后方向。常用 0.10 只是经验界限，本项目阈值必须预设，不能在看结果后放宽。

有效样本量（effective sample size, ESS）为 `(sum w)^2 / sum(w^2)`；权重变异越大，ESS 越可能远小于原始 n。ESS 低提示信息损失和不稳定性，不是简单“样本量仍足够”的证明。

Positivity/overlap 检查 PS 是否落在预设 support 范围、越界比例和极端权重。问题可能反映设计不可识别，不能由软件自动改模型解决。

Weighted treated/control risk 是各策略下的加权风险；风险差（risk difference, RD）为二者之差，null=0；风险比（risk ratio, RR）为二者之比，null=1。当前 RR 要求 control risk 为正，否则 estimator 会停止。SE 把已给权重视为 fixed weights，必须按注册方法解释。

## 15. `MI_PS_CONTINUOUS_ATE` 操作指南

### 15.1 方法库当前可正式使用的范围

该 production profile 适用于 multiple imputation、predictive mean matching (PMM)、每个插补数据集内 propensity weighting、continuous outcome、`WeightIt::lm_weightit()` M-estimation、Rubin pooling、Barnard-Rubin degrees of freedom、pooled ATE、SE 与 95% CI。

### 15.2 输入要求

- treatment 非缺失 0/1；outcome 非缺失 numeric continuous；
- 仅批准的 numeric/double baseline PS covariates 可缺失；
- 这些变量必须在字典中 `impute=TRUE`、`mice_method=pmm`；
- `m >= 2`、`maxit >= 1`、seed 固定；
- estimand 固定 ATE；
- 每个插补内都要通过 balance、ESS、positivity，MICE logged events 必须为 0 才自动过 gate。

### 15.3 执行链

```text
MICE + PMM
→ m 个 completed datasets
→ 每个插补内拟合 PS 与 ATE weights
→ 每个插补内 lm_weightit M-estimation
→ 取得 estimate 与 within variance
→ Rubin pooling
→ Barnard-Rubin df
→ pooled ATE / SE / 95% CI
→ complete-case sensitivity（complete cases ≥30 时）
```

`m` 是插补数据集个数；seed 保证随机过程可重复；PMM 为缺失协变量从相似预测值的已观察值中匹配 donor。每个 completed dataset 都必须用同一冻结分析方案独立建权重与估计，然后合并 estimate 与 variance。

**绝对不要**选择一个“最佳插补数据集”。这样会丢失插补间不确定性并产生选择偏倚。主结果是 Rubin pooling 后的 pooled ATE，而不是任一单独 imputation 的结果。

### 15.4 输出检查

- `per_imputation_estimates.csv`：每个 imputation 的 estimate、within variance、SE、ESS、max weight、positivity rate、max abs SMD；
- `balance.csv`：按 imputation × variable 查看；不能只看 median；
- `weight_summary.csv`：minimum total ESS、maximum weight/SMD/positivity rate、MICE logged events；
- `primary_effects.csv`：pooled mean difference、SE、CI、variance method；
- `sensitivity_results.csv`：如 complete cases 至少 30 行，包含预设 complete-case sensitivity。

Rubin 规则合并 within-imputation 与 between-imputation variance。v1.0.0 通过 `mice::pool.scalar(Q,U,n,k=2)`取得总方差和 Barnard-Rubin df，再用 t 临界值生成 95% CI。

## 16. 缺失数据

缺失数据策略必须在查看 treatment effect 前冻结。建议真实项目先在方法库外生成 missingness audit：每个变量缺失数/比例、按 treatment 的缺失、时间关系、特殊缺失编码、合理机制讨论和拟采用策略。

v1.0.0 的生产边界：

- `BASELINE_BINARY_RISK`：outcome 和所有 PS covariates 均不得缺失；没有生产批准的自动插补。
- `MI_PS_CONTINUOUS_ATE`：只对经批准的 numeric/double PS baseline covariates 使用 MICE + PMM；treatment 与 outcome 不插补。
- `missing_code`列不会自动把任意编码转换成 `NA`；应在外部数据准备阶段完成并审计。
- MICE `loggedEvents`非零会阻断 diagnostic gate，必须人工审查。
- complete-case sensitivity 不是主分析替代；只有 complete cases 至少 30 行时实现会生成。

不能因为 complete-case 或某个 seed 的结果更“显著”而改变 missing strategy。任何科学策略改变必须形成新配置版本、新批准记录、新 hash，并重新 Canary；旧结果保留审计但不得混入新 release。

## 17. 权重诊断

倾向评分（propensity score, PS）是在已批准 baseline covariates 条件下接受 treatment 的模型概率。两个生产 profile 使用 `WeightIt::weightit()`的 logistic GLM 路径，并按 ATE 生成权重。

### 17.1 必看的诊断

1. **PS/support：** 两 treatment groups 的 PS 范围和重叠；是否大量接近 0/1。
2. **Weight distribution：** 最大权重、长尾和异常集中；baseline 与 MI 每个 imputation 都看。
3. **SMD：** 每个 covariate 的加权前后变化，不只看 aggregate PASS。
4. **ESS：** total 和 group ESS；MI 看所有插补中的 minimum total ESS。
5. **Positivity violation rate：** 相对冻结 `positivity_lower/upper`的越界比例。
6. **Warnings/MICE events：** `logs/warnings.csv`与 MI logged events。

### 17.2 怎么判断存在问题

- 加权后关键变量 SMD 仍大或比未加权更差；
- 少数极端权重主导估计；
- ESS 相对原始 n 大幅下降；
- treatment groups 的 PS support 分离；
- positivity violation 超过预设 gate；
- MI 只有部分插补通过 balance；
- 结果对预设 truncation/complete-case sensitivity 高度敏感。

这些是需要人工统计审查的信号，不是让软件自动添加变量、截断权重或换 estimand 的许可。当前 production profile 不提供 stabilized weights 的独立批准路径；模板出现 `stabilized_iptw`不等于正式可用。

### 17.3 截断敏感性

Baseline profile 在 `runtime_thresholds.run_truncation_sensitivity=true` 时，按预设 `truncation_lower/upper` quantile 截断权重并重新计算 risk/RD/RR。它是 sensitivity，不应自动替代 primary。MI profile 当前没有相同 production truncation 实现。

## 18. Tables

### 18.1 Table 1

自动 runtime 输出 `tables/table1.csv` 与 HTML，包含：

- treatment group；
- unweighted summary；
- weighted summary；
- unweighted SMD；
- weighted SMD。

`build_table1()`拒绝默认 group-comparison P-value 列。Table 1 的目的主要是描述和 balance，而不是对 baseline 差异做显著性检验；大样本下 P 值会过度敏感，且与加权诊断目的不同。

**实现限制：** 当前自动 adapter 把 PS covariates 转为 numeric 后输出 mean (SD)。如研究需要分类变量水平、median (IQR) 等期刊格式，应使用已经验证的 aggregate summary 调用 table contract，或在独立、审计过的制表流程中完成；不得把自动 numeric summary 误称为适合所有变量类型的最终 Table 1。

对 `MI_PS_CONTINUOUS_ATE`，自动 Table 1 adapter 使用第一个 completed dataset 的 weights，但摘要函数接收的是原始输入数据，并从多插补 balance 行中取首个匹配行；含缺失协变量可能得到不完整摘要。这不是 pooled MI Table 1。MI 项目的正式 Table 1 必须单独做方法学与数值审核，不能把自动文件直接当最终论文表。

### 18.2 Main Results

`primary_effects.csv` 的关键列包括：analysis、effect measure、estimate、standard error、CI lower/upper、P-value reporting status、estimand、analysis population、method、variance method、profile/release status。

- 基线：risk treated、risk control、RD、RR；
- MI：pooled mean difference ATE；
- P values 默认不由 formatting layer 生成；
- 必须核对 CI、null value、estimand、population 和 method，而非只看 estimate。

### 18.3 Sensitivity

`sensitivity/sensitivity_results.csv`保留与 primary 同结构的标准化 estimate/SE/CI，可向 `plot_sensitivity_forest()`提供 analysis、estimate、CI，并显式指定 difference/ratio effect scale。敏感性表必须说明与 primary 的差异，不得选择最有利的一行作为结论。

## 19. Figures：当前 14 类图

v1.0.0 figure contract test 创建 14 个图对象。底层有 12 个 `plot_*`函数；其中 survival/risk 共用一个函数，difference/ratio forest 使用同一 `plot_forest()`但因 null value 和尺度不同按两类测试。**函数可用不等于相应 estimator/module 已获生产批准。**

| # | 图类型（函数/模式） | 用途与建议位置 | 需要的 aggregate/model-summary 输入 | 关键视觉检查 | 常见误用 |
|---:|---|---|---|---|---|
| 1 | Cohort flow (`plot_cohort_flow`) | 纳排流程；通常正文或补充 | `stage`, `n` | 数量单调关系、标签、无裁切 | 用未审计计数；放患者 ID |
| 2 | Missingness (`plot_missingness`) | 各变量缺失比例；通常补充 | `variable`, `missing_fraction` | 0–100%轴、变量完整 | 把缺失比例图当缺失机制证明 |
| 3 | PS distribution (`plot_propensity_score_distribution`) | 检查 overlap；通常补充/诊断 | `propensity_score`, `treatment` | 两组 support、尾部、图例 | 只展示合并密度；从图自动决定删人 |
| 4 | Weight distribution (`plot_weight_distribution`) | 极端权重；通常补充/诊断 | `weight`, `treatment` | 长尾、尺度、组间区别 | 截掉 x 轴隐藏极端权重 |
| 5 | Love plot (`plot_love`) | 加权前后 absolute SMD；正文或补充 | `variable`, `smd_unweighted`, `smd_weighted` | 阈值线、关键变量、标签 | 把 0.10 当绝对真理；只展示通过变量 |
| 6 | Standardized balance (`plot_standardized_balance`) | 有符号 SMD 的阶段比较；通常补充 | `variable`, `smd`, `stage` | ±阈值与 0 线、方向 | 与 Love plot 混称且忽略符号定义 |
| 7 | Difference forest (`plot_forest`, difference) | RD/mean difference；正文常用 | `label`, `estimate`, `ci_lower`, `ci_upper` | null=0、单位与 CI | 把 ratio 结果放在 null=0 图 |
| 8 | Ratio forest (`plot_forest`, ratio) | RR/OR/HR；正文常用 | 同上 | null=1、正值区间、必要时 log 轴说明 | 用 null=0；把 RR 当 RD |
| 9 | Survival curve (`plot_survival_risk`, survival) | 生存概率；仅适当已验证输出，通常正文 | `time`, `estimate`, `strategy`，可选 CI | y 轴 survival、时间单位、risk set 说明 | 认为函数存在即 time-to-event profile 已批准 |
| 10 | Risk curve (`plot_survival_risk`, risk) | 随访风险曲线；仅适当已验证输出 | 同上 | y 轴 risk、单调性和 CI | 将 1-survival 在有 competing risks 时直接当 cumulative incidence |
| 11 | Cumulative incidence (`plot_cumulative_incidence`) | 竞争风险累积发生；仅合适方法输出 | 同 curve schema | 事件定义、竞争事件、范围 | 用普通 KM complement 冒充竞争风险估计 |
| 12 | Sensitivity forest (`plot_sensitivity_forest`) | primary 与预设敏感性比较；通常补充 | `analysis`, `estimate`, `ci_lower`, `ci_upper` + effect scale | 同一 estimand/scale、null、排序 | 混合不可比 estimand；只保留有利分析 |
| 13 | CCW schematic (`plot_ccw_strategy_schematic`) | 解释 cloning/censoring/weighting 策略；方法补充 | `strategy`, `period`, `status` | period、状态、策略标签 | 将示意图当 CCW estimator 验证；CCW 未生产批准 |
| 14 | LMTP policy (`plot_lmtp_policy`) | 展示 observed 与 policy treatment trajectory；方法补充 | `time`, `observed`, `policy` | 单位、轨迹、图例 | 将示意函数当 LMTP 主分析批准；LMTP 未生产批准 |

两个 production profiles 的正式 runtime 自动生成：

- `covariate_balance` Love plot；
- 有 additive effect 时生成 `primary_effect_difference`；
- 有 ratio effect 时生成 `primary_effect_ratio`。

其他函数要求合适的已验证 aggregate 输出和人工审查。`figure_qc.csv` 的机器 PASS 不等于论文视觉批准。流程语义可写作 `PENDING_MANUAL_VISUAL_REVIEW → HUMAN_APPROVED`，但 v1.0.0 的字面字段是 `PENDING_MANUAL_REVIEW`/`manual_review=PENDING`，人工后为 `manual_review=APPROVED`且 `publication_ready=TRUE`。

## 20. Output 目录解释

```text
output/
├─ diagnostics/
├─ tables/
├─ figures/
├─ sensitivity/
├─ internal/
└─ logs/
```

| 目录 | 内容 | 论文使用 | 隐私/发布处理 |
|---|---|---|---|
| `diagnostics/` | contract、structure、balance、weight、gate、independent validation、input manifest；MI 另有 per-imputation estimates | 主要用于 QA；部分 balance/weight 可转补充材料 | aggregate 为主，但仍做 disclosure review |
| `tables/` | primary effects、Table 1 的 CSV/HTML | 经统计和披露审核后可作为论文制表输入 | 自动表仍标记 audit-only release status；不得跳过人工审核 |
| `figures/` | PDF/SVG/TIFF/PNG 与 `figure_qc.csv` | 人工批准后可用 | 未批准图不得进入 manuscript/release |
| `sensitivity/` | 预设敏感性结果 | 常用于补充或正文对照 | 不能选择性报告 |
| `internal/` | `analysis_internal.rds`；含 row-level/completed data/weights 等内部对象 | **不得直接用于论文附件** | 构建 aggregate release 时明确排除；视为私有敏感资产 |
| `logs/` | warnings、package versions | 审计用，不是论文结果表 | aggregate release builder 当前不复制 logs；项目需外部保留 execution log |

输出存在不等于 gate PASS。首先读 `diagnostic_gate.csv` 和 `figure_qc.csv`，再决定是否进入下一步。

## 21. Canary 与 Formal Analysis

### 21.1 Canary

Canary 使用 `execution_mode="CANARY"`，用于：结构/合同、模型可执行性、warning、positivity、weights、balance、ESS、independent numerical check、表图和 output contract。Canary 必须使用已冻结科学字段；它不是论文正式结果，输出 `release_status`为 `AUDIT_ONLY_NOT_FOR_FORMAL_REPORTING`。

### 21.2 Formal Candidate

v1.0.0 的字面执行模式为 `FORMAL_CANDIDATE`，不是 `FORMAL_ANALYSIS`。只有在：

- 科学 specification 冻结；
- input CSV/hash 冻结；
- Canary gate PASS；
- 人工 scientific/statistical/privacy review 通过；
- 所有未决问题关闭；

以后才能执行。

```r
formal <- tte_run_analysis(
  profile = "BASELINE_BINARY_RISK",
  data_path = data_path,
  config_dir = config_dir,
  output_dir = formal_output,
  execution_mode = "FORMAL_CANDIDATE",
  project_root = library_root
)

if (!isTRUE(formal$gate$diagnostic_gate_pass)) {
  stop("FORMAL_CANDIDATE diagnostic gate failed: ",
       formal$gate$stopping_reasons)
}
```

**Fail-closed 的真实边界：** `tte_run_analysis()`会先写诊断、表图和内部对象，再返回 gate；gate FALSE 不代表目录为空。调用者必须像上面一样显式检查并停止 release。不能因文件已经生成就当作正式结果。

## 22. Formal Analysis Release

### 22.1 v1.0.0 构建器实际包含

`tte_build_analysis_release()`创建一个新的、不能预先存在的 destination，包含：

```text
release/
├─ config_snapshot/
│  ├─ analysis_spec.yml
│  ├─ variable_dictionary.csv
│  ├─ input_data_contract.csv
│  └─ figure_config.yml
├─ diagnostics/
├─ tables/
├─ figures/
├─ sensitivity/
├─ metadata/
│  ├─ VERSION
│  └─ session_info.txt
└─ result_manifest.csv
```

`diagnostics/input_manifest.csv`保留实际 input SHA、analysis spec SHA、variable dictionary SHA、row/column count 和 profile；`result_manifest.csv`记录 release 内每个文件的相对路径、字节数和 SHA-256。

构建前必须先完成：

```r
if (!isTRUE(formal$gate$diagnostic_gate_pass)) stop("Diagnostic gate failed")

assert_publication_figures_ready(
  file.path(formal_output, "figures", "figure_qc.csv")
)

manifest <- tte_build_analysis_release(
  config_dir = config_dir,
  output_dir = formal_output,
  destination = release_destination,
  project_root = library_root
)
```

### 22.2 不得包含

- patient CSV 或其他 row-level input；
- `output/internal/`和 `analysis_internal.rds`；
- manuscript prose；
- reviewer/private governance 文件；
- credentials 或内部路径；
- 未人工批准的 figures。

### 22.3 当前自动化边界

构建器会检查目录完整、四个 config、destination 不覆盖，并排除文件名/路径含 `internal`、`input/private`、`manuscript`、`reviewer` 的资产。但它**不会自动核验** diagnostic gate、input contract SHA 与实际 SHA、figure human approval、Git tag/commit/DOI，也不会复制 `logs/package_versions.csv`。

因此正式 release 还必须由项目 checklist 人工确认：input/config hash、tag/commit/DOI、R/package versions、run date、diagnostic gate、统计审核、视觉审核和披露审核。若机构要求把额外 metadata 放进同一包，必须用独立、审计过的上层包装流程重新生成完整 manifest；不得手工加文件后仍声称原 `result_manifest.csv`完整。

## 23. Reproducibility

每个真实研究固定记录：

```yaml
method_library:
  name: "Target Trial Emulation Statistical Analysis Method Library"
  version: "1.0.0"
  tag: "v1.0.0"
  commit: "998e3c0a83656eae5e3ee8dae909e2edcd2625ec"
  doi: "10.5281/zenodo.21879884"
```

同时记录：

- R `4.5.1`；
- `renv.lock` hash 与关键 package versions；
- seed（MI）；
- input SHA-256；
- 四个 config 的 SHA-256；
- run date/time/timezone；
- execution mode、profile、输出目录；
- warnings 与 gate status；
- figure reviewer/date；
- result manifest SHA。

Windows 批量计算 config hash：

```powershell
Get-FileHash -Algorithm SHA256 .\config\analysis_spec.yml
Get-FileHash -Algorithm SHA256 .\config\variable_dictionary.csv
Get-FileHash -Algorithm SHA256 .\config\input_data_contract.csv
Get-FileHash -Algorithm SHA256 .\config\figure_config.yml
```

不要只记录“用了 v1.0.0”；tag、commit、DOI、R、packages、input/config hash 缺一会降低可重复性。

## 24. 论文如何引用

正式论文优先引用 version DOI：[`10.5281/zenodo.21879884`](https://doi.org/10.5281/zenodo.21879884)。不要用 moving `main`、最新 GitHub commit 或 concept DOI 代替本研究实际使用的 version DOI。

英文 software citation 示例：

> Zheng, X. (2026). *Target Trial Emulation Statistical Analysis Method Library* (Version 1.0.0) [Software]. Zenodo. https://doi.org/10.5281/zenodo.21879884

按期刊格式可调整大小写、标点和作者名格式，但不得改 DOI/version。

Code Availability 模板：

> Statistical analyses were executed using the Target Trial Emulation Statistical Analysis Method Library, version 1.0.0 (Git tag v1.0.0; commit 998e3c0a83656eae5e3ee8dae909e2edcd2625ec), archived at Zenodo (https://doi.org/10.5281/zenodo.21879884). Study-specific patient-level data and private configurations are not included in the public software repository.

这只是模板。作者必须根据真实数据共享政策、研究审批和实际运行内容修改；不得照抄未发生的开放数据或开放代码声明。

## 25. Troubleshooting

完整的“表现—原因—检查—正确处理—禁止处理”表见[故障排查表](TROUBLESHOOTING_ZH_CN.md)。最常见阻断点：

- Rscript/PATH 与 PowerShell `R` alias；
- renv 未激活或包版本漂移；
- profile/tag/commit 不一致；
- scientific fields 未冻结；
- role alignment；
- duplicate ID、binary coding、ISO time ordering；
- MI 非批准缺失路径；
- SMD/ESS/positivity/weights；
- figure clipping/overlap/600 DPI/manual approval；
- formal release gate 未显式检查。

出现 SMD、ESS、extreme weights 或 positivity 问题时，这是分析问题。允许人工审查并依据预设 sensitivity plan 处理；禁止软件自动改模型、放宽 threshold 或选择有利结果。

## 26. Windows 常用命令

```powershell
git status
git status --short
git rev-parse HEAD
git describe --tags --exact-match HEAD
git remote -v
Rscript --version
Get-Command R
Get-Command Rscript
Rscript -e ".libPaths()"
Rscript -e "packageVersion('WeightIt')"
Rscript examples\quick_start\run_quick_start.R
Rscript validation\run_public_numerical_regression.R
```

带明确 R 路径的换行示例：

```powershell
& "<R-4.5.1实际安装目录>\bin\Rscript.exe" `
  "examples\quick_start\run_quick_start.R"
```

PowerShell 的换行是行尾反引号 `` ` ``。复制命令时不要写成 `\``；建议初学者优先使用单行命令。

## 27. 新电脑部署

```text
clone public repository
→ checkout v1.0.0
→ verify tag and SHA
→ install/select R 4.5.1
→ install renv bootstrap
→ restore renv.lock
→ verify .libPaths() and package versions
→ Quick Start
→ public numerical regression
→ project Canary
→ ready for human review
```

建议命令：

```powershell
git clone https://github.com/secdelic/tte-method-library.git
Set-Location .\tte-method-library
git checkout v1.0.0
git rev-parse HEAD
Rscript -e "install.packages('renv'); renv::restore(project='.', prompt=FALSE)"
Rscript examples\quick_start\run_quick_start.R
Rscript validation\run_public_numerical_regression.R
```

Numerical regression 预期：

```text
PUBLIC_NUMERICAL_REGRESSION=PASS; checks=14
```

不要直接复制旧电脑整个 R library：其中可能有平台相关 binary、不同 R minor version、残留 package 或错误路径。优先由 lockfile 恢复；如使用共享 cache，仍必须核对实际版本和回归结果。

## 28. 版本管理

- `v1.0.0` 是冻结 tag，不得移动。
- 使用 v1.0.0 的论文引用 version DOI `10.5281/zenodo.21879884`。
- 修改统计源码后不能继续称为 v1.0.0。
- 向后兼容 bug fix 原则上使用 `v1.0.1`。
- 向后兼容新功能原则上使用 `v1.1.0`。
- breaking change 考虑 `v2.0.0`。
- 未来版本不能反向改变本研究已使用版本的记录。

这些是版本治理建议；实际新版本发布必须另行验证、审查、tag 和归档。本手册不创建新版本。

## 29. 绝对不要这样做

1. 修改 v1.0.0 统计源码后继续称为 v1.0.0；
2. 自动升级 R packages 或修改 `renv.lock`；
3. 使用 moving `main`作为论文冻结版本；
4. 把患者 CSV、RDS/RData 或 private config 提交 GitHub；
5. 根据结果改变 cohort、outcome、confounders、model、estimand 或 threshold；
6. 自动挑选最有利模型或 sensitivity；
7. 单独选择“最好”的 MICE completed dataset；
8. 把 CCW、LMTP、longitudinal TTE、PATH、three-timepoint TTE 或 multilevel PS 当 production module；
9. 把 Canary/Synthetic Test 结果当正式论文结果；
10. 忽略 weight、balance、ESS、positivity 或 MICE logged events；
11. 用输出文件存在代替 `diagnostic_gate_pass`检查；
12. 把 `tte_build_analysis_release()`成功当科学批准；
13. 自动批准 figure，或手工把 `publication_ready`改 TRUE；
14. 把 `internal/analysis_internal.rds`上传为补充材料；
15. 为了 PASS 修改 expected values、numerical tolerance 或 production registry。

## 30. 推荐真实项目一页式 SOP

```text
① 研究者/GPT辅助制定 protocol（最终科学判断由研究者确认）
② 在方法库外完成数据库提取
③ 数据 QA：单位、分析单位、重复、缺失、范围、时间顺序
④ 冻结 analysis-ready CSV 与 SHA-256
⑤ 填写并批准 analysis_spec.yml
⑥ 填写并批准 variable_dictionary.csv
⑦ 填写 input_data_contract.csv 并人工比对 SHA
⑧ 冻结 figure_config.yml 与四个 config SHA
⑨ 验证 v1.0.0 tag/commit、R 4.5.1、lockfile packages
⑩ 执行 input/contract validation
⑪ 执行 CANARY
⑫ 人工审核 structure、warnings、weight、SMD、ESS、positivity、MI events
⑬ 关闭 unresolved items；科学改变则重新冻结并重跑 Canary
⑭ 对最终冻结输入执行 FORMAL_CANDIDATE
⑮ 显式检查 diagnostic_gate_pass
⑯ 执行并完整报告 prespecified sensitivity
⑰ 核对 Table 1、main results、sensitivity 的数值一致性
⑱ 导出 vector + 600-DPI raster figures
⑲ 人工 visual QA，记录 reviewer/date，assert figures ready
⑳ 统计 QA、隐私/披露 QA
㉑ 构建 aggregate analysis release 与 result manifest
㉒ 人工核对 tag/commit/DOI/R/packages/input/config/result hashes
㉓ 将 aggregate 结果交给独立 writing workflow
㉔ Methods/Results/Table/Figure 交叉核对
㉕ 论文引用 version DOI；由研究者决定投稿
```

完成标准：所有自动 gate 与人工 gate 有真实证据；formal release 只含 aggregate/审计允许文件；无法验证的事项明确保留为 unresolved，不制造 PASS。
