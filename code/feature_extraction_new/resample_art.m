function mask = resample_art(art, fs, targetFs, outputLength)
% Preserve narrow ART events and exclude the support of the resample FIR.
validateattributes(fs, {'numeric'}, {'scalar','integer','positive'});
validateattributes(targetFs, {'numeric'}, {'scalar','integer','positive'});
mask = false(size(art,1),outputLength);
if fs == targetFs
    mask = logical(art(:,1:outputLength));
    return;
end
guard = ceil(10*max(1,targetFs/fs));
for ch = 1:size(art,1)
    starts = find(diff([false logical(art(ch,:)) false]) == 1);
    stops = find(diff([false logical(art(ch,:)) false]) == -1)-1;
    for k = 1:numel(starts)
        first = max(1,floor((starts(k)-1)*targetFs/fs)+1-guard);
        last = min(outputLength,ceil(stops(k)*targetFs/fs)+guard);
        mask(ch,first:last) = true;
    end
end
end
