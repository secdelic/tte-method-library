# CCW known-truth simulation program（冻结前草案）

日期：2026-10-15。状态：`CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL`。
本轮没有编写或运行 DGP、拟合器或仿真。下列场景是验收设计需求，
参数、真值、seeds、次数和接受门限尚未冻结，不能称为“仿真已通过”。

## 必须先冻结的清单

| 冻结字段 | 当前值 / 要求 |
| --- | --- |
| 目标验证 profile 和 estimands | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；人审批准的合成验证范围，非真实研究方案 |
| DGP 完整分布和参数 | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；baseline、subject effect、units、L(t)、A(t)、事件和观测/删失过程 |
| 策略及 grace 内 initiation distribution | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；不能只规定“窗口内治疗”却未确定目标干预分布 |
| 真值及求解精度 | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；各策略、原因、horizon、对比、RMST/RMTL；无待测引擎参与 truth |
| 样本量和 cluster 结构 | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；subject 数及每人 units 分布，不能只写 clone row 数 |
| Seeds / streams | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；data、truth、bootstrap、MI 独立可复现流 |
| Outer replications 和每次 bootstrap/MI 次数 | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；区分仿真次数与 bootstrap 次数，失败账目不互相替代 |
| 点估计、SE、coverage、tails 的门限 | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；按 estimand/场景/单位，含 MC 不确定性的判定规则 |
| MC 精度目标 / truth error budget | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；先据精度设计重复数，不用结果决定何时停 |
| Failures、retry、不可估计与支持域 | `HUMAN_SCIENTIFIC_DECISION_REQUIRED`；正常验证场景和故意失配/stress 场景分开规定预期 |

计划结构采用 aims、DGP、estimands、methods、performance measures；报告
Monte Carlo uncertainty，而非把一次仿真估计当真值。
参考 [Morris, White & Crowther, 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6492164/)
（DOI 10.1002/sim.8086），用于验证设计，不代替本项目门限审批。

## 独立 DGP 与真值路径

候选构造包括可解析离散时间吸收状态模型，以及有限状态、可精确枚举的纵向 DGP。
每一 original subject 可先生成共同的 latent/observed cluster 特征，
再生成其全部 analysis units；L(t)、A(t)、事件类型和记录可用性依照预先规定的
时间序生成。由过去治疗影响未来 L(t) 的场景单独定义，不把自然治疗关联当作因果真值。

真值在明确干预策略下，通过独立状态转移递推/全枚举对所有合法 histories 积分，
而非读取拟合 CCW 的平均值或把 hazard 系数当作 marginal RD/RR。
复杂 DGP 若只能用独立超大参考样本近似，则单独冻结参考样本量、seed 和精度预算，
报告 truth error；未达到精度不得标为 exact known truth。
验证用 observation/censoring 过程与生成 full counterfactual outcomes 的真值路径分离。
grace 策略的干预分布和自然 initiation 支持域须一致且有定义，不能仅令 censor 权重为一。

生成器只输出真实生成的合成记录，保留完整时间/缺失信息，不调用待测 CCW helper。
疾病、数据库和临床阈值均不从 benchmark 自动继承。

## 最低场景矩阵

下表“预期检查”是冻结需求；具体数值都仍为 `HUMAN_SCIENTIFIC_DECISION_REQUIRED`。
主验证场景在正确模型/识别假设下验准确性；故意失配的 stress 场景验失败识别或
预先声明的稳健性范围，不要求错误模型也恢复真实效应。

