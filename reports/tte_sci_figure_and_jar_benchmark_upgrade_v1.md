# TTE SCI figure and JAR benchmark capability upgrade V1

完成核对日期：2026-10-15。任务范围：公开方法库的视觉候选审计、JAR
能力基准核对及独立 publication figure v1.2 candidate；没有执行 CCW 研究。
本候选的实际 AI assistance 包括代码、fixtures/tests、原生 R 绘图与导出验证、
技术审阅、能力矩阵及报告起草；不将其描述为仅语言润色。研究者负责人工
style 审阅和最终科学采用。没有生成式患者影像或实验图像。

## 1. PR #2 visual audit

研究者明确回复“已逐张人工审阅，确认 PASS”，对应 cbc4424 的 14 张
候选图在 85/178 mm 下的人工视觉审阅。该记录仅适用于原 style candidate。
保留的 28 张原始/候选文档 PNG 均与已审阅版本字节一致。
详见 [逐图审计](pr2_visual_audit.md)。

## 2. Palette adoption recommendation

建议采用现有 navy/terracotta/teal/gold/slate/charcoal 方向；白底、克制坐标、
语义配色、形状/线型冗余保持。没有再设计第二套 palette。人工 merge 决定与
真实研究图的科学采用仍独立于技术检查。

## 3. PR #2 generated-asset audit

原 cbc4424 的 223 个 changed files 已逐项分类：55 KEEP_IN_MAIN、168
CI_ARTIFACT_OR_REGENERABLE。原 196 个生成图文件先在本机完整归档并逐字节
核对；最终 style tree 保留 28 张文档 PNG，生成图体积减少 79.82%。
完整矩阵、重复图和 CVD 预览从最终 tree 移至 ignored output，可由源码重建。
没有宣称旧 Git 历史中的 binary 已消失；未改写历史、未 force push。
详见 [保留审计](pr2_generated_asset_retention_audit.md) 和
[分类清单](pr2_asset_retention_manifest.csv)。

## 4. JAR benchmark method matrix

已核对 DOI/PMID，并读取研究者提供的九页 corrected-proof 全文中的相关方法及
Fig. 1-4。只抽象方法类别和 figure information architecture，没有使用论文
患者数据、结果数值、图标、图像、布局像素或代码。补充材料未提供、未审阅；
其具体模型和验证细节不作推断。
[方法矩阵 A](jar_tte_benchmark_capability_matrix.md) 给出逐项代码/registry/test
证据，区分已验证的 baseline/MI ATE 与缺失的 CCW pipeline。

## 5. JAR benchmark figure matrix

[绘图矩阵 B/D](jar_tte_benchmark_capability_matrix.md) 分别记录原候选与升级后
13 项信息表达能力。升级后的对应项均为 VISUALIZATION_ONLY；没有把已能绘图
改标成统计估计器 PRODUCTION_VALIDATED。

## 6. Current method parity

公开 registry/runtime 仍仅允许 BASELINE_BINARY_RISK 与
MI_PS_CONTINUOUS_ATE。风险差的 production validation 只覆盖 baseline
fixed-horizon binary ATE；PMM/Rubin 验证只覆盖 MI continuous ATE。
CCW per-protocol estimand、cloning、artificial censoring、IPCW、weighted
KM/CIF、RMST/RMTL 和 CCW inference 的完整 production parity 未建立。

## 7. Current plotting parity

`FIGURE_CAPABILITY_PARITY_READY` 限于本轮已测试的信息架构、原生输出和原创
synthetic fixtures。可表达 flow、clone/event timeline、CI bands、caller-supplied
risk table/annotation、任意 horizon panels、分层 subgroup forest 和一致行结构的
forest panels。它不代表真实研究验证、论文复现、像素模仿或人工发表批准。

## 8. Figure capability gaps

原矩阵所列的缺失绘图功能已在独立候选中补齐。真实数据规模、长标签、复杂
多分支图及密集 risk tables 仍需按实际输入调整尺寸并查看最终导出；不能以
本轮 synthetic PASS 宣称所有未来数据均不会裁切。实际统计估计与输入 provenance
仍由有效研究代码/方案和研究者负责。

## 9. Implemented new figure capabilities

新增六个 public APIs：`plot_participant_flowchart()`、
`plot_tte_ccw_timeline()`、`plot_survival_risk_publication()`、
`compose_outcome_panels()`、`plot_subgroup_forest()`、
`compose_forest_panels()`。复用 SCI theme/colors 和同一 export contract；仅扩展
其接受原生 grid/gtable composite。N、事件时间、曲线、CI、效应、interaction P
均显式由 caller 提供，没有从图像估算、从 CI 判断获益或根据 P 值着色。
见 [API guide](../docs/figures/publication_capability_guide.md) 与
[原创 gallery](../figure_gallery/publication_capability/README.md)。

