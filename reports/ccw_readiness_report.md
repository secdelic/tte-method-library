# CCW statistical parity program：科学冻结前交付

日期：2026-10-15。

`CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL`

当前完成的是 authority 草案、方法类别审计、输入/实现架构和独立验证计划。
关键科学字段尚未冻结，依本次任务的明确停止规则，没有启动统计实现或仿真。
`CCW_METHOD_CAPABILITY_PARITY_NOT_ESTABLISHED` 保持不变。

## 本次范围和九项交付

| 文件 | 用途 |
| --- | --- |
| [CCW_SCIENTIFIC_AUTHORITY_V1.yml](../governance/CCW_SCIENTIFIC_AUTHORITY_V1.yml) | 待人工审阅的科学/验证字段，所有未确认值显式标记 |
| [ccw_benchmark_methods_matrix.csv](ccw_benchmark_methods_matrix.csv) | 22 项方法类别，逐项列主文、当前代码、实现/数值缺口、决策、comparator 和生产门 |
| [ccw_implementation_architecture.md](../docs/ccw/ccw_implementation_architecture.md) | clone、censor、IPCW、结局、推断、MI、敏感性/亚组和实际结果绘图绑定 |
| [ccw_input_contract.md](../docs/ccw/ccw_input_contract.md) | 六类独立配置的 analysis-ready 输入和时间/身份契约 |
| [ccw_validation_protocol.md](../docs/ccw/ccw_validation_protocol.md) | oracle、边界、完整 bootstrap、MI、冻结和失败处理 |
| [ccw_independent_comparator_plan.md](../docs/ccw/ccw_independent_comparator_plan.md) | 独立公式/包候选、匹配条件和不得复用待测 helper 的边界 |
| [ccw_known_truth_simulation_plan.md](../docs/ccw/ccw_known_truth_simulation_plan.md) | 14 类场景及 DGP/truth/参数/MC uncertainty 冻结需求 |
| [ccw_production_gate_checklist.csv](ccw_production_gate_checklist.csv) | 18 项生产门；数值执行均 NOT_RUN，人工决定 PENDING |
| [ccw_readiness_report.md](ccw_readiness_report.md) | 本报告，记录范围、结果、限制及文件表面审计 |

本轮仅新增这九个文本文件；不添加可执行 CCW R 源码、测试替身或 production profile。
这些方案尚未成为已冻结的 preregistered validation protocol。

## Benchmark 证据与不可推断内容

