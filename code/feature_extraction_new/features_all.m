function [feats, flist] = features_all(data, art, fs1, epl, varName)
% FEATURES_ALL ART-aware EEG features, based on the original features_all_new.
% feats{1}: 20 x channels; feats{2:13}: channels x channels.
% flist{1:20} labels rows of feats{1}; flist{21:32} labels feats{2:13}.
validateattributes(data, {'numeric'}, {'2d','real','nonempty'}, mfilename, 'data');
validateattributes(fs1, {'numeric'}, {'scalar','integer','positive'});
validateattributes(epl, {'numeric'}, {'scalar','real','finite','positive'});
if ~isequal(size(data), size(art)) || ...
        ~(isnumeric(art) || islogical(art)) || ...
        any(~isfinite(art(:))) || any(art(:) ~= 0 & art(:) ~= 1)
    error('features_all:InvalidArt', 'art must be a binary matrix with the same size as data.');
end
if nargin < 5, varName = 'full'; end
% Band-limited records are commonly named EEG_alpha_sleep, EEG_beta_wake,
% etc.  Treat those names like the historical exact alpha/beta/theta/delta
% names: burst/suppression descriptors are not meaningful on a band-only
% signal, while the envelope/energy and connectivity features remain valid.
isBandSpecific = ~isempty(regexpi(char(varName), ...
    '(^|[_-])(alpha|beta|theta|delta)([_-]|$)', 'once'));
validateattributes(epl*fs1, {'numeric'}, {'integer'});
validateattributes(epl*128, {'numeric'}, {'integer'});
data = double(data);
art = logical(art) | ~isfinite(data);
n_channels = size(data,1);
fs2 = 128;
% Fill excluded samples only for filtering; they remain excluded by the mask.
filled = data;
for ch = 1:n_channels
    valid = find(~art(ch,:));
    if numel(valid) < 2
        filled(ch,:) = 0;
    else
        filled(ch,:) = interp1(valid, data(ch,valid), 1:size(data,2), 'linear', 'extrap');
    end
