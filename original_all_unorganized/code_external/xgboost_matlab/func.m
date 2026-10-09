%% XGBoost matlab实现
clc; clear; close all;

%% XGBoost核心参数设置
params = struct(...
    'eta', 0.05, ...           % 学习率 (同learning_rate), 控制每棵树的贡献
    'gamma', 0, ...           % 最小分裂增益阈值，防止过拟合
    'lambda', 1, ...          % L2正则化系数，约束叶子权重
    'max_depth', 3, ...       % 树最大深度，控制模型复杂度
    'subsample', 1, ...     % 行采样比例，增强多样性
    'colsample_bytree', 1, ... % 列采样比例，类似随机森林
    'min_child_weight', 1 ... % 叶子节点最小样本权重和（基于Hessian）
);

%% 生成模拟数据（含10%缺失值）
rng(42); % 固定随机种子
n_samples = 200;  % 样本数量
n_features = 5;   % 特征维度
X = rand(n_samples, n_features) * 10; % 特征矩阵范围[0,10]
Y = 3*X(:,1) + 2*X(:,2) + 1.5*X(:,3) + randn(n_samples,1)*2; % 目标变量（线性关系+噪声）

% 添加10%缺失值（NaN表示缺失）
X(randperm(numel(X), round(0.1*numel(X)))) = NaN;

% 划分训练集和测试集
cv = cvpartition(n_samples, 'HoldOut', 0.3);
X_train = X(cv.training,:);
Y_train = Y(cv.training,:);
X_test = X(cv.test,:);
Y_test = Y(cv.test,:);

%% 初始化预测值（基学习器为均值）
base_score = mean(Y_train);  % 初始预测值
F = base_score * ones(size(Y_train)); % 训练集预测值初始化
F_test = base_score * ones(size(Y_test)); % 测试集预测值初始化

%% XGBoost训练主循环
n_estimators = 70;  % 树的数量
trees = cell(n_estimators, 1); % 存储所有树结构

for t = 1:n_estimators
    % 步骤1: 数据采样（行采样 + 列采样）
    [sub_X, sub_Y, sub_idx, col_idx] = subsample(X_train, Y_train, ...
        params.subsample, params.colsample_bytree);
    
    % 步骤2: 计算一阶梯度(g)和二阶导数(h) —— 均方误差损失
    g = -(sub_Y - F(sub_idx));  % 一阶导数：负残差
    h = ones(size(g));          % 二阶导数：平方损失下恒为1
    
    % 步骤3: 训练XGBoost树（处理缺失值）
    tree = xgb_train_tree(sub_X, g, h, params, 0, 1:size(col_idx,2));
    
    % 步骤4: 更新训练集预测值（带学习率）
    leaf_pred = xgb_predict_tree(tree, X_train(:, col_idx)); % 仅使用采样特征
    F = F + params.eta * leaf_pred;
    
    % 存储树结构和使用的特征索引
    trees{t} = struct('tree', tree, 'col_idx', col_idx);
    
    % 打印训练进度
    fprintf('Tree %d 训练完成 | 最佳增益: %.2f\n', t, tree.best_gain);
end

%% 测试集预测
for t = 1:n_estimators
    % 获取当前树的特征子集
    col_idx = trees{t}.col_idx;
    % 预测并累加结果
    leaf_pred = xgb_predict_tree(trees{t}.tree, X_test(:, col_idx));
    F_test = F_test + params.eta * leaf_pred;
end

% 计算评估指标
mse = mean((Y_test - F_test).^2);
fprintf('\n测试集MSE: %.2f\n', mse);

plot(1:size(Y_test,1),Y_test,1:size(F_test,1),F_test)
%% ========== 核心函数定义 ==========

function tree = xgb_train_tree(X, g, h, params, depth, col_idx)
    % XGBoost树训练函数（递归实现）
    % 输入:
    %   X - 特征矩阵（可能含NaN）
    %   g - 一阶梯度
    %   h - 二阶导数
    %   params - 超参数
    %   depth - 当前深度
    %   col_idx - 全局特征索引（用于预测时对齐）
    % 输出:
    %   tree - 树结构体
    
    % 终止条件1: 达到最大深度
    % 终止条件2: 节点样本权重和不足（min_child_weight）
    if depth >= params.max_depth || sum(h) < params.min_child_weight
        % 计算叶子节点权重（带L2正则化）
        w = -sum(g) / (sum(h) + params.lambda);
        tree = struct('is_leaf', true, 'value', w, 'best_gain', 0, 'col_idx', col_idx);
        return;
    end
    
    % 初始化最佳分裂参数
    best_gain = -inf;
    best_feature = 0;
    best_threshold = 0;
    best_default = 0; % 缺失值默认方向（0=左子树，1=右子树）
    
    % 遍历所有采样特征（此处使用全局特征索引）
    for f_global = col_idx
        % 获取当前特征数据（可能含NaN）
        feature_data = X(:, f_global);
        
        % 步骤1: 处理缺失值，获取有效数据点
        valid_mask = ~isnan(feature_data);
        sorted_data = sort(feature_data(valid_mask));
        
        % 步骤2: 生成候选分裂点（简化版分位数）
        n_bins = min(10, length(sorted_data)); % 分箱数量
        candidates = linspace(min(sorted_data), max(sorted_data), n_bins+1);
        candidates = candidates(2:end-1); % 去除首尾
        
        % 步骤3: 评估每个候选点
        for threshold = candidates
            % 分裂掩码（处理缺失值为默认方向）
            left_mask = feature_data <= threshold;
            left_mask(isnan(feature_data)) = false; % 初始假设缺失值归右
            
            % 计算增益（假设缺失值在右）
            G_left = sum(g(left_mask));
            H_left = sum(h(left_mask));
            G_right = sum(g) - G_left;
            H_right = sum(h) - H_left;
            gain = (G_left^2)/(H_left + params.lambda) + ...
                   (G_right^2)/(H_right + params.lambda) - ...
                   (G_left + G_right)^2/(H_left + H_right + params.lambda);
            gain = gain/2 - params.gamma; % XGBoost官方增益公式
            
            % 检查是否更优增益（考虑缺失值在左的情况）
            G_left_alt = sum(g(left_mask | isnan(feature_data)));
            H_left_alt = sum(h(left_mask | isnan(feature_data)));
            G_right_alt = sum(g) - G_left_alt;
            H_right_alt = sum(h) - H_left_alt;
            gain_alt = (G_left_alt^2)/(H_left_alt + params.lambda) + ...
                       (G_right_alt^2)/(H_right_alt + params.lambda) - ...
                       (G_left_alt + G_right_alt)^2/(H_left_alt + H_right_alt + params.lambda);
            gain_alt = gain_alt/2 - params.gamma;
            
            % 选择更优的缺失值分配方向
            if gain_alt > gain
                gain = gain_alt;
                default_dir = true; % 缺失值归左
            else
                default_dir = false; % 缺失值归右
            end
            
            % 更新最佳分裂
            if gain > best_gain
                best_gain = gain;
                best_feature = f_global;
                best_threshold = threshold;
                best_default = default_dir;
            end
        end
    end
    
    % ========== 修改后的终止条件判断 ==========
    % 当所有特征都无法产生有效分裂时
    if best_gain <= params.gamma || best_feature == 0
        w = -sum(g)/(sum(h) + params.lambda);
        tree = struct('is_leaf', true, 'value', w, 'best_gain', best_gain, 'col_idx', col_idx);
        return;
    end
    
    
