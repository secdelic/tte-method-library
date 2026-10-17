# CCW analysis-ready 输入契约草案

日期：2026-10-15；状态：`CCW_SCIENTIFIC_AUTHORITY_AWAITING_HUMAN_APPROVAL`。
以下为待审阅接口要求，尚未实现 parser/validator。列名是建议的标准内部名称，
实际输入映射、科学含义、时间粒度和适用范围必须在
[authority](../../governance/CCW_SCIENTIFIC_AUTHORITY_V1.yml) 冻结。
不得将其传给目前仅支持 baseline/MI 的 runtime，或沿用旧配置的数值默认值。

## 六类输入独立配置

| 输入 | 记录单位 / 建议必需信息 | 关键连接 |
| --- | --- | --- |
| Baseline-wide CSV | 每 analysis unit 一行；original subject ID、analysis ID、资格、time zero、获准基线变量；时序来源可放在附表 | analysis ID 唯一并映射到一个 original subject；subject 可有多个 units |
| Longitudinal / person-period CSV | 每 analysis unit-period 一行；period ID、start、stop、实际治疗状态及其来源、允许的时变 history | 与 baseline 多对一；不预装某个 clone 的“正确”删失决定 |
| Event / outcome information | 独立路径；每事件记录包含 unit、event ID、endpoint/cause code、发生时点、记录可用时点及观测/行政随访结束信息 | 与 baseline 多对一；每 endpoint 的事件规则和是否吸收由 authority 定义 |
| Variable dictionary | 每变量/来源一行；label、role、type、unit、levels/reference、missing codes、合法范围、measurement/availability 映射、模型/插补权限 | 字典引用列必须存在；因果角色及获准用途必须人工指定 |
| analysis_spec | authority 版本/内容身份、全部文件角色映射、时间与编码映射、获准 scientific profile、输出请求 | 与已批准 authority 一致；不可隐式继承 baseline ATE、1-hour 或 24-hour 等默认 |
| Input manifest | 文件角色、路径配置、SHA256、schema version、row count、来源版本、synthetic/real 标记、单位和时区说明 | 一个角色解析到明确输入；实际字节/数量与声明一致；私有路径仅保存在受控运行记录 |

CSV 可在文件间采用不同路径。事件表和随访终止信息可有不同物理布局，但必须
在配置中显式映射为上述语义，不能根据列名猜测。单位/字典/manifest 不能仅靠
文件存在即通过；缺一项必要语义即停止对应分析。真实数据不进入公共仓库。

## ID、clone 与抽样身份

ID 按字符串读取，保留前导零；空值、意外类型转换、映射一对多和孤立外键拒绝。
baseline 的 analysis ID 唯一；允许 subject 重复仅因合法多 analysis units，
不能使用当前 baseline validator 的 subject-unique 假设覆盖该设计。
输入 period 键为 analysis ID + period ID；若有独立 endpoint 风险集，须明确该层。

clones 由引擎生成，不接受未核验的 caller-clone 作为替代。
生成后验证 analysis ID + strategy 的 clone 映射、clone + period 唯一性，
每 clone 保留原 subject/analysis ID。重抽样时使用 draw-instance + analysis ID
+ strategy 区分重复抽中的完整 subject 副本；所有数量检查明确计数层级。

## 时间、信息可用性与终止贡献

绝对时间必须能解析其时区，或采用已声明原点、单位、精度的相对时间；
混用时刻和 elapsed time、缺失时区或未经批准的 rounding 均拒绝。
与 time zero 的转换需可逆追溯，不能对齐失败后自动平移。
interval 的闭开、非等长/最后部分区间、同刻优先级尚未确定，不采用软件默认。

| 验证点 | 预期检查 / 失败处理 |
| --- | --- |
| Interval geometry | start < stop、单调顺序、无未授权 overlap/gap/duplicate；检查 period label 与真实时间一致；零时长事件需单独冻结表示法 |
| Eligibility / time zero | 按获准定义核对资格、baseline、assignment、follow-up 起点；不把“所有时间相等”作为通用规则 |
| Prebaseline events | 区分历史病史与 index outcome；结局在 time zero 前且与已批准 incident-outcome 定义矛盾时拒绝；任何重新分类由 authority 决定 |
| Treatment timing | 实际给药/治疗发生时间、记录可用时间、适用剂量/持续性明确；不得用未来治疗反推 baseline 已治疗 |
| Covariate timing | 每次模型决策只使用对应允许 history：测量时间和真实可用时间均有证据；晚录入值不得因测量较早就自动视为早已可用 |
| Adherence and ties | 同时发生治疗、人工/自然删失、结局、竞争事件或 grace 边界时，需冻结排序；排序缺失为未决错误 |
| Event consistency | 非法二元/原因编码、未授权多终末事件、重复事件及事件后恢复在险拒绝；不同 endpoint 的随访分别处理 |
| Follow-up support | 所有风险集贡献均落在观察窗口和批准 horizon；无后续支持不自动向 horizon 外推 |
| Post-censor data | 原始 history 可保留终止后观测，但分析贡献表在对应 clone/endpoint 终止后必须为零，不把原始记录删掉以掩盖错误 |
| Missingness | 按获准机制/方案识别 sentinel 和 NA；不自动删行、不擅自 carry-forward、不静默改 complete-case |

未来的信息若被允许用于某种 retrospective imputation，也必须单独冻结其适用条件；
“允许插补预测”不自动授予它在较早 censoring model 中作为已观测 history 使用的资格。
时间检查能证明的是输入记录与规则一致，不能独立证明源数据库的真实性或测量可用性。

## 拟定分析中间对象和聚合输出

这些是未来输出契约，本轮不生成伪造的统计结果：

- clone map：original subject、analysis unit、strategy、clone 和对应资格。
- contribution ledger：interval、model-decision time、可用 history 版本、状态、事件/删失原因、风险集和贡献标记。
- weight ledger：模型身份、条件概率指向、numerator/denominator、累积范围、raw/stabilized/truncated 权重、失败原因。
- curve table：endpoint、strategy、time、curve/state、estimate、CI、CI 方法、horizon/support 状态。
- risk-set table：original subject 数、analysis unit 数、clone 数和 weighted mass 分列；每列自带单位与事件前/后约定。
- effect table：endpoint、contrast、reference、scale、horizon、estimate、SE/CI（如获验证）、method、estimability 状态。
- bootstrap / MI ledger：scenario、draw/imputation ID、种子/stream、attempt/valid/failed、失败原因、refit stages；无静默丢弃。

内部行级 ledger 保留用于审计；对外图表仅使用获准聚合。
figure adapter 需按输出版本验证一对一键、曲线状态/时间单位、对比方向和 CI 来源，
不从展示 fixture、四舍五入权重和未知计数补足缺失数据。

## 冻结时必须补齐

未决项为 `HUMAN_SCIENTIFIC_DECISION_REQUIRED`：实际 ID 映射、analysis unit、
每人多 units 的目标权重、科学定义、time zero、时间粒度/边界、全部事件代码、
可用性证据、缺失处理和输出披露范围。批准后才实现最小 parser 和拒绝案例测试。
