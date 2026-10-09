function [values, labels, quality] = organize_graph_block(block, proportion, customRegions)
% Read actual flist instead of assuming a fixed feature order or channel count.
if nargin < 2, proportion = 0.4; end
if nargin < 3, customRegions = []; end
if ~isstruct(block) || ~isscalar(block) || ~isfield(block,'feats') || ~isfield(block,'flist')
    error('organize_graph_block:InvalidBlock','Each EEG block must contain feats and flist.');
end
feats = block.feats;
if ~iscell(feats) || size(feats,1) ~= 1 || isempty(feats)
    error('organize_graph_block:InvalidLayout','Expected a 1 x K feature cell array; old epoch layouts must be explicitly converted.');
end
single = feats{1};
validateattributes(single, {'numeric'}, {'2d','real','nonempty'});
names = cellstr(string(block.flist)); names = names(:).';
nSingle = size(single,1); n = size(single,2);
if numel(names) ~= nSingle+numel(feats)-1 || numel(unique(names)) ~= numel(names)
    error('organize_graph_block:LabelMismatch','flist must uniquely label every single-feature row and connectivity cell.');
end
regions = graph_regions(n,customRegions);
regionNames = fieldnames(regions);
validChannels = true(1,n);
artFraction = NaN;
if isfield(block,'art')
    art = block.art;
    if ~(islogical(art) || isnumeric(art)) || ~ismatrix(art) || ...
            size(art,1) ~= n || isempty(art) || ...
            any(~isfinite(art(:))) || any(art(:) ~= 0 & art(:) ~= 1)
        error('organize_graph_block:InvalidArt','art must be a binary channels x samples matrix.');
    end
    validChannels = ~all(logical(art),2).';
    artFraction = mean(double(art(:)));
end
single = double(single);
single(~isfinite(single)) = NaN;
single(:,~validChannels) = NaN;
values = []; labels = {};
for f = 1:nSingle
    for r = 1:numel(regionNames)
        idx = regions.(regionNames{r});
        values(end+1) = mean(single(f,idx),'omitnan'); %#ok<AGROW>
        labels{end+1} = [names{f} '_' regionNames{r}]; %#ok<AGROW>
    end
end
for f = 1:nSingle
    for ch = 1:n
        values(end+1) = single(f,ch); %#ok<AGROW>
        labels{end+1} = sprintf('%s_Channel%d',names{f},ch); %#ok<AGROW>
    end
end
quality = struct('artFraction',artFraction,'validChannels',validChannels, ...
    'graphStatus',{{}},'graphMetrics',{{}});
for f = 2:numel(feats)
    A = feats{f};
    if ~isnumeric(A) || ~isreal(A) || ~isequal(size(A),[n n])
        error('organize_graph_block:MatrixSize','Connectivity %s must be %d x %d.',names{nSingle+f-1},n,n);
    end
    metric = names{nSingle+f-1};
    [v,l,info] = graph_metrics(A,metric,proportion,regions,validChannels);
    values = [values v]; %#ok<AGROW>
    labels = [labels cellfun(@(s) [s '_' metric],l,'UniformOutput',false)]; %#ok<AGROW>
    quality.graphStatus{end+1} = info.status;
    quality.graphMetrics{end+1} = metric;
    % Raw FC summaries retain direction and are not thresholded graph weights.
    A = double(A); A(~isfinite(A)) = NaN;
    A(~validChannels,:) = NaN; A(:,~validChannels) = NaN;
    directed = any(strcmpi(metric,{'PSI','PhaseSlopeIndex','DPLI','DirectionalityPhaseLagIndex'}));
    pairNames = {'left','right','betweenlr','whole'};
    left = []; right = [];
    if isfield(regions,'Left'), left = regions.Left; end
    if isfield(regions,'Right'), right = regions.Right; end
    masks = {within(n,left,directed),within(n,right,directed),false(n),within(n,1:n,directed)};
    masks{3}(left,right) = true;
    masks{3}(1:n+1:end) = false;
    if directed
        reverse = false(n); reverse(right,left) = true;
        reverse(1:n+1:end) = false;
        masks{5} = reverse; pairNames{5} = 'betweenrl';
    end
    for r = 1:numel(masks)
        values(end+1) = mean(A(masks{r}),'omitnan'); %#ok<AGROW>
        labels{end+1} = ['Raw_' metric '_' pairNames{r}]; %#ok<AGROW>
    end
end
assert(numel(values) == numel(labels));
if numel(unique(labels)) ~= numel(labels)
    error('organize_graph_block:DuplicateLabel','Region and channel labels collide; rename custom regions.');
end
end

function mask = within(n,idx,directed)
mask = false(n); mask(idx,idx) = true;
if directed, mask(1:n+1:end) = false;
else, mask = tril(mask,-1); end
end
