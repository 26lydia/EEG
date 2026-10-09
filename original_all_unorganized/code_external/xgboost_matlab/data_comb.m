% 选择输入文件夹和Excel表格
inputFolder = uigetdir('', '选择.mat文件夹'); % 选择文件夹
[inputExcelFile, inputExcelPath] = uigetfile('*.xlsx', '选择输入的Excel文件'); % 选择Excel文件
inputExcelFullPath = fullfile(inputExcelPath, inputExcelFile); % Excel文件的完整路径

% 选择输出Excel表格所在的文件夹
outputFolder = uigetdir('', '选择输出文件夹'); % 选择输出文件夹
outputExcelFile = 'merged_output.xlsx'; % 输出文件名
outputExcelFullPath = fullfile(outputFolder, outputExcelFile); % 输出文件的完整路径

% 读取输入Excel文件中的数据
excelData = readtable(inputExcelFullPath); % 读取Excel数据
names = excelData.name; % 获取“name”列，假设为病人名字
PMA = excelData.PMA; % 获取PMA列

% 选择EEG类型（可选择多个，默认选择全部）
% EEG_types = {'EEG_alpha_sleep', 'EEG_beta_sleep', 'EEG_delta_sleep', 'EEG_sleep', 'EEG_theta_sleep'};
EEG_types = {'EEG_alpha_sleep', 'EEG_beta_sleep', 'EEG_delta_sleep', 'EEG_sleep', 'EEG_theta_sleep'};
[selectedEEGTypes, isValidSelection] = listdlg('PromptString', '选择EEG类型', 'SelectionMode', 'multiple', 'ListString', EEG_types);

if isempty(selectedEEGTypes)
    disp('没有选择EEG类型，程序退出');
    return;
end

% 初始化一个空的数组，用于存储拼接后的数据
allFeatures = [];

% 遍历文件夹中的所有.mat文件
matFiles = dir(fullfile(inputFolder, '*.mat')); % 获取.mat文件列表

for i = 1:length(matFiles)
    matFileName = matFiles(i).name; % 获取当前.mat文件的名字
    patientName = erase(matFileName, '.mat'); % 假设.mat文件名即病人名字

    % 检查病人名字是否在输入Excel表格的“name”列中
    patientIdx = find(strcmp(names, patientName));
    if isempty(patientIdx)
        disp(['警告: 找不到病人名为' patientName '的记录']);
        continue; % 跳过该病人
    end

    % 读取.mat文件中的EEG数据
    matFilePath = fullfile(inputFolder, matFileName);
    matData = load(matFilePath); % 加载.mat文件

    % 获取病人的EEG数据，按选择的EEG类型提取特征
    patientFeatures = [];
    for j = 1:length(selectedEEGTypes)
        EEG_type = EEG_types{selectedEEGTypes(j)};
        if isfield(matData, EEG_type)
            EEG_data = matData.(EEG_type); % 获取相应类型的EEG数据
            EEG_cell = EEG_data{1}; % 获取cell中的数据
            if size(EEG_cell, 1) == 36 && size(EEG_cell, 2) == 13
                % 如果数据符合要求，提取特征
                patientFeatures = [patientFeatures, EEG_cell(:)']; % 将数据拉成一行
            else
                disp(['警告: ' patientName '的' EEG_type '数据尺寸不正确']);
            end
        else
            disp(['警告: ' EEG_type ' 在文件 ' matFileName ' 中未找到']);
        end
    end

    if ~isempty(patientFeatures)
        % 将特征和PMA值拼接
        allFeatures = [allFeatures; patientFeatures, PMA(patientIdx)];
    end
end

% 将拼接好的数据写入输出Excel文件
if ~isempty(allFeatures)
    % 创建一个表格用于保存结果
    resultTable = array2table(allFeatures);

    % 将数据写入Excel文件
    writetable(resultTable, outputExcelFullPath, 'WriteVariableNames', false);
    disp(['数据已成功保存到: ' outputExcelFullPath]);
else
    disp('没有有效的数据需要保存');
end