end
dat64 = resample(filled.', fs2, fs1).';
a64 = resample_art(art, fs1, fs2, size(dat64,2));
sum_single = zeros(20,n_channels);
cnt_single = zeros(20,n_channels);
sum_pair = zeros(n_channels,n_channels,12);
cnt_pair = zeros(n_channels,n_channels,12);

% Non-overlapping long epochs: burst descriptors and sample entropy.
long_values = nan(14,n_channels,ceil(size(data,2)/(epl*fs1)));
epoch = 0;
for first = 1:epl*fs1:size(data,2)
    epoch = epoch + 1;
    last = min(size(data,2), first + epl*fs1 - 1);
    lowfirst = floor((first-1)*fs2/fs1)+1;
    lowlast = min(size(dat64,2), floor(last*fs2/fs1));
    for ch = 1:n_channels
        sig = dat64(ch,lowfirst:lowlast);
        mask = a64(ch,lowfirst:lowlast);
        if isempty(sig) || mean(mask) >= 0.5, continue; end
        if ~isBandSpecific
            long_values(1:13,ch,epoch) = burst_features(sig, mask, fs2);
        end
        long_values(14,ch,epoch) = estimate_mse_pch_fast( ...
            data(ch,first:last), fs1, art(ch,first:last));
    end
end

% Preserve the original 10-second windows / 2-second overlap.
% Short recordings use one shorter window; long recordings use full windows.
win = min(size(dat64,2), 10*fs2);
hop = 8*fs2;
for first = 1:hop:size(dat64,2)-win+1
    last = first+win-1;
    values = nan(20,n_channels);
    for ch = 1:n_channels
        sig = dat64(ch,first:last);
        mask = a64(ch,first:last);
        if mean(mask) >= 0.5, continue; end
        envelope = abs(hilbert(sig));
        q = quantile(envelope(~mask), [0.05 0.25 0.5 0.75 0.95]);
        values(1:5,ch) = q([3 1 2 4 5]).';
        centered = sig - mean(sig(~mask));
        centered(mask) = 0;
        power = abs(fft(centered)).^2 / sum(~mask);
        energy = sum(2*power(1:ceil(numel(sig)/2)));
        if energy > 0, values(20,ch) = log(energy); end
    end
    good = isfinite(values);
    sum_single(good) = sum_single(good)+values(good);
    cnt_single(good) = cnt_single(good)+1;
    for ch1 = 1:n_channels
        for ch2 = ch1:n_channels
            % Never concatenate samples across ART gaps for phase/spectral metrics.
            if any(a64(ch1,first:last) | a64(ch2,first:last)), continue; end
            x = dat64(ch1,first:last).';
            y = dat64(ch2,first:last).';
            if numel(x) < 2*fs2 || std(x) == 0 || std(y) == 0, continue; end
            window = hamming(fs2);
            [sxx,~] = pwelch(x,window,floor(0.7*fs2),fs2,fs2);
            [syy,~] = pwelch(y,window,floor(0.7*fs2),fs2,fs2);
            [sxy,~] = cpsd(x,y,window,floor(0.7*fs2),fs2,fs2);
            coh = sxy./sqrt(sxx.*syy);
            coh = coh(isfinite(coh));
            msc = NaN; imcoh = NaN;
            if ~isempty(coh)
                msc = mean(abs(coh).^2);
                imcoh = max(imag(coh));
            end
            v = [corr(x,y), max(xcorr(x,y,'normalized')), msc, imcoh, ...
                calculate_PSI(x,y,fs2), calculate_PLV(x,y), ...
                calculate_PLI(x,y), calculate_WPLI(x,y), ...
                calculate_DPLI(x,y), calculate_RHO(x,y,18), ...
                calculate_MI(x,y,18), calculate_OrthAEC(x,y)];
            reverse = v;
            reverse(5) = -v(5);
            reverse(9) = 1-v(9);
            if ch1 == ch2, v(5) = 0; v(9) = 0.5; end
            for k = 1:12
                if isfinite(v(k))
                    sum_pair(ch1,ch2,k) = sum_pair(ch1,ch2,k)+v(k);
                    cnt_pair(ch1,ch2,k) = cnt_pair(ch1,ch2,k)+1;
                    if ch1 ~= ch2
                        sum_pair(ch2,ch1,k) = sum_pair(ch2,ch1,k)+reverse(k);
                        cnt_pair(ch2,ch1,k) = cnt_pair(ch2,ch1,k)+1;
                    end
                end
            end
        end
    end
end
single = sum_single./cnt_single;
single(6:19,:) = mean(long_values,3,'omitnan');
pair = sum_pair./cnt_pair;
feats = cell(1,13);
feats{1} = single;
for k = 1:12, feats{k+1} = pair(:,:,k); end
flist = {'MedianAmplitudeEnvelope', '5thPercentileAmplitudeEnvelope', ...
    '25thPercentileAmplitudeEnvelope', '75thPercentileAmplitudeEnvelope', ...
    '95thPercentileAmplitudeEnvelope', '5thPercentileInterburstInterval', ...
    '50thPercentileInterburstInterval', '95thPercentileInterburstInterval', ...
    '5thPercentileBurstDuration', '50thPercentileBurstDuration', ...
    '95thPercentileBurstDuration', 'BurstSkewnessSymmetry', ...
    'BurstKurtosisSharpness', 'SlopeBurstDurationvsBurstArea', ...
    'InterceptBurstDurationvsBurstArea', 'SuppressionCurve', ...
    'MeanBurstDuration', 'StandardDeviationBurstDurations', 'SampleEntropy', ...
    'LogPSDEnergy', 'CorrelationCoefficient', 'CrossCorrelation', ...
    'MagnitudeSquaredCoherence', 'ImaginaryPartofCoherence', 'PhaseSlopeIndex', ...
    'PhaseLockingValue', 'PhaseLagIndex', 'WeightedPhaseLagIndex', ...
    'DirectionalityPhaseLagIndex', 'RhoIndex', 'MutualInformation', ...
    'OrthogonalizedAmplitudeEnvelopeCorrelation'};
end