| ID | 场景 | 真值/预期检查 |
| --- | --- | --- |
| S01 | Null effect | 两策略 counterfactual estimand 相同；差值真值 0、适用且分母非零的 ratio 真值 1；其余参数待冻结 |
| S02 | Nonzero effect | 用明确干预分布独立求 marginal contrasts；不把模型系数当风险差 |
| S03 | No censoring | 在已定义策略下不存在人工/自然删失的合法退化情形；检查 q=1、权重和曲线退化，不把有偏离的 clones 强行保留 |
| S04 | Informative artificial censoring | 偏离与预后历史相关且满足所声明识别条件；正确重加权恢复目标，无权重路径仅作预设诊断 |
| S05 | Competing events | 两个或更多吸收原因的真值递推；每原因 CIF、event-free survival、CIF area 和对比 |
| S06 | Time-varying confounding | 既往治疗影响后续 L(t)，L(t) 影响治疗/删失与结局；检查合法信息和正确模型 |
| S07 | Different grace periods | 每个预设窗口有自己的策略/目标真值；变化窗口不能被当作只改坐标轴 |
| S08 | Treatment/event/boundary ties | 离散质量产生同刻事件；按冻结顺序计算真值及 oracle，不 jitter 时间 |
| S09 | Poor positivity | 接近零保持概率及结构性零支持分别设置；报告 ESS/极端权重/不可识别，不自动截尾使其通过 |
| S10 | Sparse events / small subjects | 无事件和单侧事件、稀疏对比、RMST/RMTL 区间校准及不可估计率；保留失败尾部 |
| S11 | Multiple units within subject | 显式单位内/同 subject 相关性和目标加权；按原 subject 抽样，验证 clone dependence |
| S12 | Model misspecification | 分别遗漏 time basis、历史项或交互等预先选定失配；与正确模型分开，禁止按结果挑方法 |
| S13 | Missingness with CCW | 按获准机制、时序与方法生成缺失；逐插补结果和 pooling/MI-bootstrap 嵌套分别验证 |
| S14 | Natural censoring and incomplete horizon | 正确独立/需加权删失及无后续支持边界；无法估计的 horizon 不外推 |

冻结时说明哪些因素交叉、哪些仅单独场景，预先列出完整 scenario 清单；
不能把一项通过推广为所有组合通过。先做冻结的确定性极小 oracle，再做 smoke、
完整 point-estimate 和 CI 校准计划。smoke 不生成生产 PASS，且不能被用来调整主验收门。

## 指标、分母和 Monte Carlo 误差

设 M 为预设 outer attempts，V 为可估计点估计集合，C 为有效 CI 集合，
真值 theta 已独立冻结。每个 estimand/scenario 分别报告：

- bias：`mean(theta_hat - theta)`，MCSE 为该误差的样本 SD / sqrt(|V|)。
- relative bias：`bias / theta`；theta=0 时 `NOT_APPLICABLE`，不添加任意 epsilon。
- RMSE：`sqrt(mean((theta_hat-theta)^2))`，保留其 MC uncertainty 估计方法和分母。
- mean reported SE 与 empirical SD：明确各自可估计集合；比较时额外给相同完整集合的值。
- 95% CI coverage：`mean(lower <= theta <= upper)`，同时报告 |C|/M 和失败分类；只有成功重复中的 coverage 不能单独满足生产门。
- tail imbalance：分别报告 theta 低于 lower 与高于 upper 的概率/计数，不能只报合计 coverage。
- convergence、positivity、empty risk set、undefined contrast、CI failure：各自数量/比例，保留逐重复日志。
- ESS、概率边界、极端权重和截尾比例：按策略/时间/插补展示分布，区分 clone/unit/subject 单位。

coverage/tail 的二项近似 MCSE 为 `sqrt(p*(1-p)/n)`，零或一的估计还应给
适当的二项区间；具体 MC 区间和 gate 判定须预先批准。
重复数可依据预设 MCSE 目标 e，用规划式 `p0*(1-p0)/e^2` 确定需求；
e、规划 p0 及舍入规则尚未选定。bias、RMSE、SE/SD 和 tails 的误差方法同样在运行前冻结。
若真值是近似值，要把 truth uncertainty 纳入误差预算，不用更宽的结果后 tolerance 掩盖它。

另外报告 `covered_CI_count / M` 这一包含失败分母的成功交付率，
明确它不是成功条件下 coverage 的同义词；不能将失败随意计为科学上“不覆盖”而不说明。
failure gate 与 conditional coverage gate 必须同时满足；不补抽到获得有利 coverage 为止。

## 既往 RMST 风险及变更规则

研究者明确报告“既往 CCW 小样本 RMST 区间校准未全面通过”。当前公开树无可复核的
原始失败明细；历史场景、CI 方法、样本量和失败率均为 `UNKNOWN`。
应先取得历史记录并冻结回归场景，或由研究者明确记录资料缺口和新复核范围。
不得声称重新运行过历史测试，不得以新大样本结果覆盖小样本缺口。

RMST 点估计、RMST CI、RMTL 点估计、RMTL CI 分开验收。
若 CI 仍失败，只能提出限制生产适用范围的候选，由人批准；未验证 CI 不入 allowlist。
每个新场景/门限/方法/样本量域修订保留旧版本及失败理由，必须在重新评价前批准。
此计划当前没有任何数值执行结果，不能赋予 `CCW_METHOD_PARITY_VALIDATED`。
