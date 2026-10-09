% clear all
% warning off
% 
% load carsmall; 
% 
% Xtrain = [Acceleration Cylinders Displacement Horsepower MPG]; 
% ytrain = cellstr(Origin); 
% ytrain = double(ismember(ytrain,'USA'));
% X = Xtrain(1:70,:); 
% y = ytrain(1:70); 
% Xtest = Xtrain(size(X,1)+1:end,:); 
% ytest = ytrain(size(X,1)+1:end);
% 
% model_filename = []; 
% model = xgboost_train(X,y,[],999,'AUC',model_filename); %%% model_filename = 'xgboost_model.xgb'
% loadmodel = 0; 
% 
% Yhat = xgboost_test(Xtest,model,loadmodel);
% [XX,YY,~,AUC] = perfcurve(ytest,Yhat,1);
% 
% figure; 
% plot(XX,YY,'LineWidth',2); 
% xlabel('False positive rate'); 
% ylabel('True positive rate'); 
% title('ROC for Classification by Logistic Regression'); 
% grid on
% 
% figure; 
% scatter(Yhat,ytest + 0.1*rand(length(ytest),1)); 
% grid on




clear all
warning off

infile = "E:\test_results\test_model\modified_output.xlsx";
data = readmatrix(infile);

X = data(:, 1:end-1); 
Y = data(:, end); 

train_ratio = 0.7;
num_train = floor(size(X, 1) * train_ratio);
X_train = X(1:num_train, :); 
Y_train = Y(1:num_train, :); 
X_test = X(num_train+1:end,:); 
Y_test = Y(num_train+1:end,:);

% % 数据归一化
% [p_train, ps_input] = mapminmax(X_train, 0, 1);
% p_test = mapminmax('apply', X_test, ps_input);
% [t_train, ps_output] = mapminmax(y_train, 0, 1);
% t_test = mapminmax('apply', y_test, ps_output);

% XGBoost 模型训练
params = struct(...
    'eta', 0.05, ...          % 学习率
    'max_depth', 6, ...       % 树的最大深度
    'subsample', 1, ...       % 行采样比例
    'colsample_bytree', 1, ...% 列采样比例
    'reg_alpha', 1, ...      % L1正则
    'reg_lambda', 10, ...        % L2正则
    'objective', 'reg:squarederror', ...  % 回归目标函数
    'eval_metric', 'rmse' ... % 评估指标为均方根误差
);

% evals ={
%     dmatrix(X_train, Y_train),...
%     dmatrix(X_test, Y_test)};


% model_filename = []; 
% model = xgboost_train(Xtrain,Ytrain,[],999,'AUC',model_filename); %%% model_filename = 'xgboost_model.xgb'
num_trees = 999;  % 树的数量
model_filename = 'E:\test_results\xgboost_model.xgb';  % 指定保存路径
model = xgboost_train(X_train, Y_train, params, num_trees, 'None', model_filename);

% train_rmse = training_info.eval_history{1}(:, 2);
% tst_rmse = training_info.eval_history{2}(:, 2);
% 
% figure;
% plot(1:num_trees, train_rmse, 'r', 'LineWidth', 2); % 训练集
% hold on;
% plot(1:num_trees, test_rmse, 'b', 'LineWidth', 2);  % 测试集
% xlabel('Number of Trees');
% ylabel('RMSE');
% legend('Training RMSE', 'Test RMSE');
% title('Training and Test RMSE vs. Number of Trees');
% grid on;


loadmodel = 0; 
Yhat = xgboost_test(X_test,model,loadmodel);

% 绘制真实值 vs 预测值
figure;
scatter(Y_test, Yhat, 'b');
hold on;
plot([min(Y_test), max(Y_test)], [min(Y_test), max(Y_test)], 'r--', 'LineWidth', 2); % 理想预测线
xlabel('True Values');
ylabel('Predicted Values');
title('True Values vs Predicted Values');
grid on;

% % 残差图
% residuals = Y_test - Yhat;
% figure;
% scatter(Yhat, residuals, 'b');
% hold on;
% plot([min(Yhat), max(Yhat)], [0, 0], 'r--', 'LineWidth', 2); % 零残差线
% xlabel('Predicted Values');
% ylabel('Residuals');
% title('Residuals vs Predicted Values');
% grid on;

% % 特征重要性可视化
% importance = model.getScore('weight');
% figure;
% bar(importance);
% title('Feature Importance');
% xlabel('Feature Index');
% ylabel('Importance');

% 计算 RMSE
rmse = sqrt(mean((Y_test - Yhat).^2));
fprintf('Test RMSE: %.4f\n', rmse);

% [XX,YY,~,AUC] = perfcurve(Ytest,Yhat,1);

% figure; 
% plot(XX,YY,'LineWidth',2); 
% xlabel('False positive rate'); 
% ylabel('True positive rate'); 
% title('ROC for Classification by Logistic Regression'); 
% grid on
% 
% figure; 
% scatter(Yhat,ytest + 0.1*rand(length(ytest),1)); 
% grid on




