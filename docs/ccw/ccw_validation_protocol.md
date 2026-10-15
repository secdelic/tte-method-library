# CCW 验证协议草案

日期：2026-10-15。状态：`CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL`。
本轮完成验证设计，不执行 CCW、oracle、comparator、bootstrap 或 known-truth simulation。
所有尚未选定的科学/验证参数为 `HUMAN_SCIENTIFIC_DECISION_REQUIRED`。
本文的“必须”是未来验收要求，不表示已经运行或获得 PASS。

## 冻结对象与启动门

1. 人工解决 [authority](../../governance/CCW_SCIENTIFIC_AUTHORITY_V1.yml) 的关键字段，明确批准的合成 profile 范围和真实项目边界。
2. 冻结输入 schema、事件排序、模型、estimands、方法域以及 [simulation plan](ccw_known_truth_simulation_plan.md) 的 DGP、真值、样本量、seeds、重复数和门限。
3. 冻结 [comparator plan](ccw_independent_comparator_plan.md) 的适用范围、版本、公式、容差、oracle 表和独立审阅记录。
4. 记录批准人、日期、文件内容身份、批准范围和排除项。记录须绑定被审核版本；修改科学内容后重新审核受影响范围。

当前无已批准的 scientific profile。`scientific_fields_frozen: false` 与
`implementation_authorized: false` 不是可被工程人员自行翻转的完成标志。
批准记录的摘要不包含摘要字段本身，避免自引用；冻结时明确被签署文件集合及计算范围。

## 验证层次与实际证据

| 层次 | 必要证据 | 不足以替代它的证据 |
| --- | --- | --- |
| 输入/单位/时间 | 缺字段、重复/孤立 ID、未来信息、反向时间、错误编码的拒绝案例；合法多 units 和时变 history 接受案例 | 一个 CSV 可读或旧 baseline validator PASS |
| Clone / censor oracle | 独立人工枚举的逐条 ledger，整数/类别精确一致 | 测试直接调用待测 helper 得到 expected |
| IPCW oracle | 手算风险集、条件概率、乘积、截尾位置及边界；拟合失败可见 | 最终权重直方图看起来合理 |
| Outcome comparator | 同一科学定义下逐时 survival/CIF、RD/RR、积分及支持边界一致 | 曲线图重合或与真实论文效应数值相近 |
| 完整推断 | subject bootstrap 抽样映射、全部必要 refit、联合对比不确定性和失败账目 | fixed-weight SE 或克隆独立 bootstrap |
| Known truth | 预设所有场景的 bias、RMSE、SE/SD、95% coverage、tails、failure 和 MC uncertainty | 无真值实证结果、单个大样本或平均值掩盖失败场景 |
| Reproducibility | 相同输入/版本/seeds 重跑；并行度变化不改变抽样身份和结果在冻结容差内 | 仅 set.seed 或一份截图 |
| Scientific / canary | 独立统计审阅、获准真实项目的端到端 canary、明确人工批准 | 合成 PASS、CI 工作流 PASS、图形已获审阅 |

## Hand-enumerated oracle 设计

使用极小、全合成、可逐条核算的数据。个体与次数在冻结时确定；不能从 benchmark 的
真实个体或展示 fixture 复制临床值。至少枚举以下 histories 及交叉情形：

- 无治疗、grace 前/边界/后治疗、恰在 time zero 治疗；早期结局尚未观察到策略完成。
- 治疗与结局同刻、结局与竞争事件同刻、grace 结束与自然/人工删失同刻。
- 不同策略的兼容/不兼容路径、grace 后依从性、非完整末区间。
- 无删失、自然删失、人工删失、竞争事件；风险集耗尽和 horizon 无支持。
- 相同 subject 多 analysis units、同一 subject bootstrap 重复被抽中。
- 概率为边界或模型分离、某策略无事件、RR 分母为零、缺失/晚可用协变量。

