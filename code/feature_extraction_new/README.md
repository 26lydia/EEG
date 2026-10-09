# feature_extraction_new

本目录独立运行，不依赖原 feature_extraction。原目录不作修改。
以原 features_all_new.m 的含 ART、32 项特征版本为整理基础，统一入口为 features_all.m。
原 main 调用的 features_all_final.m 不接收 ART，且输出与其 flist 不匹配，故不沿用该临时版本。

## 使用

MATLAB R2026a + Signal Processing Toolbox；corr 需要 Statistics and Machine Learning Toolbox。
数据为实数二维矩阵：行是通道，列是时间样本；采样率和幅度单位必须由使用者核实。

```matlab
cd('/Volumes/Elements/code/feature_extraction_new');
report = main;                         % 选择输入、输出文件夹，默认 500 Hz / 300 秒
report = main(inputDir, outputDir, 500, 300);
art = detect_art(data, 500);
[feats, flist] = features_all(data, art, 500, 300, 'full');
test_feature_extraction;
```

可选的完整预处理（默认批处理不启用，以免改变已有结果）：

```matlab
[cleaned, validArt, info] = preprocess_eeg(data, 500);
[feats, flist] = features_all(cleaned, validArt, 500, 300, 'full');
opts = struct('HighpassHz',0.5,'LowpassHz',45, ...
    'LineHz',[], 'MaxGapSeconds',0.5);
report = main(inputDir, outputDir, 500, 300, opts);
test_preprocess_eeg;
```

`preprocess_eeg(data,fs,art,opts)` 的 art 可省略或传 `[]` 以自动检测。
输入为通道×样本，默认 0.5-45 Hz 双向零相位 Butterworth 带通；
`LineHz` 可设 50 或 60，在低通截止频率内时额外作 `LineHz +/- 1` Hz 陷波。
要求 `LowpassHz < fs/2`。自动检测沿用幅度阈值，但不作 5 秒外扩，
便于识别短缺口；已有人工标注 ART 建议显式传入。
仅两侧都有有效点、长度不超过 `MaxGapSeconds` 的缺口做线性插值，
并将这些插值点视为有效，**会参与后续特征计算**；边界/长缺口不插值为有效数据。
为使滤波器正常工作，长缺口内部也会临时填值，滤波后重新设为 NaN，
其邻近约 `1/HighpassHz` 秒也标为 ART，避免滤波边缘污染。
返回的 `validArt` 是最终有效性掩码；`info` 记录原 ART 比例、插值样本数、
最终 ART 比例和滤波参数。批处理输出额外保存 `EEG.(变量).preprocessing`；
原始信号和原始 ART 不会覆盖。严谨分析应核对阈值、频带与插值长度是否适合数据。

请把新目录放在 MATLAB 路径最前面，避免原目录同名函数遮蔽；可用 which features_all -all 核对。
main 现在是函数，不再是清空工作区的脚本。输入/输出不能是同一个文件夹，已有输出文件会跳过。

## 接口与输出

| 文件 | 接口 / 职责 |
| --- | --- |
| main.m | report = main(inputDir, outputDir, fs1, epl, preprocessOptions)，可选启用预处理 |
| preprocess_eeg.m | [cleaned, art, info] = preprocess_eeg(data, fs, art, options) |
| test_preprocess_eeg.m | 预处理滤波、缺口、接口的合成数据测试 |
| features_all.m | [feats, flist] = features_all(data, art, fs1, epl, varName) |
| detect_art.m | art = detect_art(data, fs, highThreshold, lowThreshold, paddingSeconds) |
| resample_art.m | mask = resample_art(art, fs, targetFs, outputLength) |
| burst_features.m | values = burst_features(sig, art, fs)，13 行 burst/抑制特征 |
| calculateSC_NS_pch.m | fv = calculateSC_NS_pch(dataEEG, fs, art)，支持多通道 |
| estimate_mse_pch_fast.m | fvx = estimate_mse_pch_fast(data, fs, art)，单通道行向量 |
| SampEn.m | saen = SampEn(dim, r, data, tau)，tau 默认 1 |
| calculate_*.m | 保留原连接特征计算接口；PSI 额外接收 fs；RHO/MI 接收分箱数 |
| test_feature_extraction.m | 合成数据回归测试，不读取或修改原 EEG 数据 |

feats 是 1×13 cell，flist 是 1×32 cell：
- feats{1} 是 20×通道数，行标签对应 flist{1:20}。
- feats{2:13} 是通道数×通道数，分别对应 flist{21:32} 的连接指标。
- 无有效数据或不适用的指标返回 NaN，不用 0 代替缺失。
- 原 features_all_final 的标签/布局不能直接用于本版本；下游应读取实际保存的 flist，
  不要复用旧 organize_* 脚本里的硬编码顺序。

批处理保存 EEG.(变量名).feats、flist、art、fs。
处理所有非空实数二维数值信号矩阵，跳过标量、结构体、文本以及 ART 变量。
输入文件应仅包含信号矩阵和相关元数据，普通数值矩阵元数据也可能被识别为信号。
优先使用同尺寸二值 <变量名>_art，其次使用同尺寸 art，否则自动检测。
report 的 saved / partial / skipped / failed 状态及 message 可用于检查失败变量。

