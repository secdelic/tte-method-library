# Target Trial Emulation Statistical Analysis Method Library v1.0.0 配置字段字典

> 适用版本：`1.0.0`；Git tag：`v1.0.0`；commit：`998e3c0a83656eae5e3ee8dae909e2edcd2625ec`。
>
> 本字典严格对应 v1.0.0 的 `config_templates/`、配置读取器和验证器。模板中出现某个选项，只表示配置结构能够记录该科学方案，不等于相应方法已经通过生产验证。生产资格只由 `runtime/production_registry.csv` 决定。

## 1. 使用原则

正式研究应把四个模板复制到研究项目自己的 `config/`，填写后冻结：

```text
analysis_spec.yml
variable_dictionary.csv
input_data_contract.csv
figure_config.yml
```

研究者负责研究问题、队列、暴露、结局、time zero、混杂因素、estimand、缺失数据策略和敏感性分析的科学决定。方法库验证结构与部分一致性，并按已注册路径执行；它不会替研究者作因果判断，也不会根据结果改配置。

### 1.1 三类字段要分清

| 类别 | 含义 | 例子 |
|---|---|---|
| 运行器实际读取 | 会直接改变 v1.0.0 生产路径的参数 | `profile`、`missing_data.m`、`runtime_thresholds.max_abs_smd` |
| 验证或治理记录 | 用于冻结方案、结构检查、审计或人工核对 | `scientific_fields_frozen`、`governance.approved_by` |
| 方案描述字段 | 模板可记录，但 v1.0.0 不把它当作任意可执行开关 | `weighting.propensity_model`、`figures.requested` |

**注意：** 不得仅因字段可填写，就认为某个 estimator、design、outcome 或 variance method 已获生产批准。两个正式 profile 的具体限制见主手册。

## 2. `analysis_spec.yml`

来源：`config_templates/analysis_spec.yml`。模板是单分析形式；示例还展示了顶层 `analyses:` 下按 profile 放置多个分析块的形式。运行器同时支持这两种组织方式。

### 2.1 顶层标识

| 字段 | 含义、负责人和示例 | v1.0.0 检查与常见错误 |
|---|---|---|
| `schema_version` | 配置结构版本。模板值为 `"1.0"`。由项目维护者记录。 | 模板包含该字段；当前 validator 不强制其值，也不会执行完整 schema 枚举校验。不要把软件版本 `1.0.0` 写到这里。 |
| `profile` | 单分析配置的生产 profile，例如 `BASELINE_BINARY_RISK`。由统计方案确定。 | 单分析形式必须与运行调用中的 `profile` 完全一致。正式可用只有注册表中的两个 profile。 |
| `analysis_id` | 研究者定义的分析标识，如 `primary_28day_ate`。 | 应唯一、稳定、可审计；当前运行器不自动生成或全局查重。 |
| `scientific_fields_frozen` | 科学字段是否已冻结。Canary/Formal Candidate 必须为 `true`。 | `CANARY` 与 `FORMAL_CANDIDATE` 下为 `false` 会使合同验证失败。`SYNTHETIC_TEST` 可用于合成示例，但不能替代正式冻结。 |

多分析文件可采用：

```yaml
schema_version: "1.0"
scientific_fields_frozen: true
analyses:
  BASELINE_BINARY_RISK:
    scientific_fields_frozen: true
    # 其余字段同下
```

### 2.2 设计与人群

