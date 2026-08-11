# TTE Method Library v1.0.0 中文快速参考

适用版本：`1.0.0` · tag `v1.0.0` · commit `998e3c0a83656eae5e3ee8dae909e2edcd2625ec`<br>
Version DOI：[`10.5281/zenodo.21879884`](https://doi.org/10.5281/zenodo.21879884) · License：MIT<br>
仓库：[`https://github.com/secdelic/tte-method-library`](https://github.com/secdelic/tte-method-library)

> 科学方案由研究者预先制定并冻结。方法库执行与验证，不自动定义 cohort/treatment/outcome/time zero/confounders/estimand，不根据结果改模型，不写论文或投稿。

## 1. 安装与固定版本

```powershell
git clone https://github.com/secdelic/tte-method-library.git
Set-Location .\tte-method-library
git checkout v1.0.0
git rev-parse HEAD
git describe --tags --exact-match HEAD
Rscript --version
```

预期：

```text
HEAD = 998e3c0a83656eae5e3ee8dae909e2edcd2625ec
tag  = v1.0.0
R    = 4.5.1
```

PowerShell 的 `R` 常是 `Invoke-History` alias；判断 R 安装请用：

```powershell
Get-Command R
Get-Command Rscript
Rscript --version
```

PATH 未配置时使用本机实际路径：

```powershell
& "<R-4.5.1实际安装目录>\bin\Rscript.exe" --version
```

## 2. 恢复冻结 R 环境

```r
install.packages("renv")
renv::restore(project = ".", prompt = FALSE)
.libPaths()
renv::status()
```

关键锁定版本：

| renv | WeightIt | mice | cobalt | ggplot2 | yaml | digest |
|---:|---:|---:|---:|---:|---:|---:|
| 1.2.2 | 1.7.0 | 3.19.0 | 4.6.3 | 4.0.3 | 2.3.12 | 0.6.39 |

v1.0.0 tag 中没有 `renv/activate.R`，不要假设自动激活。restore 后必须核对 `.libPaths()`和实际包版本。缺单包时优先：

```r
renv::restore(project = ".", packages = "WeightIt", prompt = FALSE)
```

不要 `update.packages()`或用最新版替代 lockfile。

## 3. Quick Start

从仓库根：

```powershell
Rscript examples\quick_start\run_quick_start.R
```

预期消息：

```text
Synthetic production Quick Start PASS
```

它用合成数据执行 `BASELINE_BINARY_RISK` 的 `SYNTHETIC_TEST`，输出 diagnostics、Table 1、primary effects、sensitivity、PDF/SVG/TIFF/PNG figures、figure QC、internal RDS 和 logs。输出在 `examples/quick_start/output/`。PASS 不证明真实研究设计正确。

新电脑还应执行：

```powershell
Rscript validation\run_public_numerical_regression.R
```

预期：`PUBLIC_NUMERICAL_REGRESSION=PASS; checks=14`。

## 4. 正式项目输入四件套

正式研究放在方法库目录外：

```text
ResearchProject/
├─ input/private/analysis_data.csv
├─ config/
│  ├─ analysis_spec.yml
│  ├─ variable_dictionary.csv
│  ├─ input_data_contract.csv
│  └─ figure_config.yml
├─ output/
└─ project_metadata/
```

| 文件 | 作用 | 必须人工决定 |
|---|---|---|
| `analysis_spec.yml` | 冻结 population、time zero、treatment、follow-up、outcome、estimand、missing、weighting、variance、sensitivity、thresholds | 所有科学定义；`scientific_fields_frozen=true`；禁止结果驱动修改 |
| `variable_dictionary.csv` | 每变量 role/type/unit/reference/levels/timing/missing/imputation/model use | confounder/mediator/collider 判定；measurement vs availability time；reference |
| `input_data_contract.csv` | 相对路径、分析单位、主键、时间结构、expected columns、SHA、批准人 | 实际 SHA 比对；患者/住院/stay 级；输入冻结 |
| `figure_config.yml` | 85/178 mm、≥7 pt、PDF/SVG、TIFF/PNG、≥600 DPI、palette 与人工 QC | 期刊尺寸、人工 visual approval |

数据固定要求：一行一个分析单位；`subject_id`和`analysis_id`各自唯一、非缺失；五个含时区 ISO-8601 时间列；treatment 0/1；profile-compatible outcome。

## 5. 两个 production profile

| Profile | 正式范围 | 不得外推 |
|---|---|---|
| `BASELINE_BINARY_RISK` | baseline TTE；ATE；binary nonmissing outcome；PS weighting；weighted treated/control risk；RD、RR；SMD、ESS；fixed-weight influence-curve SE/95% CI；预设截断敏感性 | 不插补；不自动 CCW/longitudinal；底层 ATO 可用不等于注册表批准 |
| `MI_PS_CONTINUOUS_ATE` | MICE/PMM；continuous nonmissing outcome；每插补内 ATE weighting + `lm_weightit` M-estimation；Rubin pooling；Barnard-Rubin df；pooled ATE/SE/95% CI；可执行时 complete-case sensitivity | 不插补 treatment/outcome；不选“最佳插补集”；不自动改 missing strategy |

CCW、LMTP、longitudinal TTE、PATH、three-timepoint TTE、multilevel PS 均未生产批准。

```text
AVAILABLE IN LIBRARY != PRODUCTION-APPROVED
```

## 6. Canary → Formal Candidate → Release

可用 execution mode 只有：

```text
SYNTHETIC_TEST
CANARY
FORMAL_CANDIDATE
```

没有字面 `FORMAL_ANALYSIS` mode。

```r
result <- tte_run_analysis(
  profile = "BASELINE_BINARY_RISK",
  data_path = data_path,
  config_dir = config_dir,
  output_dir = output_dir,
  execution_mode = "CANARY",
  project_root = library_root
)

if (!isTRUE(result$gate$diagnostic_gate_pass)) {
  stop(result$gate$stopping_reasons)
}
```

人工审查通过后，用最终冻结输入在新输出目录执行 `FORMAL_CANDIDATE`，再次显式检查 gate。图形必须由真实 reviewer 记录 clipping/overlap/grayscale PASS，再调用：

```r
assert_publication_figures_ready(file.path(output_dir, "figures", "figure_qc.csv"))
```

最后才构建 aggregate release：

```r
tte_build_analysis_release(
  config_dir = config_dir,
  output_dir = output_dir,
  destination = release_dir,
  project_root = library_root
)
```

注意：构建器不自动检查 diagnostic gate、合同 SHA 与实际 SHA、human figure approval、tag/commit/DOI；项目 SOP 必须先阻断检查。

## 7. Output 目录

| 目录 | 内容 | 是否直接给论文 |
|---|---|---|
| `diagnostics/` | contract、structure、balance、weights、gate、independent check、input manifest；MI per-imputation | QA；部分可转补充，需审核 |
| `tables/` | `primary_effects.*`、`table1.*` | 经统计/披露审核后 |
| `figures/` | multi-format figures、`figure_qc.csv` | 仅人工批准后 |
| `sensitivity/` | 预设敏感性结果 | 通常补充或正文对照；不得选择性报告 |
| `internal/` | row-level/completed/weights RDS | **不得上传或进 release** |
| `logs/` | warnings、package versions | 审计保留，不是结果表 |

## 8. 诊断最小检查

```text
structure_audit.csv: structural_pass=TRUE
diagnostic_gate.csv: diagnostic_gate_pass=TRUE
balance.csv: 每变量加权前后 SMD
weight_summary.csv: ESS、max weight、positivity
warnings.csv: 无 blocking/unreviewed warning
MI: 每个 imputation 的 estimate/variance/SMD/ESS/positivity，logged events=0
figure_qc.csv: machine PASS + human APPROVED + publication_ready=TRUE
```

SMD threshold、ESS 和 positivity bounds 是预设 gate，不是普遍真理。失败时停止并人工审查；不能放宽阈值到 PASS、自动增删 confounders 或选择有利模型。

## 9. 常见错误速查

| 表现 | 首先检查 | 正确方向 |
|---|---|---|
| `Rscript`找不到 | `Get-Command Rscript` | 修 PATH 或用实际 R 4.5.1 路径 |
| PowerShell `R`异常 | `Get-Command R` | 使用 `Rscript` |
| `Package 'WeightIt' is required` | `.libPaths()`、`packageVersion()` | `renv::restore(packages="WeightIt")`，锁定 1.7.0 |
| role conflict | spec vs dictionary `role` | 研究者确认后统一，记录决策 |
| duplicate ID | analysis unit 与重复来源 | 回到数据构建，不要无解释去重 |
| binary coding | treatment/outcome 分布与 reference | 外部按冻结定义映射 0/1 |
| time ordering | 五个时间列与时区 | 修 analysis-ready 数据并重冻 SHA |
| SMD/ESS/positivity 失败 | balance/weight/gate | 统计人工审查；不得自动改模型 |
| figure not ready | clipping/overlap/grayscale/reviewer/date | 真实人工视觉 QA |
| release builder success 但 gate 未核验 | `result$gate`与 figure readiness | 不得 release；补齐上层人工 gate |

详见[故障排查表](TROUBLESHOOTING_ZH_CN.md)。

## 10. 常用命令

```powershell
git status --short
git rev-parse HEAD
git describe --tags --exact-match HEAD
Rscript --version
Get-Command Rscript
Rscript -e ".libPaths()"
Rscript examples\quick_start\run_quick_start.R
Rscript validation\run_public_numerical_regression.R
(Get-FileHash -Algorithm SHA256 ".\input\private\analysis_data.csv").Hash
```

## 11. 论文引用

优先引用 version DOI，而不是 `main`、最新 commit 或 concept DOI：

> Zheng, X. (2026). *Target Trial Emulation Statistical Analysis Method Library* (Version 1.0.0) [Software]. Zenodo. https://doi.org/10.5281/zenodo.21879884

项目 reproducibility record：

```yaml
method_library:
  name: "Target Trial Emulation Statistical Analysis Method Library"
  version: "1.0.0"
  tag: "v1.0.0"
  commit: "998e3c0a83656eae5e3ee8dae909e2edcd2625ec"
  doi: "10.5281/zenodo.21879884"
```

同时记录 R/package versions、seed、input/config SHA、run date、gate status、figure reviewer 和 result manifest。

完整说明见[中文版正式使用说明书](USER_GUIDE_ZH_CN.md)；字段逐项定义见[配置字段字典](CONFIG_REFERENCE_ZH_CN.md)。
