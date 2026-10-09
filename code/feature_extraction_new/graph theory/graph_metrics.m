function [values, labels, info] = graph_metrics(A, metric, proportion, regions, validChannels)
% Network descriptors based on the original features_all_organize_new.
% Missing edges are not absent edges: incomplete observed networks return NaN.
if nargin < 3 || isempty(proportion), proportion = 0.4; end
validateattributes(A, {'numeric'}, {'2d','real','square','nonempty'});
validateattributes(proportion, {'numeric'}, {'scalar','finite','>=',0,'<=',1});
n = size(A,1);
if nargin < 4, regions = []; end
regions = graph_regions(n,regions);
if nargin < 5, validChannels = true(1,n); end
if ~islogical(validChannels) || numel(validChannels) ~= n
    error('graph_metrics:InvalidChannels','validChannels must be a logical vector with one entry per channel.');
end
labels = {'Degreemax','Degreemin','Degreeleft','Degreeright','Degreewhole', ...
    'Strengthmax','Strengthmin','Strengthleft','Strengthright','Strengthwhole', ...
    'InDegreemax','InDegreemin','InDegreeleft','InDegreeright','InDegreewhole', ...
    'PathLength','Clusteringmax','Clusteringmin','Clusteringleft', ...
    'Clusteringright','Clusteringwhole','GlobalEfficiency','LocalEfficiency'};
values = nan(1,numel(labels));
nodes = find(validChannels(:).');
info = struct('status','insufficient_channels','usedChannels',nodes,'weights',[]);
directed = false;
allowPath = true;
switch lower(char(metric))
    case {'cor','correlationcoefficient','rho','rhoindex','orthaec', ...
            'orthogonalizedamplitudeenvelopecorrelation', ...
            'msc','magnitudesquaredcoherence','plv','phaselockingvalue', ...
            'pli','phaselagindex','wpli','weightedphaselagindex','mi','mutualinformation'}
        transform = 'positive';
    case {'imcoh','imaginarypartofcoherence'}
        transform = 'absolute';
    case {'xcor','crosscorrelation'}
        transform = 'absolute'; allowPath = false;
    case {'psi','phaseslopeindex'}
        transform = 'positive'; directed = true; allowPath = false;
    case {'dpli','directionalityphaselagindex'}
        transform = 'dpli'; directed = true; allowPath = false;
    otherwise
        error('graph_metrics:UnknownMetric','Unsupported connectivity metric: %s',char(metric));
end
if numel(nodes) < 2, return; end
W = double(A(nodes,nodes));
W(1:size(W,1)+1:end) = 0;
if any(~isfinite(W),'all')
    info.status = 'missing_connections';
    return;
end
if ~directed && max(abs(W-W.'),[],'all') > 1e-10
    error('graph_metrics:Asymmetric','An undirected connectivity matrix must be symmetric.');
end
switch transform
    case 'absolute', W = abs(W);
    case 'dpli'
        if any(W(:) < 0 | W(:) > 1)
            error('graph_metrics:InvalidDPLI','dPLI values must be in [0,1].');
        end
        W = max(W-0.5,0);
    otherwise, W = max(W,0);
end
% Threshold after converting signs/directions, not before.
W = threshold_proportional(W,proportion);
info.weights = W;
info.status = 'ok';
if directed
    [inDegree,outDegree,~] = degrees_dir(W);
    degree = outDegree;
    strength = sum(W,2);
    values(11:15) = summarize(inDegree,nodes,regions);
else
    degree = degrees_und(W);
    strength = strengths_und(W);
end
values(1:5) = summarize(degree,nodes,regions);
values(6:10) = summarize(strength,nodes,regions);
if allowPath
    % BCT distance_wei represents missing edges by zero, not Inf.
    lengths = zeros(size(W));
    positive = W > 0;
    lengths(positive) = 1./W(positive);
    D = distance_wei(lengths);
    values(16) = charpath(D,0,1); % Disconnected graphs have infinite path length.
    clusterW = W/max(1,max(W(:)));
    values(17:21) = summarize(clustering_coef_wu(clusterW),nodes,regions);
    values(22) = efficiency_wei(W,0);
    values(23) = mean(efficiency_wei(W,2));
end
end

function out = summarize(vector,nodes,regions)
vector = vector(:);
left = []; right = [];
if isfield(regions,'Left'), left = ismember(nodes,regions.Left); end
if isfield(regions,'Right'), right = ismember(nodes,regions.Right); end
out = [max(vector),min(vector),mean(vector(left)),mean(vector(right)),mean(vector)];
end
