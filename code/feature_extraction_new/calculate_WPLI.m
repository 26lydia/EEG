function wpli = calculate_WPLI(X, Y)
% ---------------------------------------------------------
% Weighted Phase Lag Index (wPLI)
%
% Input:
%   X, Y : signals
%          [1 x N] or [N x 1], same length
%
% Output:
%   wpli : weighted phase lag index, scalar in [0, 1]
%
% Interpretation:
%   wpli ≈ 0 : no consistent phase lag / weak coupling
%   wpli ≈ 1 : strong consistent non-zero phase lag
%   (robust to volume conduction and common sources)
% ---------------------------------------------------------

    Xh = hilbert(X);
    Yh = hilbert(Y);

    Sxy = Xh .* conj(Yh);

    imag_part = imag(Sxy);

    numerator = abs(mean(imag_part));
    denominator = mean(abs(imag_part));

    if denominator == 0
        wpli = 0;
    else
        wpli = numerator / denominator;
    end
end
