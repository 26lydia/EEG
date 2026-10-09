function dpli = calculate_DPLI(X, Y)
% ---------------------------------------------------------
% Directed Phase Lag Index (dPLI)
%
% Input:
%   X, Y : real-valued time series signals
%          [1 x N] or [N x 1], same length
%
% Output:
%   dpli : directed phase lag index, scalar in [0, 1]
%
% Interpretation:
%   dpli > 0.5 : X leads Y
%   dpli < 0.5 : Y leads X
%   dpli ≈ 0.5 : no preferred direction / symmetric coupling
% ---------------------------------------------------------

    % analytic phases
    phaseX = angle(hilbert(X));
    phaseY = angle(hilbert(Y));

    % wrapped phase difference in [-pi, pi]
    dphi = angle(exp(1i*(phaseX - phaseY)));

    % remove zero-lag samples
    valid = abs(dphi) > 1e-6;
    if sum(valid) < 10
        dpli = 0.5;
        return;
    end

    % Heaviside step
    dpli = mean(dphi(valid) > 0);

end