| 字段 | 是什么、由谁决定、示例 | 方法库会检查什么 | 方法库不会判断什么 |
|---|---|---|---|
| `design.type` | 设计类型。模板列示 `<baseline_tte|longitudinal_tte|ccw|lmtp>`。由研究者冻结。正式 profile 示例使用 `baseline_tte`。 | `design`块必须存在；当前 validator 不对 `type`做完整枚举/生产资格校验。 | 不会因填入 `ccw`/`lmtp` 就赋予生产资格；也不会判断设计是否能识别因果效应。 |
| `design.analysis_population` | 分析人群的稳定名称，如 `eligible_icu_admissions`. | 运行器把它写入主结果表的 `analysis_population`。 | 不会检查纳排标准的临床合理性。 |
| `population.id` | 分析单位标识变量。v1.0.0 示例为 `subject_id`。 | 必须已解析；与字典 `population_id` role 对齐。实际输入还固定检查 `subject_id` 非缺失且唯一。 | 不会决定患者级、住院级或 ICU stay 级应选哪一种。 |
| `population.cluster_id` | 聚类标识；无聚类时 `null`。 | 若提供，合同对齐检查要求字典 role 为 `cluster_id`。 | v1.0.0 两个生产 estimator 不因填写该字段而自动实施任意 cluster-robust 分析。 |
| `population.eligibility_variables` | 与资格和 time zero 对齐有关的变量列表，如 `[eligibility_time]`。 | 与字典 `eligibility` role 对齐。输入验证固定要求 `eligibility_time == time_zero`。 | 不会定义或验证完整临床纳排规则。 |

### 2.3 Time zero、治疗策略、宽限期与随访

| 字段 | 含义与示例 | 实际检查/限制 | 常见错误 |
|---|---|---|---|
| `time_zero.variable` | time zero 变量，如 `time_zero`。研究者决定。 | 必须已解析；字典 role 应为 `time`。输入时间必须为含时区的 ISO-8601。 | 用暴露后时间作 baseline；时区缺失；与资格时间不一致。 |
| `time_zero.definition` | 临床和操作性定义文字。 | 字段存在但不会被代码转成队列规则。 | 只写变量名而没有临床定义。 |
| `treatment.variable` | 二元 treatment 变量，示例 `treatment`。 | 必须已解析；字典 role 为 `treatment`；实际数据必须非缺失且为 `0/1`。 | 用 `1/2`、`yes/no`，或未明确 reference。 |
| `treatment.definition` | 治疗的操作性定义。 | 作为冻结方案记录；不会自动执行数据库定义。 | 把未来信息或结局后信息纳入 treatment。 |
| `strategies[].id` | 每个策略的稳定标识，如 `treatment_1`、`treatment_0`。 | 顶层 `strategies` 必须存在；当前验证器不逐项验证 id 语义。 | 策略与 treatment 编码不一致。 |
| `strategies[].definition` | 每个策略的文字定义。 | 记录用途。 | 将策略描述当成会被运行器自动解析的规则。 |
| `grace_period.enabled` | 是否设宽限期。生产示例为 `false`。 | 字段结构必须存在。 | 误以为设置 `true` 就会启用 CCW；两个生产 profile 均不是已批准 CCW 路径。 |
| `grace_period.start` / `end` / `unit` | 宽限期边界与单位。无宽限期时可为 `null`/`not_applicable`。 | 当前两个生产 estimator 不执行宽限期逻辑。 | 在基线 profile 中填写但没有相应 estimator 支持。 |
| `follow_up.start` | 随访起始变量，示例 `followup_start`。 | 实际输入固定要求 `followup_start == time_zero`。 | 随访开始晚于 time zero 而未采用相应设计。 |
| `follow_up.end` | 随访结束变量，示例 `followup_end`。 | 必须晚于 `followup_start`。 | 时间倒序或缺少时区。 |
| `follow_up.administrative_end` | 行政随访截止的方案描述；可为 `null` 或文字。 | 当前不据此自动截断数据。 | 把文字描述当成已执行的数据裁剪。 |
| `follow_up.unit` | 随访单位，如 `days`。 | 记录用途。 | 图表/报告使用不同单位。 |

输入数据固定需要以下时间列：`eligibility_time`、`time_zero`、`treatment_assignment_time`、`followup_start`、`followup_end`。前四个时间点在 v1.0.0 生产输入合同中必须对齐，`followup_end` 必须更晚。

### 2.4 结局与 estimand

