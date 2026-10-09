# graph theory 整理版

本目录新增于 feature_extraction_new，原 feature_extraction/graph theory 保持不变。
基于原 features_all_organize_new.m 的图论流程及其 BCT 函数整理，适配上一轮
feature_extraction_new 的 ART-aware 输出，不依赖原目录。

## 使用

输入是提取后含 EEG 结构的 MAT 文件，不是原始信号 MAT 文件。
在 MATLAB 中运行：

```matlab
cd('/Volumes/Elements/code/feature_extraction_new/graph theory');
[T, report, columnMap] = features_all_organize_new; % 交互选择文件夹/临床表
[T, report, columnMap] = features_all_organize_new(inputDir, '', outputDir); % 不用临床表
[T, report, columnMap] = features_all_organize_new(inputDir, excelFile, outputDir);
options = struct('Proportion', 0.4, ...
    'Regions', struct('Left', [1 3], 'Right', [2 4]));
[T, report, columnMap] = features_all_organize_new(inputDir, '', outputDir, options);
test_graph_theory;
```

默认保留比例 0.4，范围 [0,1]；选临床表时取消可跳过临床信息。
输入、输出文件夹必须不同；已有输出文件会报错，不自动覆盖。
MATLAB R2026a 已验证；图论计算自身只使用基础 MATLAB，端到端测试还依赖上一轮提取模块及其工具箱。

## 文件与接口

| 文件 | 接口 |
| --- | --- |
| features_all_organize_new.m | [T, report, columnMap] = features_all_organize_new(inputDir, excelFile, outputDir, options) |
| organize_graph_block.m | [values, labels, quality] = organize_graph_block(block, proportion, customRegions) |
| graph_metrics.m | [values, labels, info] = graph_metrics(A, metric, proportion, regions, validChannels) |
| graph_regions.m | regions = graph_regions(channelCount, customRegions) |
| threshold_proportional.m | W = threshold_proportional(W, p)，新增输入验证 |
| degrees_und.m | deg = degrees_und(W) |
| degrees_dir.m | [inDegree, outDegree, totalDegree] = degrees_dir(W) |
| strengths_und.m | strength = strengths_und(W) |
| clustering_coef_wu.m | C = clustering_coef_wu(W) |
| distance_wei.m | [D, B] = distance_wei(lengthMatrix) |
| charpath.m | [lambda, efficiency, ecc, radius, diameter] = charpath(D, diagonal_dist, infinite_dist) |
| efficiency_wei.m | E = efficiency_wei(W, local)，local=0/1/2 |
| test_graph_theory.m | 合成网络、提取模块对接、批处理与依赖回归测试 |

原 BCT 函数的作者与出处注释保留；charpath 的 nanmax 改为基础 MATLAB 的 max(...,'omitnan')。

## 与提取模块对应

block 为 EEG.(任意变量名)，至少有 feats、flist，可含 art：
- feats 是 1×K cell，feats{1} 是单通道特征×通道数。
- flist 前 size(feats{1},1) 项对应单通道行，之后依次对应连接矩阵。
- 上一轮输出为 20 行单通道特征、12 个连接矩阵、32 项 flist；其顺序直接从文件读取。
- 支持原连接指标名称及 COR/XCOR/MSC/ImCoh/PSI/PLV/PLI/WPLI/DPLI/Rho/MI/OrthAEC 缩写。
- 不猜测旧版矩阵位置，不沿用临时版本中 21/26 项标签或 f+5 偏移。
  旧文件布局、标签或矩阵尺寸不匹配时，记录为失败，不静默错误映射。
- 每个文件中每个 EEG 字段独立输出一行，保留原变量名；
  EEG_alpha_sleep、EEG_alpha_wake、alpha、full 等不会混合，也不会只取第一个匹配字段。

## ART 保留

图论模块消费已经执行 ART 排除的特征，不重复检测原始信号：
- 上游 NaN/Inf 连接视为未观测，绝不填成 0 再计算图指标。
- 如果有 art，尺寸必须是通道×样本的二值掩码。整个记录均为 ART 的通道从网络中排除，
  该通道的单通道数值与原始连接汇总也强制设为缺失，防止旧文件中的零占位被误用。
- 剩余通道之间只要有任意未观测的非对角连接，该指标的整组 23 项图参数返回 NaN。
  不把不完整网络当作完整网络；原始连接均值仍可汇总已观测值。
- 少于 2 个有效通道时网络参数为 NaN；全 ART 的所有特征为 NaN。
- 有效观测的 0 权重与缺失连接不同：完整零网络的度、强度、聚类和效率为 0。
- ART 的部分样本污染由上游提取阶段负责；仅凭已聚合矩阵不能事后重新剔除这些样本。
  没有 art 字段时保留已有 NaN，但无法额外识别整通道 ART。