%     % 终止条件3: 无有效分裂（增益不足）
%     if best_gain <= 0
%         w = -sum(g)/(sum(h) + params.lambda);
%         tree = struct('is_leaf', true, 'value', w, 'best_gain', best_gain, 'col_idx', col_idx);
%         return;
%     end
    
    % 步骤4: 执行分裂
    % 生成分裂掩码（处理缺失值）
    feature_data = X(:, best_feature);
    left_mask = feature_data <= best_threshold;
    left_mask(isnan(feature_data)) = best_default; % 根据最佳方向分配缺失值
    
    % 检查左右子节点是否为空
    if sum(left_mask) == 0 || sum(~left_mask) == 0
        w = -sum(g)/(sum(h) + params.lambda);
        tree = struct('is_leaf', true, 'value', w, 'best_gain', best_gain, 'col_idx', col_idx);
        return;
    end
    
    % ========== 带保护的递归调用 ==========
    try
        left_tree = xgb_train_tree(X(left_mask, :), g(left_mask), h(left_mask), ...
                   params, depth+1, col_idx);
        right_tree = xgb_train_tree(X(~left_mask, :), g(~left_mask), h(~left_mask), ...
                    params, depth+1, col_idx);
    catch ME
        % 递归错误处理
        warning('深度 %d 递归失败: %s', depth, ME.message);
        w = -sum(g)/(sum(h) + params.lambda);
        tree = struct('is_leaf', true, 'value', w, 'best_gain', best_gain, 'col_idx', col_idx);
        return;
    end
    
    
%     % 递归构建子树
%     left_tree = xgb_train_tree(X(left_mask, :), g(left_mask), h(left_mask), ...
%                 params, depth+1, col_idx);
%     right_tree = xgb_train_tree(X(~left_mask, :), g(~left_mask), h(~left_mask), ...
%                  params, depth+1, col_idx);
    
    % 返回非叶子节点结构
    tree = struct(...
        'is_leaf', false, ...
        'feature', best_feature, ...
        'threshold', best_threshold, ...
        'default', best_default, ... % 缺失值方向
        'left', left_tree, ...
        'right', right_tree, ...
        'best_gain', best_gain, ...
        'col_idx', col_idx ...
    );
end

function pred = xgb_predict_tree(tree, X)
    % XGBoost树预测函数
    % 输入:
    %   tree - 训练好的树结构
    %   X - 特征矩阵（必须包含tree.col_idx指定的特征）
    % 输出:
    %   pred - 预测值
    
    pred = zeros(size(X,1), 1);
    for i = 1:size(X,1)
        node = tree;
        while true
            if node.is_leaf
                pred(i) = node.value;
                break;
            end
            
            % 获取特征值（注意特征索引对齐）
            f_global = node.feature;
            val = X(i, f_global);
            
            % 处理缺失值
            if isnan(val)
                go_left = node.default; % 使用训练时确定的方向
            else
                go_left = val <= node.threshold;
            end
            
            % 移动到子节点
            if go_left
                node = node.left;
            else
                node = node.right;
            end
        end
    end
end

function [sub_X, sub_Y, sub_idx, col_idx] = subsample(X, Y, subsample_ratio, colsample_ratio)
    % 数据采样函数（行+列采样）
    % 输入:
    %   X, Y - 原始数据和标签
    %   subsample_ratio - 行采样比例
    %   colsample_ratio - 列采样比例
    % 输出:
    %   sub_X, sub_Y - 采样后的数据和标签
    %   sub_idx - 行采样索引（相对于原始数据）
    %   col_idx - 列采样索引（全局特征索引）
    
    % 行采样
    n = size(X,1);
    sub_idx = randperm(n, round(n * subsample_ratio));
    sub_X = X(sub_idx, :);
    sub_Y = Y(sub_idx);
    
    % 列采样
    n_features = size(X,2);
    col_idx = sort(randperm(n_features, round(n_features * colsample_ratio)));
    sub_X = sub_X(:, col_idx);
end