## 10. New tests

新增 [结构/语义测试](../tests/test_publication_capabilities.R)：分支/排除/计数与
环拒绝、事件实际时间/grace/ties、风险表完整性/计数/端点、subgroup hierarchy、
formatted CI、null=0/1、统一 strategy mapping、curve/table 与 forest 行对齐、
显式独立尺度及未批准 QC。现有加新增共 5 个测试脚本 PASS。
另核对 72 个实际 PDF/SVG/TIFF/PNG 文件：矢量、600 DPI、请求尺寸和 native
rounding、PDF 最小字体 7 pt、page bbox、PNG/TIFF 像素一致；实际 PDF/SVG
render 检查 synthetic labels/counts/CI 未发现裁切。

## 11. Accessibility

9 类原创 scene 的灰阶、deutan、protan、tritan 共 36 个实际 PNG 预览已检查。
色觉模拟转换复用现有 validator helper；线型、事件形状、文字和层级提供冗余。
参考线/CI/ribbon 在检查范围内可见。详见
[视觉与无障碍记录](publication_capability_visual_and_accessibility_review.md)。
这是技术和 AI-assisted review，新的 QC 均保持 publication_ready=FALSE、
manual_review=PENDING；原 style 人工 PASS 不自动套用到新增图。

## 12. Statistical invariance

本轮重新执行：5 个测试脚本、现有 Quick Start、14 项 frozen regression、
11 项 independent validation，均 PASS。两个既有 profile 的最大绝对回归差异为
5.32907051820075e-15，冻结容差 1e-8；独立验证最大差异
1.13686837721616e-13，既有容差 1e-7。未修改 expected 或 tolerance。
统计 R/core/estimators/estimands/weighting/missing_data/diagnostics、runtime、
冻结 fixtures、renv.lock、VERSION 和 module readiness 相对 style base 无改动。
证据：[回归](sci_style_numerical_regression.csv)、
[独立验证](sci_style_independent_validation.csv)。

## 13. CCW production parity

`CCW_METHOD_CAPABILITY_PARITY = NOT_ESTABLISHED`。
没有在本任务重写 CCW estimator、开放 allowlist 或声称同等级完整 production
CCW 能力；没有 subject-level bootstrap、competing-risk 或 known-truth study
运行记录。绘图补齐和 CI PASS 不改变这个结论。

## 14. Remaining method blockers

缺少公共可执行且正式验证的 clone/strategy/grace/adherence/censor pipeline、
time-varying IPCW、适用的 stabilization/truncation、subject-level inference、
weighted KM/CIF 与 competing risks、所声称的 RMST/RMTL/bootstrap、grace
sensitivity 和 subgroup CCW。未来 independent comparator、手工 oracle、
known-truth、bootstrap、runtime/publication gate 见
[缺口与验证计划](ccw_production_parity_gap_and_validation_plan.md)；该计划是未来
候选要求，不是已批准统计方案或已执行验证。

## 15. Recommended PR structure

[PR #2](https://github.com/secdelic/tte-method-library/pull/2) 保持 STYLE ONLY，
当前 head 741b73a：人工 style PASS、retention 完成、两项 CI SUCCESS、统计
不变性 PASS，可建议 READY_FOR_REVIEW，由研究者决定 merge。
新能力分支为 feature/publication-figure-capability-v1.2，独立 Draft PR 以
feature/sci-figure-style-v1.1 为 base，避免在 capability diff 重复整套 style。
新 PR 的线上验证以其当前 head checks 为准；本地验证结果如上。
若以后明确授权合并 PR #2，再核对/retarget capability PR 到 main。
本轮没有 merge、Release、改 tag、升级 stable VERSION 或改动原始 dirty checkout。

## 16. Final status

```text
SCI_STYLE_READY_FOR_HUMAN_MERGE_DECISION
FIGURE_CAPABILITY_PARITY_READY
CCW_METHOD_PARITY_NOT_ESTABLISHED
```

任务范围内的技术结果已形成可审阅候选；研究者保留科学采用和 merge 决定。
外发表面检查单独记录在 [surface audit](publication_capability_final_external_surface_audit.md)，
不改变统计或人工批准状态。检查范围内没有需处理的非预期残留，但不能可靠
检查的潜在像素 provenance/watermark 和 SVG glyph text extraction 明确列为
UNCHECKED_SURFACES；不以关键词零命中宣称没有 AI 使用。