## 分区与网络规则

13 通道默认采用原脚本的编号映射，前提是你的真实电极顺序与原脚本一致。
保留 Whole/Anterior/Posterior/Left/Right/Frontalpole/Frontal/Central/Parietal/Occipital/Temporal；
13 号中央通道同时属于 Left 和 Right，与原代码一致。
其他通道数默认仅 Whole，不擅自推断左右脑；可在 options.Regions 中提供分区。
Whole 始终包括所有原通道；无 Left/Right 时对应网络汇总为 NaN。

保留原 23 项网络参数：
- 无向图计算度、强度、路径、聚类与效率；InDegree 项为 NaN。
- 有向 PSI/dPLI 的 Degree/Strength 明确定义为出度/出强度，InDegree 为入度。
  沿用原限制：PSI、dPLI、XCOR 不计算路径、聚类、效率。
- COR/Rho/OrthAEC 仅取正连接；MSC/PLV/PLI/WPLI/MI 同样使用非负权重。
  ImCoh/XCOR 取绝对值。
- PSI 只保留正方向（行→列）；dPLI 使用 max(dPLI-0.5,0)，
  0.5 为中性不建边，避免双方中性值形成伪双向连接。
- 先转换符号/方向，再比例阈值化，修复原先阈值化后才处理负值的问题。
- 路径输入为正边的 1/weight，缺边记 0，符合 distance_wei 接口。
  不连通网络的 PathLength 为 Inf，GlobalEfficiency 的不可达贡献为 0。
- 聚类权重按 max(1,最大权重) 归一化到 [0,1]，主要处理 MI 等可能大于 1 的指标。
  强度、路径和效率保留转换后权重的原尺度；不同指标的数值尺度不能直接互相比大小。
- 原始连接汇总不做符号转换/阈值化；保留左右脑、脑间、全脑汇总。
  有向指标额外保留 betweenrl，betweenlr 表示 Left→Right。
  全脑有向均值包括两种方向；PSI 反对称时可为 0，这是均值定义而非无连接。

## 输出

输出文件：
- EEG_Feature_Combined.xlsx：每行一个文件/EEG 变量，包含分区单通道均值、
  各通道原值、23 项图参数及原始连接汇总。
- EEG_Feature_Columns.csv：合法/唯一的输出列名与实际特征标签映射。

T 的基础列为 name、EEGVariable、ARTFraction、ValidChannelCount、IncompleteGraphCount。
IncompleteGraphCount 统计无法形成完整网络的连接指标数，包括少于 2 个有效通道的情况。
不同变量/文件的通道数或特征不同，使用标签并集，不存在的列填 NaN。
这是明确的一变量一行格式，不与旧脚本的一受试者多频段横向拼接格式兼容。
临床表只要求 name，其他 PMA/health/group 等列按实际存在的列保留；
重复/空 name 会报错，找不到临床匹配的 EEG 行仍保留，不静默丢弃。
report 记录 processed / partial / skipped / failed、成功行数和失败原因。
Excel 会按其写入规则表示 NaN/Inf；需要保留严格 MATLAB 数值类型时使用返回的 T。

## 文件取舍

保留 13 个 MATLAB 文件（8 个原算法依赖、整理入口、3 个辅助模块和测试）。
以下原文件未复制；它们仍留在原目录：

- clustering_coef_wu_sign.m
- clustering_coefficient.m
- density.m
- density_und.m
- distance_wei_floyd.m
- efficiency_bin.m
- features_all_organize.m
- final_organize.m
- path_length.m

其中 features_all_organize.m 的实际运行部分仅处理 DeltaBrush；
final_organize.m 的图论部分已关闭，且含大量重复历史代码。
未使用的密度/二值效率/其他距离与聚类包装函数不纳入依赖闭包。
取舍仅针对本流程，不表示这些算法在所有场景都无用。
本版因 ART、方向性和归一化修复，不会逐值复现旧脚本结果。

## 验证与原文件保护

合成测试覆盖：已知完全图/链/零图、缺失边、ART 通道排除、PSI/dPLI 方向、
符号变换、MI 归一化、比例边界、13 通道分区、特征顺序变更、提取模块对接、
sleep/wake 独立行、临床匹配、重复与覆盖保护、标签映射、依赖闭包及 MATLAB 语法。
真实 EEG 的科研有效性仍需结合通道映射、阈值与原始数据核实。
source_manifest.json 保存原 graph theory 的 18 个文件 SHA-256。