| 字段 | 含义与负责人 | v1.0.0 生产限制 | 注意 |
|---|---|---|---|
| `outcome.variable` | 结局变量，示例 `outcome`。研究者预先定义。 | 必须已解析并与字典 `outcome` role 对齐。 | 方法库不定义结局窗口或临床意义。 |
| `outcome.type` | 模板可记录 `binary`、`continuous`、`time_to_event`、`competing_risk`。 | `BASELINE_BINARY_RISK` 仅批准非缺失二元 `0/1`；`MI_PS_CONTINUOUS_ATE` 仅批准非缺失 numeric continuous outcome。后两种模板值不代表生产批准。 | 类型与实际编码不一致会失败或产生错误解释。 |
| `outcome.definition` | 操作性定义文字。 | 记录用途，不执行数据库提取。 | 含糊地写“死亡”而不说明时间窗、来源和竞争事件。 |
| `estimand.name` | 目标估计量，如 `ATE`。由研究者冻结。 | 两个生产注册 profile 均为 `ATE`。虽然基线输入检查代码可接受 `ATO`，注册表未批准该 profile 的 ATO 正式使用。 | 不得根据结果在 ATE/ATT/ATO 间切换。 |
| `estimand.effect_measure` | 效应尺度描述。基线示例 `risk_difference_and_risk_ratio`；MI 示例 `mean_difference`。 | 生产 estimator 的输出尺度由 profile 固定；该文字不会选择任意 estimator。 | 把配置文字与实际 `effects` 输出混淆。 |

### 2.5 混杂变量

| 字段 | 含义 | 检查 | 科学边界 |
|---|---|---|---|
| `baseline_confounders` | 研究者批准的基线混杂变量列表，如 `[age, sofa]`。 | 必须与字典 `baseline_confounder` role 对齐；用于 PS 的变量必须在 time zero 前或当时可用。 | 软件不判断 confounder、mediator 或 collider。 |
| `time_varying_confounders` | 时变混杂变量列表。 | 与字典 `time_varying_confounder` role 对齐。 | 两个 v1.0.0 生产 profile 均为 baseline 路径；填写列表不会启用 longitudinal estimator。 |

正式模板没有 `include_in_ps` 列。运行器通常从 `role=baseline_confounder` 且 `include_in_model=TRUE` 的字典行取得 PS 协变量。示例 CSV 为兼容性增加了 `include_in_ps` 等扩展列；这些不是正式模板必需列。

### 2.6 缺失数据

| 字段 | 含义 | 生产行为 | 常见错误 |
|---|---|---|---|
| `missing_data.strategy` | `<complete_case|mice|none>`；研究者预先决定。 | 基线生产 profile 为 `none`；MI profile 为 `mice`。运行器不会因为填写其他值而提供新的已验证路径。 | 看结果后改策略。 |
| `missing_data.m` | 插补数据集数。MI 必须为整数且 `m >= 2`。示例为 `10`。 | 传给 `mice::mice()`，所有插补数据集均被分析。 | 只选“最好”的一个插补集。 |
| `missing_data.maxit` | MICE 最大迭代数，MI 必须 `>= 1`。示例为 `10`。 | 传给 `mice::mice()`。 | 未记录收敛/`loggedEvents`。 |
| `missing_data.seed` | 可重复随机种子。 | 显式 `set.seed()` 并传给 `mice::mice()`。 | 不冻结 seed 或为追求结果反复换 seed。 |

MI profile 只允许缺失发生在经字典批准、numeric/double、`impute=TRUE` 且 `mice_method=pmm` 的 PS 基线协变量。Treatment 与 outcome 必须非缺失。MICE 的分析变量包括 outcome、treatment 和所列 covariates；只有声明 PMM 的缺失协变量被插补。

### 2.7 权重、方差与敏感性分析

