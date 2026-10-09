function fvx = estimate_mse_pch_fast(data, fs, art)
% Original scale-9 sample entropy; exclude contaminated 100-second blocks.
if nargin < 3, art = false(size(data)); end
validateattributes(data, {'numeric'}, {'row','real','nonempty'});
if ~isequal(size(data),size(art))
    error('estimate_mse_pch_fast:InvalidArt','data and art must have identical sizes.');
end
art = logical(art) | ~isfinite(data);
filled = double(data);
filled(art) = 0;
eeg = resample(filled,128,fs);
mask = resample_art(art,fs,128,numel(eeg));
epl = 100*128;
values = nan(1,floor(numel(eeg)/epl));
for k = 1:numel(values)
    idx = (k-1)*epl+(1:epl);
    if any(mask(idx)), continue; end
    sig = conv(eeg(idx),ones(1,9)/9);
    sig = sig(5:9:end);
    if std(sig) > 0
        values(k) = SampEn(2,0.2*std(sig),sig);
    end
end
values = values(isfinite(values));
fvx = NaN;
if ~isempty(values), fvx = median(values); end
end
