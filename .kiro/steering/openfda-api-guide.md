# OpenFDA API Development Guide

本指南提供 OpenFDA Drug API 的核心知识和最佳实践，帮助开发者正确使用 OpenFDA API 构建应用。

## OpenFDA API 概述

### 什么是 OpenFDA

OpenFDA 是美国 FDA（食品药品监督管理局）提供的开放数据平台，通过 RESTful API 提供药品、医疗器械、食品等相关数据的访问。

### Drug API 的四个核心 Endpoints

1. **Drug Adverse Events** (`/drug/event.json`)
   - 数据源：FAERS (FDA Adverse Event Reporting System)
   - 用途：查询药品不良反应报告
   - 数据特点：自愿报告系统，数据量大但可能存在偏差

2. **Drug Labels** (`/drug/label.json`)
   - 数据源：SPL (Structured Product Labeling)
   - 用途：查询官方药品标签信息
   - 数据特点：FDA 批准的官方文档，包含警告、用法、剂量等

3. **Drug NDC Directory** (`/drug/ndc.json`)
   - 数据源：National Drug Code Directory
   - 用途：查询药品 NDC 码和产品信息
   - 数据特点：包含包装、制造商、产品类型等详细信息

4. **Drugs@FDA** (`/drug/drugsfda.json`)
   - 数据源：FDA 药品申请数据库
   - 用途：查询药品申请和批准信息
   - 数据特点：包含申请号、申请人、批准历史等

## 关键概念

### Lucene 查询语法

OpenFDA API **强制要求**使用 Lucene 查询语法，格式为 `field:value`。

**核心规则**：
- ❌ 不能直接传递药品名称：`"aspirin"`
- ✅ 必须指定字段：`"openfda.generic_name:aspirin"`

**逻辑操作符**：
- `AND`：两个条件都必须满足
- `OR`：任一条件满足即可
- `NOT`：排除特定条件

**范围查询**：
- 日期范围：`receivedate:[20200101 TO 20201231]`
- 数值范围：`patient.patientonsetage:[18 TO 65]`

**通配符**：
- 后缀通配：`field:val*`
- 前缀通配：`field:*value`

**精确匹配**：
- 使用 `.exact` 后缀：`openfda.manufacturer_name.exact:"Pfizer Inc."`
- 主要用于聚合查询（count）

### 字段命名的不一致性

**重要**：不同 endpoints 使用不同的字段名称，这是 OpenFDA API 的设计特点。

#### Generic Name（通用名）
- Drug Labels: `openfda.generic_name`
- Drug NDC: `generic_name`
- Adverse Events: `patient.drug.openfda.generic_name`
- Drugs@FDA: `openfda.generic_name`

#### Brand Name（品牌名）
- Drug Labels: `openfda.brand_name`
- Drug NDC: `brand_name`
- Adverse Events: `patient.drug.openfda.brand_name`
- Drugs@FDA: `openfda.brand_name`

#### Manufacturer/Sponsor（制造商/申办方）
- Drug Labels: `openfda.manufacturer_name`
- Drug NDC: `labeler_name`
- Adverse Events: N/A（无直接字段）
- Drugs@FDA: `sponsor_name`

**设计原因**：
- Adverse Events 数据结构复杂，包含患者、药品、反应等多层嵌套
- NDC 数据使用自己的术语体系（如 labeler 而非 manufacturer）
- 其他 endpoints 通过 `openfda` 对象提供标准化字段

### 分页机制

**参数**：
- `limit`：返回结果数量（最大 1000）
- `skip`：跳过的结果数量（用于翻页）

**最佳实践**：
- 首次查询使用较小的 limit（如 10-100）测试
- 大量数据使用分页：`limit=100, skip=0` → `limit=100, skip=100` → ...
- 注意 API 速率限制

### 聚合查询（Count）

**用途**：获取统计数据而非详细记录

**参数**：
- `count`：指定要统计的字段
- 通常与 `search` 结合使用过滤数据

**示例**：
```
search="patient.drug.openfda.generic_name:aspirin"
count="patient.reaction.reactionmeddrapt.exact"
```
返回：aspirin 相关的各种不良反应及其出现次数

**注意**：
- Count 字段通常需要 `.exact` 后缀
- 返回格式与普通查询不同（包含 term 和 count）

## API 速率限制

### 无 API Key
- **每分钟**：240 次请求
- **每天**：120,000 次请求

### 有 API Key
- **每分钟**：240 次请求
- **每天**：无限制

### 获取 API Key
1. 访问：https://open.fda.gov/apis/authentication/
2. 免费注册获取 key
3. 在请求中添加 `api_key` 参数

### 速率限制策略
- 对于高频应用，强烈建议使用 API key
- 实现请求重试机制处理 429 错误
- 考虑缓存常见查询结果

## 常见字段参考

### Adverse Events 关键字段

**药品信息**：
- `patient.drug.openfda.generic_name` - 通用名
- `patient.drug.openfda.brand_name` - 品牌名
- `patient.drug.medicinalproduct` - 报告中的药品名称
- `patient.drug.drugcharacterization` - 药品角色（1=可疑药品，2=伴随用药）