| 字段 | 含义 | v1.0.0 实际行为与限制 |
|---|---|---|
| `weighting.method` | 模板列示 `<none|iptw|stabilized_iptw|overlap|matching>`。 | 两个注册 profile 的生产实现均调用 `WeightIt::weightit(method="glm")`；基线按注册 ATE，MI 固定 ATE。模板选项不是生产能力清单。 |
| `weighting.estimand` | 权重目标人群。 | 应与 `estimand.name` 和注册 profile 一致；当前验证器不会全面交叉检查。 |
| `weighting.propensity_model` | 冻结的 PS 模型文字，如 `"treatment ~ age + sofa"`。 | 当前实现实际公式由字典中批准 covariates 用 `reformulate()`构造；不会解析此字符串来替代公式。必须人工核对二者一致。 |
| `weighting.truncation_quantiles` | 预设截断分位数记录，如 `[0.01, 0.99]`。 | 基线实际敏感性开关和界值来自 `runtime_thresholds.run_truncation_sensitivity`、`truncation_lower`、`truncation_upper`。 |
| `variance.method` | 方差方法记录。 | 基线固定 `fixed_weight_influence_curve`；MI 固定 `weightit_m_estimation_plus_rubin`。不得通过文字字段替换注册实现。 |
| `variance.cluster_id` | 方差聚类标识；无时 `null`。 | 当前生产 estimator 不提供任意 cluster-robust 切换。 |
| `variance.confidence_level` | 置信水平记录，模板 `0.95`。 | v1.0.0 estimator 使用 95% CI 的固定临界值（`qnorm(.975)`或 Rubin 后 `qt(.975, df)`）；不要填写其他值并声称已执行。 |
| `sensitivity.prespecified` | 敏感性分析是否预设。正式研究应为 `true`。 | 记录治理意图。 |
| `sensitivity.analyses` | 预设分析列表，如 `[weight_truncation]` 或 `[complete_case]`。 | 基线截断敏感性由 runtime threshold 开关执行；MI 在 complete cases 至少 30 行时生成 complete-case sensitivity。列表本身不是通用调度器。 |

### 2.8 图形与治理

| 字段 | 含义 | 检查与限制 |
|---|---|---|
| `figures.config_file` | 图形配置相对路径，模板 `config/figure_config.yml`。 | 运行调用实际从传入的 `config_dir/figure_config.yml` 读取；路径文字主要用于方案记录。 |
| `figures.requested` | 预设图类型列表。 | 当前 publication adapter 自动生成 balance 与可用的主效应 forest 图；不是任意图调度器。 |
| `governance.created_by` | 配置建立者。 | 正式项目填真实责任人或批准的角色标识。 |
| `governance.approved_by` | 科学方案批准者。 | 代码不替代签字；不要填自动生成的“approved”。 |
| `governance.approval_date` | 批准日期，建议 ISO `YYYY-MM-DD`。 | 当前验证器不验证完整日期语义。 |
| `governance.specification_hash` | 冻结配置的 SHA-256，可先留空，冻结后填入。 | 当前运行器不会自动比较该值；实际运行会另写 analysis spec SHA 到 `input_manifest.csv`。 |
| `governance.result_dependent_changes_allowed` | 是否允许结果驱动修改。必须为 `false`。 | 为 `true` 时合同验证失败。 |

### 2.9 `runtime_thresholds`

这些阈值是运行停止理由的预设界限，不是普遍统计真理。应在查看效应结果前由研究者/统计人员冻结。

| 字段 | 作用 | 运行器检查 |
|---|---|---|
| `positivity_lower` | PS 低界，模板 `0.05`。 | 计算 PS 低于此值的比例。必须满足 `0 < lower < upper < 1`。 |
| `positivity_upper` | PS 高界，模板 `0.95`。 | 计算 PS 高于此值的比例。 |
| `max_positivity_violation_rate` | 允许的最大越界比例，模板 `0.10`。 | 基线直接检查；MI 检查所有插补中的最大值。 |
| `max_abs_smd` | 最大加权后 absolute SMD，模板 `0.10`。 | 基线检查最大值；MI 要求每个插补均不超阈值。阈值是预设治理界限，不是绝对真理。 |
| `min_total_ess` | 最小总 ESS，模板 `100`。 | 基线检查总 ESS；MI 检查所有插补中的最小总 ESS。 |
| `min_group_n` | 最小 treatment 组原始样本数，模板 `30`。 | 基线 profile 检查两组较小者；MI gate 当前不使用该字段。 |
| `run_truncation_sensitivity` | 是否运行预设权重截断敏感性。 | 基线 profile 实际读取；MI 当前不执行截断敏感性。 |
| `truncation_lower` | 截断低分位，如 `0.01`。 | 基线开关为真时用于权重 quantile 截断。 |
| `truncation_upper` | 截断高分位，如 `0.99`。 | 同上；应与低分位共同预设。 |

