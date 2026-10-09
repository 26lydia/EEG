function [T, report, columnMap] = features_all_organize_new(inputDir, excelFile, outputDir, options)
% Batch EEG/graph aggregation. One output row per file and EEG variable.
% options.Proportion defaults to 0.4; options.Regions is an index struct.
if nargin < 1 || isempty(inputDir)
    inputDir = uigetdir(pwd,'Select extracted EEG MAT folder');
    if isequal(inputDir,0), T = table(); report = struct([]); columnMap = table(); return; end
end
if nargin < 2
    [file,path] = uigetfile({'*.xlsx;*.xls;*.csv'},'Select clinical table (Cancel to skip)');
    excelFile = '';
    if ~isequal(file,0), excelFile = fullfile(path,file); end
end
if nargin < 3 || isempty(outputDir)
    outputDir = uigetdir(pwd,'Select graph output folder');
    if isequal(outputDir,0), T = table(); report = struct([]); columnMap = table(); return; end
end
if nargin < 4, options = struct(); end
if ~isstruct(options) || ~isscalar(options) || ...
        any(~ismember(fieldnames(options),{'Proportion','Regions'}))
    error('features_all_organize_new:Options','Supported options are Proportion and Regions.');
end
proportion = 0.4; regions = [];
if isfield(options,'Proportion'), proportion = options.Proportion; end
if isfield(options,'Regions'), regions = options.Regions; end
validateattributes(proportion, {'numeric'}, {'scalar','finite','>=',0,'<=',1});
if ~isfolder(inputDir), error('features_all_organize_new:InputFolder','Input folder does not exist.'); end
in = java.io.File(char(inputDir)); out = java.io.File(char(outputDir));
if strcmp(char(in.getCanonicalPath()),char(out.getCanonicalPath()))
    error('features_all_organize_new:SameFolder','Input and output folders must differ.');
end
outputFile = fullfile(outputDir,'EEG_Feature_Combined.xlsx');
mapFile = fullfile(outputDir,'EEG_Feature_Columns.csv');
if isfile(outputFile) || isfile(mapFile)
    error('features_all_organize_new:OutputExists','Output already exists; select another folder.');
end
clinical = table();
if ~isempty(excelFile)
    clinical = readtable(excelFile,'VariableNamingRule','preserve');
    if ~ismember('name',clinical.Properties.VariableNames)
        error('features_all_organize_new:ClinicalName','Clinical table must contain a name column.');
    end
    clinical.name = string(clinical.name);
    if any(ismissing(clinical.name) | strlength(clinical.name)==0) || ...
            numel(unique(clinical.name)) ~= height(clinical)
        error('features_all_organize_new:DuplicateName','Clinical names must be nonempty and unique.');
    end
end
root = fileparts(mfilename('fullpath'));
addpath(root,'-begin');
files = dir(fullfile(inputDir,'*.mat'));
report = repmat(struct('file','','status','','message','','rows',0),numel(files),1);
rowValues = {}; rowLabels = {}; allLabels = {};
subjectNames = strings(0,1); variables = strings(0,1);
artFractions = []; validCounts = []; incompleteCounts = [];
for k = 1:numel(files)
    report(k).file = files(k).name;
    failures = {};
    try
        loaded = load(fullfile(inputDir,files(k).name),'EEG');
        if ~isfield(loaded,'EEG') || ~isstruct(loaded.EEG) || ~isscalar(loaded.EEG)
            error('features_all_organize_new:EEG','MAT must contain a scalar EEG struct.');
        end
        fields = fieldnames(loaded.EEG);
        [~,subject] = fileparts(files(k).name);
        for j = 1:numel(fields)
            try
                [v,l,q] = organize_graph_block(loaded.EEG.(fields{j}),proportion,regions);
                rowValues{end+1} = v; rowLabels{end+1} = l; %#ok<AGROW>
                allLabels = [allLabels l(~ismember(l,allLabels))]; %#ok<AGROW>
                subjectNames(end+1,1) = string(subject); %#ok<AGROW>
                variables(end+1,1) = string(fields{j}); %#ok<AGROW>
                artFractions(end+1,1) = q.artFraction; %#ok<AGROW>
                validCounts(end+1,1) = sum(q.validChannels); %#ok<AGROW>
                incompleteCounts(end+1,1) = sum(~strcmp(q.graphStatus,'ok')); %#ok<AGROW>
                report(k).rows = report(k).rows+1;
            catch ME
                failures{end+1} = sprintf('%s: %s',fields{j},ME.message); %#ok<AGROW>
            end
        end
        report(k).status = 'processed';
        if report(k).rows == 0, report(k).status = 'skipped';
        elseif ~isempty(failures), report(k).status = 'partial'; end
        report(k).message = strjoin(failures,'; ');
    catch ME
        report(k).status = 'failed'; report(k).message = ME.message;
    end
    fprintf('%s: %s (%d EEG rows) %s\n',files(k).name,report(k).status,report(k).rows,report(k).message);
end
reserved = {'name','EEGVariable','ARTFraction','ValidChannelCount','IncompleteGraphCount'};
columnNames = matlab.lang.makeValidName(allLabels);
columnNames = matlab.lang.makeUniqueStrings(columnNames,reserved,namelengthmax);
columnMap = table(string(columnNames(:)),string(allLabels(:)), ...
    'VariableNames',{'ColumnName','FeatureLabel'});
data = nan(numel(rowValues),numel(allLabels));
for k = 1:numel(rowValues)
    [~,idx] = ismember(rowLabels{k},allLabels);
    data(k,idx) = rowValues{k};
end
T = table(subjectNames,variables,artFractions,validCounts,incompleteCounts, ...
    'VariableNames',reserved);
T = [T array2table(data,'VariableNames',columnNames)];
if ~isempty(clinical)
    overlap = intersect(T.Properties.VariableNames,clinical.Properties.VariableNames);
    if any(~strcmp(overlap,'name'))
        error('features_all_organize_new:ClinicalColumns','Clinical columns conflict with output columns.');
    end
    % Left join retains EEG rows even when clinical information is missing.
    T = outerjoin(T,clinical,'Keys','name','MergeKeys',true,'Type','left');
end
if height(T) == 0
    warning('features_all_organize_new:NoRows','No valid EEG blocks; no output written.');
    return;
end
if ~isfolder(outputDir), mkdir(outputDir); end
writetable(T,outputFile);
writetable(columnMap,mapFile);
fprintf('Saved %d EEG rows to %s\n',height(T),outputFile);
end
