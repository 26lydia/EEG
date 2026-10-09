function values = burst_features(sig, art, fs)
% Original burst threshold/shape calculations, excluding ART-overlapping events.
values = nan(13,1);
if numel(sig) < fs || mean(art) >= 0.5, return; end
amp = conv(abs(hilbert(sig)).^2,ones(1,5)/5,'same');
% Smoothing must not leak a flagged sample into neighbouring burst events.
art = conv(double(art),ones(1,5),'same') > 0;
valid = ~art;
if ~any(valid) || max(amp(valid)) <= 0, return; end
thresholds = quantile(amp(valid),linspace(0,1,100));
counts = zeros(size(thresholds));
limit = 3*fs;
for k = 1:numel(thresholds)
    mask = amp >= thresholds(k) & valid;
    starts = find(diff([false mask false]) == 1);
    stops = find(diff([false mask false]) == -1)-1;
    counts(k) = sum(stops-starts+1 > limit);
end
[~,k] = max(counts);
threshold = thresholds(k);
mask = amp >= threshold & valid;
starts = find(diff([false mask false]) == 1);
stops = find(diff([false mask false]) == -1)-1;
keep = true(size(starts));
for k = 1:numel(starts)
    keep(k) = ~any(art(max(1,starts(k)-1):min(numel(art),stops(k)+1)));
end
durations = (stops-starts+1)/fs;
intervals = diff(starts)/fs; % Preserve original start-to-start definition.
intervalKeep = keep(1:end-1) & keep(2:end);
for k = 1:numel(intervals)
    intervalKeep(k) = intervalKeep(k) && ~any(art(starts(k):starts(k+1)));
end
if any(intervalKeep), values(1:3) = quantile(intervals(intervalKeep),[0.05 0.5 0.95]).'; end
if any(keep), values(4:6) = quantile(durations(keep),[0.05 0.5 0.95]).'; end
keep = keep & durations > 3;
starts = starts(keep); stops = stops(keep); durations = durations(keep);
if ~isempty(starts)
    M = ceil(2*mean(durations)*fs*10);
    shape = zeros(1,M);
    areas = zeros(size(starts));
    for k = 1:numel(starts)
        burst = amp(starts(k):stops(k))-threshold;
        pp = pchip(1:numel(burst),burst,linspace(1,numel(burst),M));
        if sum(pp) > 0, shape = shape+pp/sum(pp); end
        areas(k) = trapz(burst)/fs;
    end
    shape = shape-min(shape);
    if sum(shape) > 0
        shape = shape/sum(shape);
        xx = linspace(0,1,M);
        mn = sum(xx.*shape);
        sd = sqrt(sum((xx-mn).^2.*shape));
        if sd > 0
            values(7) = sum((xx-mn).^3.*shape)/sd^3;
            values(8) = sum((xx-mn).^4.*shape)/sd^4-3;
        end
    end
    good = durations > 0 & areas > 0;
    if sum(good) >= 2 && numel(unique(durations(good))) >= 2
        values(9:10) = polyfit(log(durations(good)),log(areas(good)),1).';
    end
    values(12) = mean(durations);
    values(13) = std(durations);
end
values(11) = calculateSC_NS_pch(sig,fs,art);
end
