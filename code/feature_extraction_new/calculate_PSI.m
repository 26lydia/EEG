function psi = calculate_PSI(x, y, fs, varargin)
% ---------------------------------------------------------
% Phase Slope Index (PSI) - Nolte et al., 2008
%
% Input:
%   x, y : signals (same frequency band)
%          [1 x N] or [N x 1]
%   fs   : sampling frequency (Hz)
%
% Optional:
%   window_length (sec), default = 2
%   overlap_ratio, default = 0.5
%
% Output:
%   psi  : scalar PSI
%
% Interpretation:
%   psi > 0 : x leads y
%   psi < 0 : y leads x
% ---------------------------------------------------------

%% -------------------- Parameters -------------------------
p = inputParser;
addOptional(p, 'window_length', 2);   % seconds
addOptional(p, 'overlap_ratio', 0.5);
parse(p, varargin{:});

win_len = round(p.Results.window_length * fs);
noverlap = round(win_len * p.Results.overlap_ratio);
nfft = max(2^nextpow2(win_len), win_len);

%% -------------------- Shape ------------------------------
x = x(:);
y = y(:);

if length(x) ~= length(y)
    error('Signals must have equal length');
end

%% -------------------- Spectral estimation ----------------
[Sxy, f] = cpsd(x, y, win_len, noverlap, nfft, fs);
[Sxx, ~] = pwelch(x, win_len, noverlap, nfft, fs);
[Syy, ~] = pwelch(y, win_len, noverlap, nfft, fs);

%% -------------------- Coherency ---------------------------
Cxy = Sxy ./ sqrt(Sxx .* Syy);   % complex coherency

%% -------------------- Remove DC & edge -------------------
valid = f > 0;          % remove DC
C = Cxy(valid);

if numel(C) < 3
    psi = 0;
    return;
end

%% -------------------- PSI (Nolte 2008) -------------------
dC = diff(C);
C0 = C(1:end-1);

numerator   = imag(sum(conj(C0) .* dC));
denominator = sum(abs(conj(C0) .* dC));

if denominator > 0
    psi = numerator / denominator;
else
    psi = 0;
end

end
