function deletedCols = datacheck(infile, outfile)
% datacheck - 删除含有 0 或 NaN 的特征列（不包括最后一列）
% 输入文件仅包含纯数据（无列名、无行名）
% 输出文件也仅包含纯数据（无列名、无行名）

if nargin < 1
    error('请输入输入文件名，例如 datacheck(''your_data.xlsx'')');
end
if nargin < 2
    [p,n,e] = fileparts(infile);
    outfile = fullfile(p, ['cleaned_' n e]);
end

% ✅ 读取纯数据矩阵，不带表头
data = readmatrix(infile);

if isempty(data)
    warning('表为空：%s', infile);
    writematrix(data, outfile);
    deletedCols = 0;
    return;
end

cols = size(data, 2);
if cols < 2
    warning('只有 %d 列（没有要检测的特征列，最后一列保留）。', cols);
    writematrix(data, outfile);
    deletedCols = 0;
    return;
end

deletedCols = 0;

% ✅ 从倒数第二列向前遍历，删除含 0 或 NaN 的列
for i = cols - 1 : -1 : 1
    colData = data(:, i);
    if any(colData == 0 | isnan(colData))
        data(:, i) = [];  % 删除该列
        deletedCols = deletedCols + 1;
    end
end

% ✅ 保存结果为纯数据（无表头、无行名）
writematrix(data, outfile);

fprintf('完成：已删除 %d 列（保留最后一列）。结果保存为：%s\n', deletedCols, outfile);
end
