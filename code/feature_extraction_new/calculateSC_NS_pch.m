function fv = calculateSC_NS_pch(dataEEG, fs, art)
% Original line-length suppression curve, with contaminated windows excluded.
if nargin < 3, art = false(size(dataEEG)); end
if ~isequal(size(dataEEG),size(art))
    error('calculateSC_NS_pch:InvalidArt','dataEEG and art must have identical sizes.');
end
validateattributes(fs, {'numeric'}, {'scalar','integer','>=',8});
art = logical(art) | ~isfinite(dataEEG);
win = fs;
hop = floor(0.125*win);
blocks = max(0,floor((size(dataEEG,2)-win)/hop)+1);
fv = nan(1,size(dataEEG,1));
if blocks == 0, return; end
radius = floor(2.5*60*fs/hop/2);
for ch = 1:size(dataEEG,1)
    ll = nan(1,blocks);
    for k = 1:blocks
        idx = (k-1)*hop+(1:win);
        if ~any(art(ch,idx)), ll(k) = sum(abs(diff(dataEEG(ch,idx)))); end
    end
    normalized = nan(1,blocks);
    for k = 1:blocks
        local = ll(max(1,k-radius):min(blocks,k+radius));
        local = local(isfinite(local));
        denominator = mean(local)*2*radius;
        if isfinite(ll(k)) && denominator > 0
            normalized(k) = ll(k)/denominator;
        end
    end
    curve = nan(1,blocks);
    for k = 1:blocks
        if ~isfinite(normalized(k)), continue; end
        local = normalized(max(1,k-radius):min(blocks,k+radius));
        local = local(isfinite(local));
        if mean(local) > 0, curve(k) = 1-median(local)/mean(local); end
    end
    fv(ch) = mean(curve,'omitnan');
end
end
