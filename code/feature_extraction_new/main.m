function report = main(inputDir, outputDir, fs1, epl, preprocessOptions)
% MAIN Batch extraction; run main with no arguments for folder dialogs.
% Each output MAT contains EEG.(variable).feats / flist / art / fs.
if nargin < 1 || isempty(inputDir)
    inputDir = uigetdir(pwd,'Select input MAT folder');
    if isequal(inputDir,0), report = struct([]); return; end
end
if nargin < 2 || isempty(outputDir)
    outputDir = uigetdir(pwd,'Select output folder');
    if isequal(outputDir,0), report = struct([]); return; end
end
if nargin < 3, fs1 = 500; end
if nargin < 4, epl = 300; end
if nargin < 5, preprocessOptions = []; end
validateattributes(fs1, {'numeric'}, {'scalar','integer','positive'});
validateattributes(epl, {'numeric'}, {'scalar','finite','positive'});
if ~isfolder(inputDir), error('main:InputFolder','Input folder does not exist.'); end
if ~isfolder(outputDir), mkdir(outputDir); end
in = java.io.File(char(inputDir));
out = java.io.File(char(outputDir));
if strcmp(char(in.getCanonicalPath()),char(out.getCanonicalPath()))
    error('main:SameFolder','Input and output folders must differ.');
end
root = fileparts(mfilename('fullpath'));
addpath(root,'-begin');
files = dir(fullfile(inputDir,'*.mat'));
report = repmat(struct('file','','status','','message',''),numel(files),1);
for k = 1:numel(files)
    report(k).file = files(k).name;
    outputPath = fullfile(outputDir,files(k).name);
    % Do not overwrite either input records or previously extracted results.
    if isfile(outputPath)
        report(k).status = 'skipped';
        report(k).message = 'Output file already exists.';
        continue;
    end
    try
        loaded = load(fullfile(inputDir,files(k).name));
        names = fieldnames(loaded);
        EEG = struct();
        failures = {};
        for j = 1:numel(names)
            name = names{j};
            data = loaded.(name);
            if ~isnumeric(data) || ~isreal(data) || ~ismatrix(data) || ...
                    isempty(data) || size(data,2) < 2 || isscalar(data)
                continue;
            end
            % ART sidecars are not EEG channels. Use <name>_art if supplied.
            if endsWith(lower(name),'_art') || strcmpi(name,'art'), continue; end
            try
                if isfield(loaded,[name '_art'])
                    art = loaded.([name '_art']);
                elseif isfield(loaded,'art') && isequal(size(loaded.art),size(data))
                    art = loaded.art;
                else
                    if isempty(preprocessOptions)
                        art = detect_art(data,fs1);
                    else
                        art = detect_art(data,fs1,500,0.01,0);
                    end
                end
                preprocessing = [];
                if ~isempty(preprocessOptions)
                    [data,art,preprocessing] = preprocess_eeg(data,fs1,art,preprocessOptions);
                end
                [feats,flist] = features_all(data,art,fs1,epl,name);
                EEG.(name) = struct('feats',{feats},'flist',{flist}, ...
                    'art',logical(art) | ~isfinite(data),'fs',fs1, ...
                    'preprocessing',preprocessing);
            catch ME
                failures{end+1} = sprintf('%s: %s',name,ME.message); %#ok<AGROW>
            end
        end
        if isempty(fieldnames(EEG))
            report(k).status = 'skipped';
            report(k).message = strjoin([{'No EEG matrix extracted.'},failures],'; ');
        else
            save(outputPath,'EEG','-v7.3');
            report(k).status = 'saved';
            if ~isempty(failures), report(k).status = 'partial'; end
            report(k).message = strjoin(failures,'; ');
        end
    catch ME
        report(k).status = 'failed';
        report(k).message = ME.message;
    end
    fprintf('%s: %s %s\n',files(k).name,report(k).status,report(k).message);
end
end
