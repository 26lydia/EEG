function plv = calculate_PLV(X, Y) 
% ---------------------------------------------------------
% Phase Locking Value (PLV)
%
% Input:
%   X, Y : EEG signals
%         [1 x N] or [N x 1], equal length
%
% Output:
%   plv  : scalar PLV value (0–1)
%
% Interpretation:
%   plv ≈ 0 : weak or no phase synchronization
%   plv ≈ 1 : strong phase synchronization
% --------------------------------------------------------- 

    phaseX = angle(hilbert(X)); 
    phaseY = angle(hilbert(Y)); 
    
    phaseDiff = phaseX - phaseY; 
    
    plv = abs(mean(exp(1i * phaseDiff))); 
    
end