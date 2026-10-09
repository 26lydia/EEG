function art = detect_art(data, fs, highThreshold, lowThreshold, paddingSeconds)
% Original main.m amplitude rule, including the final partial second.
if nargin < 3, highThreshold = 500; end
if nargin < 4, lowThreshold = 0.01; end
if nargin < 5, paddingSeconds = 5; end
validateattributes(data, {'numeric'}, {'2d','real','nonempty'});
validateattributes(fs, {'numeric'}, {'scalar','integer','positive'});
validateattributes(highThreshold, {'numeric'}, {'scalar','finite','positive'});
validateattributes(lowThreshold, {'numeric'}, {'scalar','finite','nonnegative','<',highThreshold});
validateattributes(paddingSeconds, {'numeric'}, {'scalar','finite','nonnegative'});
art = ~isfinite(data);
for ch = 1:size(data,1)
    for first = 1:fs:size(data,2)
        last = min(size(data,2),first+fs-1);
        sig = data(ch,first:last);
        valid = sig(isfinite(sig));
        if isempty(valid) || max(abs(valid)) > highThreshold || max(abs(valid)) < lowThreshold
            art(ch,first:last) = true;
        end
    end
    starts = find(diff([false art(ch,:) false]) == 1);
    stops = find(diff([false art(ch,:) false]) == -1)-1;
    pad = round(paddingSeconds*fs);
    for k = 1:numel(starts)
        art(ch,max(1,starts(k)-pad):min(size(data,2),stops(k)+pad)) = true;
    end
end
end
