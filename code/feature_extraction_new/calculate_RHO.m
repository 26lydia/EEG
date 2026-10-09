function rho = calculate_RHO(X, Y, nbins)
% ---------------------------------------------------------
% Phase Entropy Synchronization Index (RHO)
% RHO index based on Shannon entropy of phase difference
%
% Input:
%   X, Y   : real-valued time series signals
%            [1 x N] or [N x 1], same length
%   nbins  : number of phase-difference histogram bins
%            (optional, default = 36)
%
% Output:
%   rho    : phase entropy–based synchronization index,
%            scalar in [0, 1]
%
% Interpretation:
%   rho ≈ 0 : uniform phase difference distribution
%             (no phase synchronization)
%   rho ≈ 1 : highly peaked phase difference distribution
%             (strong phase synchronization)
% ---------------------------------------------------------

    if nargin < 3
        nbins = 36; % default resolution
    end

    % ---- 1. Compute instantaneous phases ----
    phaseX = angle(hilbert(X));
    phaseY = angle(hilbert(Y));

    % ---- 2. Phase difference ----
    dphi = phaseX - phaseY;
    dphi = mod(dphi + pi, 2*pi) - pi; % wrap to [-pi, pi]

    % ---- 3. Histogram (probability distribution) ----
    edges = linspace(-pi, pi, nbins+1);
    counts = histcounts(dphi, edges);
    p = counts / sum(counts); % normalize to probability

    % Avoid log(0)
    p(p==0) = [];

    % ---- 4. Shannon entropy ----
    S = -sum(p .* log(p));

    % ---- 5. Maximum entropy (uniform distribution) ----
    Smax = log(nbins);

    % ---- 6. RHO ----
    rho = (Smax - S) / Smax;
end
