function MI = calculate_MI(X, Y, nbin)
% ---------------------------------------------------------
% Mutual Information (MI)
%
% Input:
%   X, Y  : real-valued signals or feature vectors
%           [1 x N] or [N x 1], same length
%   nbin  : number of bins for discretization
%
% Output:
%   MI    : mutual information value (non-negative scalar)
%
% Interpretation:
%   MI = 0    : X and Y are statistically independent
%   MI > 0    : X and Y share statistical dependency
%   Larger MI : stronger dependency (linear or nonlinear)
% ---------------------------------------------------------

% 1. Discretize X and Y
X = X(:); Y = Y(:);
if numel(X) ~= numel(Y) || isempty(X) || ...
        any(~isfinite(X)) || any(~isfinite(Y))
    error('calculate_MI:InvalidInput', 'Signals must be finite, nonempty and equally sized.');
end
validateattributes(nbin, {'numeric'}, {'scalar','integer','>=',2});
if min(X) == max(X) || min(Y) == max(Y)
    MI = NaN;
    return;
end
edgesX = linspace(min(X), max(X), nbin+1);
edgesY = linspace(min(Y), max(Y), nbin+1);
X_bin = discretize(X, edgesX);
Y_bin = discretize(Y, edgesY);

% 2. Joint histogram
jointHist = accumarray([X_bin(:), Y_bin(:)], 1, [nbin, nbin]);
jointProb = jointHist / sum(jointHist(:));

% 3. Marginal probabilities
pX = sum(jointProb, 2);
pY = sum(jointProb, 1);

% 4. Compute MI
MI = 0;
for i = 1:nbin
    for j = 1:nbin
        if jointProb(i,j) > 0
            MI = MI + jointProb(i,j) * log(jointProb(i,j)/(pX(i)*pY(j)));
        end
    end
end

end
