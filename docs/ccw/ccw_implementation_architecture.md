# CCW 实现架构（待人工冻结）

日期：2026-10-15。状态：`CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL`。
本文件是实现计划，不是已实现 API。关键科学字段未冻结，本轮不新建 R 引擎、
模拟生成器、可执行 comparator 或 runtime profile。
[Scientific Authority](../../governance/CCW_SCIENTIFIC_AUTHORITY_V1.yml) 是待审核入口。

## 当前边界及复用

审计基线为 `main` 的 `56c6314689aee66b2de588ac773c8770ca5be346`。
[registry](../../runtime/production_registry.csv) 仅批准两个 ATE profile；
[runtime](../../R/core/runtime.R) 只分派 baseline / MI。
[现有输入验证](../../R/core/input_validation.R) 要求 subject 和 analysis ID 各自唯一，
不适用于同一 subject 多个 analysis units。未来 CCW 应有独立适配器，不能放松旧 profile 的契约。

可复用的工程原语包括 I/O、配置读取、告警记录、表格/绘图接口和输出目录约定。
现有 PS、权重截尾、Rubin pooling 及 SMD 代码只能作为审阅材料，
不能把 baseline PS 权重改名为 IPCW，也不能直接继承其科学默认值或验证资格。
不得触动冻结 baseline/MI estimator、expected values、tag、lockfile 或已有图形风格。

## 依赖与模块边界

规划的数据流为：已冻结 authority 与六类输入 → 输入/时间验证 → 缺失数据按批准顺序处理
→ cloning → 策略依从性和删失 → IPCW → 结局估计 → 联合对比和全流程推断
→ 诊断、敏感性和合法聚合图表。MI 的具体位置尚未选择，冻结前不能把此图当作 MI 顺序。

| 规划模块 | 输入及输出 | 核心不变量 / 拒绝条件 |
| --- | --- | --- |
| Authority / input adapter | authority、analysis_spec、dictionary、manifest、baseline、longitudinal、events → 经验证的对象 | 未批准、哈希不符、未解决字段或未授权 profile 均拒绝；保留输入，不静默修复 |
| Missing-data adapter | 按批准时序使用未克隆 subject/analysis histories 或其他明确方案 → 全部插补和日志 | 不选择最佳插补；克隆一致性、因果变量时序与插补预测信息分别验证 |
| Clone / strategy engine | 合格 analysis units、明确策略清单 → clone map、基线复制和策略身份 | original subject ID 永久保留；每个被允许的 unit-strategy 配对唯一；克隆不成为独立受试者 |
| Grace / censor engine | longitudinal 和 event histories、策略规则 → 分期状态表、贡献表、删失原因 | 每个边界/同刻事件按冻结顺序；终止后的原始记录可存档，但不得贡献模型或结局 |
| IPCW engine | 未删失风险集、合法协变量历史、冻结模型 → 条件概率、累乘权重、拟合日志 | 明确概率指向 censor 还是 remain uncensored；明确权重是事件前还是区间后；无收敛/零概率不自动换模型 |
| Weighted outcomes | 独立的 endpoint 风险集、事件、权重 → survival / CIF、计数和积分 | CIF 与 event-free survival 状态一致；竞争事件不可作为普通删失后输出 1-KM |
| Contrasts | 同一批准总体/时点/策略顺序的估计 → RD、适用时 RR、survival difference、RMST/RMTL contrast | 对比方向和时间单位固定；RR 零分母按预设不可估计规则；不能由组间 CI 推导差值 CI |
| Inference | original subjects、全部 histories、authority → 完整重拟合分布与失败账目 | 克隆与同 subject 的 units 一起抽样；两策略共用同一重抽样；必要 nuisance models 均重拟合 |
| Subgroup / sensitivity | 预设 scenario IDs、单位成员资格和规则 → 完整结果矩阵 | 每个方案依其规则重新克隆/删失/拟合；不按显著性排序或筛选；interaction 需直接推断 |
| Aggregation / figures | 上述实际计算对象及合法聚合表 → plots、tables、provenance | 图形输入不得来自展示 fixture；计数单位与权重质量分离；私有行级轨迹不自动外发 |

以上是责任划分，不要求为每一行创建框架、插件或单独包。批准后按最小必要模块实现。

## Clone 和时间状态

内部身份拟包含 original subject、analysis unit、strategy、clone、period。
bootstrap 时增加 draw-instance 身份：同一 subject 被抽到两次，是两个抽样副本，
每份均携带全部 units 和策略克隆，不能因 original ID 相同而去重或误合并。
analysis unit 的目标加权方式（每 subject 还是每 episode 等）仍需人工决定。

对每一 clone-period 保留：起止时点、区间前状态、可用协变量、策略兼容判断、
人工/自然删失候选、结局/竞争事件、最终优先事件、贡献标记、原因及原始记录键。
不能凭时间排序器自动确定同刻优先级，也不能假定所有结局共享一套终止条件。
完整原始 history 可含终止后观测，但 contribution table 必须保证没有终止后贡献。