逐行登记 original subject、unit、clone/strategy、interval、可用 history、风险集成员、
候选事件、按批准优先级选出的动作、删失概率、numerator/denominator 乘积、最终权重、
事件贡献。逐时手算 weighted mass、事件分子、曲线、积分和联合对比。
oracle 应先于待测实现运行独立记录和审核，采用精确分数/高精度计算或明确误差界。
同刻排序尚未批准，不能先造一个 expected 再把它称为已冻结规范。

## 数值容差与失败分类

整数/身份/状态/风险集键必须完全相同；连续量使用预先批准的
`abs(candidate - reference) <= atol + rtol * abs(reference)`，
近零量以绝对误差为主；不同单位/积分尺度分别冻结容差。
`atol`、`rtol`、优化收敛判据和允许的 truth approximation error 尚未选择。
不修改现有 baseline/MI expected values 和 tolerance 来通过 CCW 检查。

区分 contract failure、model nonconvergence/separation、positivity failure、
empty risk set、undefined estimand、CI unavailable、comparator mismatch。
记录原错误、影响范围和预设处理；不得宽泛捕获后改模型、删样本或返回成功。
实现 bug 的修复保留旧结果并重跑受影响的全部冻结测试；科学方案或验收门改变需要
新版本及先于新评估的人工决定，不能覆盖失败历史。

## Bootstrap 验证

以 original subject 抽样，每个 draw instance 保留该 subject 全部 units/history/clones，
两个策略共用同一抽样。核对同一 subject 重复抽中时的乘数、clone ID 和 cluster 归属。
每次按 authority 完整重拟合必要 imputation、censoring numerator/denominator、
数据依赖截尾、outcome、contrast、积分及适用 subgroup/sensitivity。

独立检查抽样索引和所需拟合的输入/输出变化；区分固定模型诊断和 full-refit evidence。
每个尝试保留 seed、ID、阶段、状态、原因。批准的重复数是 attempts 还是有效目标，
是否允许补抽及最大尝试数必须先明确。若批准目标为 1000 个有效结果而未达到，
报告真实 attempted/valid/failed/nonestimable 数并保持门未通过，不能删掉失败记录补称 1000。
所有策略/结局/对比须明确其有效集合，避免不同可估计集合造成选择性比较。

## Missing data 与 CCW 专门验证

审核插补相对于 eligibility、cloning、outcome history 和 bootstrap 的顺序；
分别列 baseline、postbaseline、时变变量、事件/时间/删失信息的角色和可用性。
冻结 m、迭代、predictor matrix、方法、seeds、diagnostics、每个插补完整 CCW、
pooling 的 estimand/变换尺度和 bootstrap/MI nesting（如适用）。
以完整数据 oracle、已知 missingness 的独立 DGP 和每插补 ledger 核对。
不得将当前 continuous ATE 的 Rubin 测试作为 CCW+MI 证据，不能选“最佳”插补，
不能把缺失机制不支持的策略默认为有效。

## 风险、生产边界和停止条件

研究者报告既往 CCW 小样本 RMST CI 校准未全面通过。当前公开树未找到该次原始
场景、估计、覆盖率或失败文件，具体证据为 `UNKNOWN`，不能补造失败数字。
冻结前要求可追溯的历史记录，或明确记录无法取得并由人审定新增预设复核范围；
这不等于历史问题已解决。点估计和 CI 分开审核。

variance/CI gate 不通过时，不能把 RMST CI 放入 production allowlist；
可供人审议更窄的已验证范围，但不自动变更范围、算法、样本量门限或覆盖率门。
整个项目满足 [production checklist](../../reports/ccw_production_gate_checklist.csv)
后才可建议候选批准，任何代码/绘图/基线回归 PASS 都不能宣布 CCW parity。

本轮停止于 authority/计划交付。所有 CCW 数值执行门均为 `NOT_RUN`，
人工冻结、统计审阅与科学采用保持 `PENDING`。