**不良反应**：
- `patient.reaction.reactionmeddrapt` - 不良反应描述
- `serious` - 严重程度（1=严重，2=非严重）
- `seriousnessdeath` - 是否导致死亡（1=是）

**时间信息**：
- `receivedate` - FDA 接收日期（YYYYMMDD）
- `transmissiondate` - 传输日期

**患者信息**：
- `patient.patientsex` - 性别（1=男，2=女）
- `patient.patientonsetage` - 发病年龄
- `occurcountry` - 发生国家

### Drug Labels 关键字段

**基本信息**：
- `openfda.generic_name` - 通用名
- `openfda.brand_name` - 品牌名
- `openfda.manufacturer_name` - 制造商

**标签内容**（可搜索文本）**：
- `indications_and_usage` - 适应症和用法
- `warnings` - 警告信息
- `adverse_reactions` - 不良反应
- `dosage_and_administration` - 剂量和给药方法
- `contraindications` - 禁忌症

**产品信息**：
- `openfda.product_type` - 产品类型
- `openfda.route` - 给药途径
- `openfda.substance_name` - 活性成分

### Drug NDC 关键字段

**产品标识**：
- `product_ndc` - 产品 NDC 码
- `generic_name` - 通用名
- `brand_name` - 品牌名

**制造商信息**：
- `labeler_name` - 标签商/制造商名称

**产品特性**：
- `product_type` - 产品类型（如 HUMAN PRESCRIPTION DRUG）
- `dosage_form` - 剂型（如 TABLET, CAPSULE）
- `route` - 给药途径
- `marketing_category` - 营销类别（NDA, ANDA, OTC 等）

**包装信息**：
- `packaging` - 包装详情（嵌套对象）

### Drugs@FDA 关键字段

**申请信息**：
- `application_number` - 申请号（如 NDA021081）
- `sponsor_name` - 申办方名称

**产品信息**：
- `openfda.generic_name` - 通用名
- `openfda.brand_name` - 品牌名
- `products.brand_name` - 产品品牌名
- `products.marketing_status` - 营销状态

**申请历史**：
- `submissions` - 提交历史（数组）
- `submissions.submission_type` - 提交类型

## 最佳实践

### 查询构建
- 从简单查询开始：`search="openfda.generic_name:aspirin"`
- 渐进添加条件：`AND openfda.manufacturer_name:bayer`
- 优先使用标准化字段（`openfda.*`）
- 聚合查询使用 `.exact` 后缀

### 常见错误
- **400**：查询语法错误 → 检查 `field:value` 格式和操作符大小写
- **404**：无结果 → 放宽查询条件或检查拼写
- **429**：速率限制 → 使用 API key 和重试机制

### 数据注意事项
- **Adverse Events**：自愿报告，存在偏差，不能推断因果关系
- **Labels**：官方权威但可能非最新版本
- **NDC**：用于产品识别和供应链管理

### 性能优化
- 使用合适的 limit 值和 count 查询
- 添加时间范围限制
- 缓存常见查询结果

## 常见使用场景

### 场景 1：药品安全监测
查找特定药品的严重不良反应，使用 Adverse Events endpoint，关键字段：`patient.drug.openfda.generic_name`, `serious`, `patient.reaction.reactionmeddrapt`

### 场景 2：药品信息查询
获取官方标签信息，使用 Drug Labels endpoint，关键字段：`openfda.generic_name`, `warnings`, `indications_and_usage`

### 场景 3：市场分析
分析药品市场情况，结合 NDC 和 Drugs@FDA endpoints，使用 count 统计制造商分布和批准历史

### 场景 4：批量数据分析
使用分页机制和 count 查询，注意速率限制和 API key 使用

## 数据质量和限制

**数据更新频率**：Adverse Events（季度）、NDC（每日）、Labels 和 Drugs@FDA（不定期）

**数据限制**：
- Adverse Events 为自愿报告，存在偏差，不能确定因果关系
- 并非所有药品都有完整数据
- 某些字段可能缺失

## 参考资源

### 官方文档
- OpenFDA 主页：https://open.fda.gov/
- Drug API 文档：https://open.fda.gov/apis/drug/
- 查询语法：https://open.fda.gov/apis/query-syntax/
- 字段参考：https://open.fda.gov/apis/drug/event/searchable-fields/

### API Endpoints
- Adverse Events: https://api.fda.gov/drug/event.json
- Drug Labels: https://api.fda.gov/drug/label.json
- Drug NDC: https://api.fda.gov/drug/ndc.json
- Drugs@FDA: https://api.fda.gov/drug/drugsfda.json

### 工具和资源
- API Key 注册：https://open.fda.gov/apis/authentication/
- 交互式查询工具：https://open.fda.gov/apis/drug/event/explore/
- 数据下载：https://open.fda.gov/apis/downloads/

## 核心要点

1. **必须使用 Lucene 语法**：`field:value` 格式，不能直接传药品名
2. **字段名因 endpoint 而异**：注意 generic_name 在不同 endpoint 的路径差异
3. **理解数据局限性**：Adverse Events 为自愿报告，不能推断因果关系
4. **使用 API key**：避免每日请求限制
5. **从简单开始**：先测试单一条件查询，再逐步复杂化