来源为研究者提供的 Liu et al. 九页 corrected-proof 主文，
DOI [10.1016/j.jare.2026.08.009](https://doi.org/10.1016/j.jare.2026.08.009)。
本轮读取 pp.2-3 方法全文、p.4 Fig.2 caption，复核 pp.2-3 实际页面渲染。
本机来源 PDF 的 SHA256 为
`acb16d902d5ef1362e2e7c4596d0b9015813d4a6686801506cbcbd28827526e2`。
此摘要只用于源文件身份；论文 PDF、页面图和全文提取均未加入本分支。

主文确立了 per-protocol CCW、baseline cloning、grace 内逐小时评估、人工删失、
IPCW、逐小时 logistic censoring model、权重截尾、weighted survival / competing-risk CIF、
risk/survival differences、RMST/RMTL、nonparametric bootstrap、grace-period sensitivity、
subgroup CCW 和缺失处理这些方法类别。矩阵中的具体窗口/阈值/次数仅是主文事实，
不是为本项目选择的默认值，也不表示该论文已独立数值复现。

Supplemental Data 1/2 未提供：精确 numerator/denominator 公式、协变量更新/
availability 规则、stabilization、截尾 domain/算法、事件 ties、
bootstrap 抽样单位/CI 类型/必要 refit、MI 的 m/pooling/nesting 等未充分明确处
继续 `UNKNOWN`。不由图形或引用的其他方法论文补写其实际实现。
benchmark 的临床定义、数据和数值结果不移植为本库通用规则。

## 当前代码与独立分支

分支：`feature/ccw-production-validation`，直接基于
`main` 的 `56c6314689aee66b2de588ac773c8770ca5be346`。
本次检查时 [PR #2](https://github.com/secdelic/tte-method-library/pull/2)
和 [PR #3](https://github.com/secdelic/tte-method-library/pull/3) 均为未合并 draft，
分别处于 `741b73a` 和 `e2bfc31`。未将其代码或图形改动并入统计分支。
原工作区已有未提交文件保留；本次工作在独立 managed worktree。

[registry](../runtime/production_registry.csv) 仍只有
`BASELINE_BINARY_RISK` 和 `MI_PS_CONTINUOUS_ATE`。
公开 R/runtime/validation 树未发现 CCW clone/censor/IPCW/weighted survival/CIF 引擎。
baseline 的 RD/RR、PS 截尾和 continuous ATE 的 PMM/Rubin 证据
不构成 CCW 或 CCW+MI 验证。已有图形能够展示输入值，不会生成这些统计估计。
旧 module-readiness 的 development/synthetic 描述不证明当前公开树有相应实现。

## 科学冻结前的必要决定

authority 包含 28 组、86 个待决定的科学/验证值，另有人工批准记录字段，
覆盖任务要求的全部主题。优先解决：

1. 验证 profile 的 analysis unit、subject cluster、eligibility、time zero、策略与窗口内干预分布。
2. 依从性、grace 闭开、interval 长度、治疗/结局/删失 ties、自然删失和竞争事件。
3. baseline/时变变量与 availability、IPCW 模型、权重时间、stabilization/truncation 和缺失数据顺序。
4. estimands/horizons、survival/CIF、RMST/RMTL、CI 方法、subject bootstrap 全部 refit、次数与失败政策。
5. subgroup/interaction、sensitivity、计数/图表绑定、DGP/truth/样本量/seeds/重复数/容差/coverage 门。

按原 subject 重抽样、保留全部相关 units/clones、完整重拟合必要模型、不得用 fixed weights
冒称等价是本次任务已明确的约束。它们不能代替具体科学模型、参数和正式批准。
可以由研究者批准有边界的合成方法验证 profile；真实项目方案和采用权仍独立。

研究者报告“既往 CCW 小样本 RMST 区间校准未全面通过”。本轮公开树检索未发现对应
原始失败数据/场景/覆盖率文件，因此将其记为用户报告的既有风险，数值细节 UNKNOWN。
不得编造重跑结果。RMST/RMTL 的点估计与区间分别验证，未通过 CI 不入 allowlist。

## 本阶段验证记录

以下为本轮实际执行的文件/范围检查，不是统计方法验证。
不将既有 baseline/MI 验证状态重标为本轮 CCW PASS。

| 检查 | 本轮状态 |
| --- | --- |
| 九项最终文件存在、UTF-8 与 YAML/CSV 解析 | PASS |
| 必需 authority 字段、未决值、批准状态与停止规则一致 | PASS；28 组/86 值保持未决，冻结/实现/生产批准均 false |
| 22 项 matrix / 18 项 gate / 14 类 simulation 的覆盖与引用一致 | PASS；CSV 无缺列/空单元，gate 引用有效 |
| 文档链接与 public repository privacy scan | PASS；运行仓库既有两个 validator |
| 仅新增九文件；冻结代码/expected/registry/lockfile/tag 未改 | PASS；Git staged diff 只有九项新增，无既有文件改动 |
| 稳定版本和 Zenodo 元数据一致性 | PASS；运行既有 validate_metadata.R，未改元数据 |
| CCW 实现、oracle、comparator、simulation、bootstrap | NOT_RUN |
| project-specific canary、独立统计审阅、人工科学批准 | NOT_RUN / PENDING |

不需要为纯文本计划重跑全部统计引擎。后续 GitHub CI 若运行 baseline/MI 检查，
其范围仍不是 CCW 方法或 scientific authority 验证。
本地解析使用 R 4.5.1 / yaml 2.3.10 及 Python 标准库 CSV；未安装或升级依赖。
检查命令包括 `Rscript validation/validate_documentation_links.R`、
`Rscript validation/scan_public_repository.R`、`Rscript validation/validate_metadata.R`
和 `git diff --cached --check`；Windows 上对前两个脚本仅在进程内设置 UTF-8 locale。
另以一次性本地检查回读 YAML 状态、CSV 引用、Markdown 表格/链接和实际九文件字节；
未把这些结构检查包装为 CCW 算法测试。

## 最终外发表面审计

交付范围为上述九个实际 UTF-8 文本文件，适用表面为正文、文件名、Markdown 链接、
YAML/CSV 字段和值、注释和状态文字。无 PDF/Office/图像/ZIP 交付。
合法的 authority、gate、冻结标识和源摘要用于本公开软件验证计划的复现与审计，
并非需要清除的内部残留。未改写作者身份、日期或来源记录。

AI assistance was used for source inspection, planning-document drafting and
technical consistency checks. No CCW statistical analysis was executed in this
stage. Scientific specification and adoption remain subject to human review.

```text
FINAL_EXTERNAL_SURFACE_AUDIT
FILES_CHECKED = 9
FILES_TOTAL = 9
UNINTENDED_TOOL_OR_TEMPLATE_LABELS = NONE
IDENTITY_METADATA_REVIEW = NONE
NORMAL_SOFTWARE_METADATA = NONE
LEGITIMATE_AI_DISCLOSURES = This report: actual assistance in inspection, drafting and technical checks
INTERNAL_WORKFLOW_RESIDUE = NONE; public specification, gate names and reproducibility references are intentional
UNCHECKED_SURFACES = NONE within the stated plain-text deliverable scope; no binary or embedded payloads
EXTERNAL_SURFACE_STATUS = CLEAR_WITHIN_CHECKED_SCOPE
```

## 停止与后续授权入口

待研究者逐项完成 authority，冻结与其匹配的 validation protocol、comparator 和 simulation
参数，提供对应版本的明确批准后，才能启动实现。当前不修改生产 allowlist、不自动合并、
不发布 Release，也不声明 `CCW_METHOD_PARITY_VALIDATED`。
本阶段的准确终态为 `CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL`。
