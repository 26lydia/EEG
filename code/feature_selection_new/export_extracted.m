function [T, report, columnMap] = export_extracted(inputDir, outputDir, clinicalFile, options)
%EXPORT_EXTRACTED Bridge from extracted EEG MAT files to selection tables.
% Example: export_extracted('/Users/lei/Desktop/feature_extraction_output', ...
%                          '/Users/lei/Desktop/eeg_graph_for_selection');
% Clinical table is optional; name must match each input MAT basename.
if nargin < 3, clinicalFile = ''; end
if nargin < 4, options = struct(); end
root = fileparts(mfilename('fullpath'));
graphDir = fullfile(fileparts(root),'feature_extraction_new','graph theory');
if ~isfolder(graphDir)
    error('export_extracted:Dependency', ...
        'Keep feature_selection_new beside feature_extraction_new under code/.');
end
addpath(graphDir,'-begin');
[T,report,columnMap] = features_all_organize_new(inputDir,clinicalFile,outputDir,options);
if height(T) > 0
    writetable(T,fullfile(outputDir,'EEG_Feature_Combined.csv'));
end
end