## ART 和统计规则

- 保留原 main 的每秒最大绝对幅度规则：>500 或 <0.01 为 ART，前后扩展 5 秒。
  最后不足 1 秒的尾段也检测；NaN/Inf 标为 ART。
  阈值是否适合实际幅度单位需自行核实，可直接传入已确认的 ART 掩码。
- ART 与数据同尺寸，1 表示伪迹，0 表示有效；未标记的 NaN/Inf 也会排除。
- 数据内部重采样到 128 Hz。ART 按原时间区间映射，并扩展重采样 FIR 支持范围，
  避免短伪迹因降采样消失。过滤前填补 ART 样本只用于数值稳定，不将其当作有效样本。
- 幅度包络和能量只统计有效样本；有效比例不超过 50% 的通道窗口跳过。
- 连接特征只使用双方均无 ART 的连续窗口（10 秒，重叠 2 秒），不拼接 ART 两侧样本。
  少于 2 秒或恒定信号的连接指标不计算；不足 10 秒的记录使用一个较短窗口。
- burst/样本熵按 epl 秒不重叠分段，包含最后的短尾段，所有有效段取均值，
  修复原代码只保留最后一段/第一段的问题。短段的均值权重与完整段相同。
- burst 去掉跨越或紧贴 ART 的事件；保留原 3 秒长 burst 阈值和 start-to-start
  间隔定义。alpha/beta/theta/delta 不计算 burst 与抑制特征。
- 样本熵保留原 128 Hz、100 秒子段、scale=9、m=2、r=0.2×std 的算法。
  仅使用无 ART 的完整 100 秒子段；不足 100 秒或没有有效子段时为 NaN。
- 抑制曲线保留原线长归一化定义，排除含 ART 的 1 秒窗口。
- dPLI 反向元素为 1-dPLI，PSI 反向元素取负；对角分别为 0.5 和 0。

以上修复和更保守的 ART 排除会使数值与旧版本不同，不能视为旧结果的逐值复现。

## 文件整理范围

保留特征提取主流程及其实际依赖（17 个 MATLAB 文件），未复制旧实验入口、重复版本、
绘图、统计/Excel 整理和图论后处理脚本。它们不参与本入口的提取，并非在所有场景下都无用。
原 remove_artefacts* 使用缺失的 neural_parameters 等外部依赖，不纳入新入口；
ART 功能由 detect_art 和贯穿提取链的二值掩码保留。
delta brush 是独立扩展，不属于原含 ART 的 32 项特征接口，本版本不启用。

以下原文件未纳入新目录（原目录仍全部保留）：

- ._features_all.m
- ._features_all_final.m
- ._main.m
- FC_4.m
- PLV_network.m
- calculate_DSL.m
- calculate_GC_PDC_DTF.m
- calculate_MSC_IMCOH.m
- check_badchannel.m
- cleanValsByNormality.m
- comparedataname.m
- delete_nan_zero.m
- deltabrush.m
- detect_burst.m
- detector_per_channel_palmu.m
- estimate_rEEG.m
- features_all_final.m
- features_all_new.m
- features_all_new_2.m
- features_burst.m
- features_paired_montages.m
- features_single_montage.m
- get_p_for_GC.m
- graph theory/charpath.m
- graph theory/clustering_coef_wu.m
- graph theory/clustering_coef_wu_sign.m
- graph theory/clustering_coefficient.m
- graph theory/degrees_dir.m
- graph theory/degrees_und.m
- graph theory/density.m
- graph theory/density_und.m
- graph theory/distance_wei.m
- graph theory/distance_wei_floyd.m
- graph theory/efficiency_bin.m
- graph theory/efficiency_wei.m
- graph theory/features_all_organize.m
- graph theory/features_all_organize_new.m
- graph theory/final_organize.m
- graph theory/path_length.m
- graph theory/strengths_und.m
- graph theory/threshold_proportional.m
- kirsi_BD_filters_256.mat
- nlin_energy.m
- org_FC_feats.m
- organize_4feats.m
- organize_features.m
- organize_length.m
- pic2.m
- pic3.m
- pic4.m
- process_ba_1ch.m
- quick_add_suffix.m
- remove_artefacts.m
- remove_artefacts_referential.m
- sampen.txt
- scatterplot.m
- show_EEG.m
- show_burst.m
- sig_feats.m
- spectrum.m
- summary_pearsonr.m
- test.m
- test_cleanValsByNormality.m
- test_fea.m
- threshold_absolute.m
- threshold_proportional.m

## 验证

MATLAB R2026a 合成数据回归测试覆盖：接口与尺寸、连接矩阵方向性、全 ART/部分 ART、
短记录、零信号、NaN、500→128 Hz 非整长度重采样、单样本 ART、尾段检测、多段聚合、
样本熵/抑制函数、MAT 批处理和依赖闭包。
尚未对真实 EEG 数据做数值或科研有效性验证。

source_manifest.json 记录原目录所有 79 个文件的 SHA-256，用于确认原文件未被修改。
