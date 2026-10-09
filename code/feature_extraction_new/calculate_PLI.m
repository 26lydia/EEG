function pli = calculate_PLI(X, Y)
% ---------------------------------------------------------
% Phase Lag Index (PLI)
%
% Input:
%   X, Y : signals (same frequency band)
%         [1 x N] or [N x 1]
%
% Output:
%   pli  : scalar PLI value (0–1)
%
% Interpretation:
%   pli ≈ 0 : no consistent phase lag (or zero-lag coupling)
%   pli ≈ 1 : strong consistent non-zero phase lag
% ---------------------------------------------------------


    % Compute cross-spectrum via Hilbert (narrowband)
    Xh = hilbert(X);
    Yh = hilbert(Y);

    Sxy = Xh .* conj(Yh);    % cross-spectrum
    imag_part = imag(Sxy);   % imaginary part

    pli = abs(mean(sign(imag_part)));
end