## IPCW 和诊断

在冻结条件下，令 q_den 为适当风险集上的条件“保持未删失”概率；
未稳定权重的概念形式为对应时点允许乘积范围内的 `1 / product(q_den)`，
稳定形式为 `product(q_num) / product(q_den)`。是否使用稳定化、哪些过程需加权、
乘积从何时到何时以及是否在 grace 后继续更新，全部由 authority 决定。
这是验证对象的符号说明，不是批准某种模型或默认权重。

输出需逐策略、时间、插补和 bootstrap 复核风险集、概率范围、分离/收敛、
原始/稳定/截尾权重、分位数、ESS、权重最大值和质量集中程度。
ESS 的权重单位必须明确；clone-row ESS 不能声称独立 subject 信息量。
interval balance 的目标总体、协变量可用性、参照分母和阈值先冻结；
对未来存活者条件化或对治疗后变量作错误平衡解释须避免。

## 结局与推断

候选验证对象包含有适用条件的 weighted product-limit survival，
以及吸收竞争事件下的 weighted Aalen-Johansen/CIF；最终选型尚未批准。
积分采用冻结的曲线状态和步阶约定；`tau - RMST` 仅在同一起点、同一 horizon、
同一 survival 的补集定义下等于 all-event time lost。
某原因的 `integral CIF_c(t) dt` 不能自动换成 `tau - RMST`。

全流程 subject bootstrap 重新执行所有必要阶段，含批准的 imputation/nuisance refit、
数据依赖截尾界值和统计量。条件在固定权重上的 package SE 只验证该受限对象，
不能替代包含权重估计不确定性的 CCW CI。
所有抽样尝试、拟合失败、无事件、无支持 horizon 和不可估计对比均记录。
申请的次数、尝试数、有效数和失败数分别报告；1000 次这一论文数值不成为本项目默认值。

## 结果绑定到 publication figure APIs

基线已有 [publication_figures.R](../../R/figures/publication_figures.R)。
另行审计的 [PR #3](https://github.com/secdelic/tte-method-library/pull/3)
在 `e2bfc319f293e0168b67cd8459c66166f664cb8f` 提供新的展示 API，
但该候选未合并，不属于本分支可运行依赖；本轮不 cherry-pick PR #2/#3。
未来接入须核验当时获准版本，单独验证 adapter。

| 输出图表 | 未来绑定的数据 | 可用/候选 API 与限制 |
| --- | --- | --- |
| Participant flow | 实际 eligibility/排除/克隆阶段的合法聚合计数 | PR #3 `plot_participant_flowchart`；单位与阶段数量守恒 |
| Actual clone/censor timeline | 引擎产生的实际事件轨迹或获准聚合轨迹 | PR #3 `plot_tte_ccw_timeline`；标注人工/自然删失和竞争事件；不可借展示 fixture 充数 |
| IPCW / balance | 实际概率/权重/ESS 和分期 balance | 现有 `plot_weight_distribution`、`plot_love` 等；需显式时间/策略层，不可只展示最有利时点 |
| Survival / CIF / at risk | 实际估计曲线、已验证 CI、独立整数计数表 | PR #3 `plot_survival_risk_publication`；曲线状态、horizon 和 CI 方法随数据绑定 |
| RD / survival annotation | 实际联合对比及其 CI | 同 wrapper 的 annotation；不得由两条曲线 CI 视觉差异生成推断 |
| Subgroup / sensitivity forest | 所有预设结果及失败状态 | PR #3 `plot_subgroup_forest` / `compose_forest_panels` 和现有 sensitivity forest |
| RMST / RMTL | 已验证积分、单位、horizon、对比及适用 CI | 既有表格/差值 forest；新增专用图并非本阶段要求；未通过的 CI 不展示为正式结果 |

聚合表分别保存 `n_original_subjects`、`n_analysis_units`、`n_clones`、
`weighted_risk_set_mass`；不得对最后一项四舍五入后命名为患者人数。
同一 subject 多个 units 仍在险时，原始受试者计数需去重并说明集合规则。
公开图无需暴露私有 input 路径或行级 ID，内部 provenance 保留实际输入/模型/统计量关联。

## 实现启动和完成条件

先冻结 [输入契约](ccw_input_contract.md)、[验证协议](ccw_validation_protocol.md)、
[独立 comparator](ccw_independent_comparator_plan.md) 和
[simulation plan](ccw_known_truth_simulation_plan.md) 的关键未决字段。
人工批准某个有边界的合成验证 profile 不等于批准真实研究或全部 CCW 方法。
每项生产门见 [checklist](../../reports/ccw_production_gate_checklist.csv)。
可实现、数值等价、区间校准、真实 canary、独立统计审阅及人工采用分别留证。
