function regions = graph_regions(n, custom)
% Original 13-channel ordering; other montages need explicit custom regions.
validateattributes(n, {'numeric'}, {'scalar','integer','positive'});
if nargin < 2 || isempty(custom)
    regions = struct('Whole',1:n);
    if n == 13
        regions.Anterior = [1 2 3 4 5 6 11 12 13];
        regions.Posterior = [5 6 7 8 9 10 11 12 13];
        regions.Left = [1 3 5 7 9 11 13];
        regions.Right = [2 4 6 8 10 12 13];
        regions.Frontalpole = [1 2];
        regions.Frontal = [3 4];
        regions.Central = [5 6 13];
        regions.Parietal = [7 8];
        regions.Occipital = [9 10];
        regions.Temporal = [11 12];
    end
else
    if ~isstruct(custom) || ~isscalar(custom)
        error('graph_regions:InvalidRegions','Regions must be a scalar struct of channel indices.');
    end
    regions = custom;
    regions.Whole = 1:n;
end
names = fieldnames(regions);
for k = 1:numel(names)
    idx = regions.(names{k});
    if ~isempty(idx)
        validateattributes(idx, {'numeric'}, {'vector','integer','>=',1,'<=',n});
        if numel(unique(idx)) ~= numel(idx)
            error('graph_regions:DuplicateChannel','Region %s repeats a channel.',names{k});
        end
    end
    regions.(names{k}) = idx(:).';
end
end
