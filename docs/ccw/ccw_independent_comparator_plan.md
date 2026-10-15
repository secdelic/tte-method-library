# CCW 独立数值 comparator 计划

日期：2026-10-15。状态：`CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL`。
本轮仅制定计划。以下 comparator 是候选，不是运行结果；具体方法/版本/容差
均须与 [authority](../../governance/CCW_SCIENTIFIC_AUTHORITY_V1.yml) 同步冻结。

## 独立性和匹配范围

比较器不得调用待测 CCW 的 helper、风险集构建器、cloning、权重或积分函数来生成
自身 expected。它读取冻结原始合成输入和科学规范，独立形成中间量；仅共享输入
格式和事先批准的科学定义。相同软件包被两边调用不能作为该算法自身的独立证明。
还需 hand oracle、独立真值及外部统计审阅。

| 对象 | 独立比较来源 / 方法 | 必须一致的条件及证据 |
| --- | --- | --- |
| Clones / strategies | 人工列出的 unit-strategy map；独立笛卡尔枚举 | 资格、策略数、每 subject 多 units 和重复抽样身份；逐键精确一致 |
| Grace / censoring | 独立逐行状态表和边界案例，不调用引擎的 event sorter | 起止闭开、time zero、同刻优先级、terminal event、无 post-censor contribution |
| 条件概率 | 对预先给定系数独立算 logistic/link；对拟合模型另行验证设计矩阵、得分/似然、拟合预测 | 同一合法风险集、时间基函数、历史信息、编码、link；仅再次调用同一 glm 不充分 |
| Cumulative IPCW | 独立乘法/对数乘积及精确分数 oracle | probability orientation、乘积上下限、事件时点使用的权重、人工/自然删失分量 |
| 稳定/截尾权重 | 独立 numerator/denominator 比、按冻结分组与算法求 cutoff | 截尾发生在区间/累乘/稳定后的哪一步；策略/时间/插补 domain；不能继承 type=3 默认 |
| Weighted KM | 手工 product-limit；适用时独立 `survival::survfit` | entry/exit/ties、时间变化权重、weight scale、initial state、无风险集后的可估计范围 |
| Weighted CIF | 手工加权原因分子/总风险集递推与独立 product-integral；适用时 `survfit` multi-state | 相同原因编码、吸收状态、事件顺序、时变权重和支持范围；检查所有 CIF 与 event-free survival |
| RD / RR / survival difference | 独立同 horizon 的标量差/比，联合 bootstrap 对比另验 | 同一总体/参考策略；零分母不可随意加常数；曲线取值约定一致 |
| RMST / RMTL | 手算矩形和或独立高精度积分 | 起点/horizon、单位、步阶、selected survival 或 cause-specific CIF；不默认线性插值 |
| 条件固定权重 variance | 适用的独立影响函数/包结果或可解析极小例 | 仅覆盖对应条件方差；标明未包含 nuisance estimation，不作为完整 CCW CI gate |
| Full-refit variance / CI | 独立 subject 抽样索引与 refit 路径、可枚举小样本重复抽样、已知真值覆盖率 | 同时保留两策略和全部 units；冻结 CI 方法/变换、MI 嵌套、失败政策；联合 contrast 协方差 |
| Subgroup / sensitivity | 独立成员资格与每个预设 scenario 的完整路径 | interaction 的效应尺度与零假设；共享 subject 抽样；不能用组内显著性差异替代交互检验 |
| CCW+MI | 完成数据的逐插补独立结果和按冻结规则独立 pooling | 插补时序、事件信息、m、within/between uncertainty 和 bootstrap nesting 均单独验证 |

## 可检查公式（条件定义，不是模型选择）

对于已冻结风险集和事件前合法权重，在一个吸收 competing-risk 场景，令
`Y_w(t)` 为加权在险质量，`dN_wc(t)` 为原因 c 的加权事件数。
概念性 oracle 为 `dLambda_c(t) = dN_wc(t) / Y_w(t)`，
`S(t) = S(t-) * [1 - sum_c dLambda_c(t)]`，
`F_c(t) = F_c(t-) + S(t-) * dLambda_c(t)`。
初始状态、权重时间、ties 与无在险时的行为须人工冻结；不能套用公式掩盖不匹配风险集。
只有一个结局原因时才退化为相应 KM；有竞争事件时将其普通删失后的 `1-KM`
不作为 cause-specific CIF comparator。需检查概率界、单调性和
`S + sum(F_c) = 1` 在被批准状态/支持范围内成立。

同一 curve 的 RMST 为限定 horizon 的 survival 面积；all-event time lost 为其补集面积。
原因 c 的 RMTL 可定义为 CIF_c 面积，但定义尚待选择，不以命名推断。
独立积分纳入区间端点、首段、最后部分区间和 t=0 事件，禁止悄然向无数据区间外推。

## 官方包接口核验

2026-10-15 查阅的 [survival 官方 `survfit.formula` 文档](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/survfit.formula.html)
说明 product-limit / multistate 计算、`weights`、`id`、`cluster` 和 robust variance 接口。
[对象文档](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/survfit.object.html)
说明 `surv` / `pstate` 及加权 `n.risk` 等字段的含义。
本仓库 lockfile 记录 survival 3.8-6；这不是本轮执行 comparator 的声明。

在采用前，必须独立验证所需 start-stop、逐时权重和事件排序能被该接口精确表达。
如不支持某个 profile，明确记 comparator 不适用，另行人工批准独立公式实现；
不能更换 estimand 来匹配包结果。不得让包默认 `na.action` 静默删除输入。
`n.risk` 的加权和不能重标为患者人数；原 subject/analysis unit/clone count 另行统计。
包给出的 robust variance 不自动涵盖先前估计 IPCW 的全流程不确定性。

## 容差、验收和留证

所有 numeric tolerances、拟合收敛判据、bootstrap CI 方法、package pin、
truth approximation error 和 Monte Carlo 接受界限为
`HUMAN_SCIENTIFIC_DECISION_REQUIRED`。连续误差按绝对与相对尺度联合检查；
整数/状态/风险集严格一致，不能用总误差平均掩盖一条错误路径。

每项比较记录输入/规范版本、独立实现来源、内部 helper 依赖审计、逐项误差、
适用范围和失败原因。比较器自身先由可解析例和 hand oracle 验证，
随后才评估待测模块。CI 的最终有效性另由预设 known-truth 仿真检查。
当前全部比较均 `NOT_RUN`，不存在“已有绘图因此统计等价”的结论。
