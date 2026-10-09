function AEC = calculate_OrthAEC(ch1, ch2)
% ---------------------------------------------------------
% Orthogonalized Amplitude Envelope Correlation (Orth AEC)
% Pairwise signal-level implementation
%
% Inputs:
%   ch1, ch2 : [1 x N] or [N x 1] vectors
%              band-limited signals (same frequency band)
%
% Output:
%   orth_aec : scalar Orth AEC value
%
% Reference:
% 1.Large-scale cortical correlation structure of spontaneous oscillatory activity
% 2.A symmetric multivariate leakage correction for MEG connectomes
% ---------------------------------------------------------

%% 1. Ensure row vectors
ch1 = ch1(:).';
ch2 = ch2(:).';

if isequal(ch1, ch2)
    AEC = 0;
    return
end

%% 2. Hilbert transform (analytic signals)
X1 = hilbert(ch1);
X2 = hilbert(ch2);

A1 = abs(X1);
A2 = abs(X2);

%% 3. Orthogonalization (numerically stable)
eps_val = eps;

% ch2 orthogonalized w.r.t ch1
X2_perp_1 = imag( X2 .* conj(X1) ./ (abs(X1) + eps_val) );
A2_perp_1 = abs(X2_perp_1);

% ch1 orthogonalized w.r.t ch2
X1_perp_2 = imag( X1 .* conj(X2) ./ (abs(X2) + eps_val) );
A1_perp_2 = abs(X1_perp_2);

%% 4. Envelope correlations
r1 = corr(A1', A2_perp_1', 'rows', 'complete');
r2 = corr(A2', A1_perp_2', 'rows', 'complete');

%% 5. Symmetric Orth AEC
AEC = mean([r1, r2]);

end