## 3. `variable_dictionary.csv`

来源：`config_templates/variable_dictionary.csv`。正式模板共有 17 个必需列；列名必须完全一致。每个变量一行，`variable` 不得重复。

| 列 | 含义与填写方式 | v1.0.0 检查/限制 |
|---|---|---|
| `variable` | 数据中的原始列名，如 `age`。 | 必需、唯一；在运行时必须存在于数据。 |
| `label` | 可读标签，如 `Age at time zero`。 | 必需列；当前不验证语义。 |
| `role` | 允许值：`population_id`、`cluster_id`、`eligibility`、`treatment`、`outcome`、`baseline_confounder`、`time_varying_confounder`、`time`、`censoring`、`descriptive_only`。 | 其他值失败；与 analysis spec 的核心变量/列表做 role 对齐。 |
| `type` | 模板允许 `<integer|double|character|factor|logical|date|datetime>`。 | MI 缺失协变量必须为 `double` 或兼容示例扩展列中的 `numeric`。当前验证器不对每列执行完整强制类型转换。 |
| `unit` | 单位，如 `years`、`mmHg`、`ISO_8601`。 | 记录用途；必须与数据准备和输出一致。 |
| `reference` | 分类变量 reference，如 treatment 的 `0`。 | 方法库不替研究者选择 reference；当前两个 profile 要求 treatment 实际为 0/1。 |
| `levels` | 以竖线分隔的允许水平，如 `0|1`。 | 记录用途；v1.0.0 不对所有变量逐一按此列枚举校验。 |
| `measurement_time` | **测量发生的时间**，如 `baseline`、`time_zero`、`follow_up`。 | baseline confounder 的 `relation_to_time_zero` 必须为 `before` 或 `at`。 |
| `availability_time` | **该信息可被分析/决策使用的时间**，如 `time_zero`。 | 主要用于防止把当时尚不可得的信息放入 baseline；当前运行器不自动推断它。 |
| `relation_to_time_zero` | 模板值 `<before|at|after|time_varying>`。 | baseline confounder 必须 `before` 或 `at`；生产输入检查也要求 PS 变量至迟在 time zero 可用。 |
| `missing_code` | 原始数据中的缺失编码，如 `-999`；清洗后建议转为标准 `NA` 并记录原编码。 | 运行器读取 CSV 后不会自动按任意 `missing_code` 重编码。 |
| `valid_min` | 合理最小值。 | 当前验证器不自动执行全字段 range check；数据准备阶段必须另行核验。 |
| `valid_max` | 合理最大值。 | 同上。 |
| `impute` | `TRUE`/`FALSE`。 | 非布尔文字失败。MI 只有 `TRUE` 的批准协变量可发生缺失。 |
| `mice_method` | 插补方法。当前生产 MI 路径只审计 `pmm`。 | 缺失 PS 协变量若不是 `pmm` 会失败。 |
| `include_in_model` | `TRUE`/`FALSE`，表示经研究者批准纳入模型。 | 非布尔文字失败；正式模板下与 `role=baseline_confounder` 一起确定 PS covariates。 |
| `notes` | 定义、来源、单位转换、异常值处理等审计说明。 | 不被 estimator 解析。 |

### 3.1 `measurement_time` 与 `availability_time`

二者不能互换。例如，某实验室指标的样本在 time zero 前采集（`measurement_time=before_time_zero`），但结果在 treatment 决策后才回报（`availability_time=after_time_zero`）。它可能不适合作为 time-zero 决策时可用的 baseline confounder。方法库只读取研究者声明，不会自动重建临床工作流，因此必须由研究者与数据人员人工确认。

### 3.2 合成示例中的扩展列

`examples/quick_start/config/variable_dictionary.csv` 额外含 `variable_name`、`data_type`、`required`、`include_in_ps`、`include_in_imputation_model`、`reference_level`，用于兼容示例/既有合同。它们不属于 `config_templates/variable_dictionary.csv` 的 17 个必需列。新项目建议以正式模板为准，不要无理由复制扩展列。

## 4. `input_data_contract.csv`

来源：`config_templates/input_data_contract.csv`。正式模板有 12 列。

| 列 | 含义/示例 | v1.0.0 自动检查 | 仍需人工完成 |
|---|---|---|---|
| `dataset_id` | 数据集稳定标识，如 `analysis_data`。 | 不得重复。 | 与项目 manifest 保持一致。 |
| `relative_path` | 项目相对路径，必须从 `input/private/` 开始，如 `input/private/analysis_data.csv`。 | 拒绝盘符绝对路径、Unix 绝对路径、`..` traversal 和 private 目录外路径。 | 确认实际文件与合同同一版本。 |
| `format` | 当前仅 `csv`。 | 非 CSV 或 SQL/database/sqlite 失败。 | 确认编码、分隔符与小数点规则。 |
| `analysis_unit` | 一行代表的分析单位，如 `one_row_per_analysis_unit`。 | 列必须存在，但不解析任意文字。 | 明确患者/住院/ICU stay 级别，避免重复。 |
| `required` | `TRUE`/`FALSE`。 | 必须是布尔文字。 | 所有 formal candidate 必需文件应冻结。 |
| `primary_key` | 主键名，如 `analysis_id`。 | required 行不能为空。 | 当前运行输入仍固定检查 `subject_id` 和 `analysis_id` 唯一；不会按任意主键字符串自动执行通用查重。 |
| `time_structure` | `<baseline_wide|person_period|longitudinal_wide|longitudinal_long>`。 | 当前只记录，不据此切换 estimator。 | 两个生产 profile 要求一行一个分析单位的 baseline 数据。 |
| `contains_patient_level_rows` | `TRUE`/`FALSE`。 | 必须是布尔文字，且路径仍须为 `input/private/`。 | 患者级数据不得进入方法库或 Git。 |
| `expected_columns` | 竖线分隔列名。 | 当前合同验证器不逐项与文件表头比较；变量字典会另行检查声明变量是否存在。 | 人工/项目脚本核对所有 expected columns。 |
| `sha256` | 冻结输入文件 SHA-256。 | 合同要求该列存在，但当前不把填充值与文件自动比较。运行时会独立计算实际输入 SHA 到 `diagnostics/input_manifest.csv`。 | **必须**比较合同 SHA 与实际 SHA，并记录差异处理。 |
| `approved_by` | 输入冻结批准者。 | 列存在即可。 | 必须由真实责任人确认，不能自动生成批准。 |
| `notes` | 数据版本、生成流程、隐私限制等。 | 不解析。 | 写明可追溯来源。 |

合成示例：

```csv
dataset_id,relative_path,format,analysis_unit,required,primary_key,time_structure,contains_patient_level_rows,expected_columns,sha256,approved_by,notes
analysis_data,input/private/analysis_data.csv,csv,one_row_per_analysis_unit,TRUE,analysis_id,baseline_wide,TRUE,subject_id|analysis_id|eligibility_time|time_zero|treatment_assignment_time|followup_start|followup_end|treatment|outcome|age|sofa,<SHA256>,researcher_name,Synthetic schema example; replace with frozen private input metadata
```

Windows 计算 SHA-256：

```powershell
(Get-FileHash -Algorithm SHA256 ".\input\private\analysis_data.csv").Hash
```

## 5. `figure_config.yml`

来源：`config_templates/figure_config.yml`。默认设置经 v1.0.0 图形合同测试。

| 字段 | 默认值/作用 | 验证规则 |
|---|---|---|
| `schema_version` | `"1.0"` | 记录配置结构。 |
| `dimensions.single_column_width_mm` | `85`，单栏宽度 | 验证器要求等于 85。 |
| `dimensions.double_column_width_mm` | `178`，双栏宽度 | 必须在 175–180 mm。 |
| `dimensions.default_height_mm` | `110` | 必须为正数；可按图形内容预设调整。 |
| `typography.font_family` | `sans` | 配置记录。当前自动 publication adapter 使用绘图函数默认 `sans`；修改本字段不保证自动改变所有图，必须检查实际渲染。 |
| `typography.base_font_pt` | `8` | 不得小于 minimum font。当前自动绘图函数默认 base size 8；修改配置后必须确认调用路径实际使用该值。 |
| `typography.minimum_font_pt` | `7` | 必须 `>= 7`。 |
| `geometry.line_width_pt` | `0.7` | 必须为正。 |
| `geometry.point_size_pt` | `2.5` | 必须为正。 |
| `export.vector_formats` | `[pdf, svg]` | 至少一个，仅支持 PDF/SVG。 |
| `export.raster_formats` | `[tiff, png]` | 至少一个，仅支持 TIF/TIFF/PNG。 |
| `export.raster_dpi` | `600` | 必须 `>= 600`。 |
| `export.background` | `white` | 导出背景色。 |
| `palette.name` | `journal_safe_colorblind` | 记录 palette 名称；当前 validator 不校验该名称。 |
| `palette.colors` | 五个十六进制颜色 | 配置记录；当前 plot functions 使用内部 `tte_journal_palette()`的固定色组，修改本字段不保证自动改变实际颜色。不得结果驱动改色，必须检查实际渲染。 |
| `palette.grayscale_compatible` | `true` | 必须为真。 |
| `palette.use_shape_and_linetype_redundancy` | `true` | 必须为真。 |
| `style.three_dimensional_effects` | `false` | 必须为假。 |
| `style.decorative_gradients` | `false` | 必须为假。 |
| `style.ai_style_decoration` | `false` | 必须为假。 |
| `numbering.prefix` | `Figure` | 图编号前缀记录。 |
| `numbering.start` | `1` | 起始编号记录；当前 exporter 仍以安全 basename 写文件。 |
| `quality_control.require_clipping_check` | `true` | 要求人工检查裁切。 |
| `quality_control.require_overlap_check` | `true` | 要求人工检查重叠。 |
| `quality_control.require_grayscale_check` | `true` | 要求人工检查灰度可辨性。 |
| `quality_control.require_human_visual_approval` | `true` | 必须为真；机器检查不能替代人工批准。 |

生成后 `figure_qc.csv` 的实际初始状态为：

```text
clipping=PENDING_MANUAL_REVIEW
overlap=PENDING_MANUAL_REVIEW
grayscale_pass=PENDING_MANUAL_REVIEW
manual_review=PENDING
publication_ready=FALSE
```

人工用 `record_figure_manual_review()`记录全部 PASS 且 decision 为 `APPROVED` 后，才可能得到 `manual_review=APPROVED` 与 `publication_ready=TRUE`。`HUMAN_APPROVED` 可以作为流程语义描述，但不是 v1.0.0 CSV 的字面状态值。

## 6. 配置冻结核对清单

正式 Canary 前至少确认：

1. `profile` 在生产注册表且科学定义与 profile 限制一致；
2. `scientific_fields_frozen=true`；
3. treatment reference 与实际 `0/1` 编码一致；
4. outcome 类型、随访窗和 estimand 已由研究者批准；
5. baseline confounders 均在 time zero 前或当时可用；
6. missing strategy、`m`、`maxit`、seed 与 PMM 字典一致；
7. PS covariate 列表与 `weighting.propensity_model` 文字人工一致；
8. runtime thresholds 在看结果前冻结；
9. 输入合同 SHA 与实际输入 SHA 人工比对；
10. figure config 与目标期刊尺寸要求一致并已冻结；
11. 保存四个配置文件的 SHA-256；
12. 所有未由 v1.0.0 自动检查的字段都有人工审计记录。

另见：[完整中文使用说明书](USER_GUIDE_ZH_CN.md)、[中文快速参考](TTE_METHOD_LIBRARY_QUICK_REFERENCE_ZH_CN.md)、[故障排查表](TROUBLESHOOTING_ZH_CN.md)。
