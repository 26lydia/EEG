function [cleaned, art, info] = preprocess_eeg(data, fs, art, options)
%PREPROCESS_EEG Detect invalid samples, interpolate short gaps, and filter EEG.
% Data is channels x samples. art=1 means excluded; omitted art is detected.
% Only internal gaps of at most MaxGapSeconds are admitted after interpolation.
if nargin < 2, error('preprocess_eeg:Arguments','data and fs are required.'); end
validateattributes(data,{'numeric'},{'2d','real','nonempty'},mfilename,'data');
validateattributes(fs,{'numeric'},{'scalar','real','finite','positive'},mfilename,'fs');
if nargin < 3 || isempty(art)
    art = detect_art(data,fs,500,0.01,0);
end
if nargin < 4 || isempty(options), options = struct(); end
if ~isstruct(options) || ~isscalar(options) || ...
        any(~ismember(fieldnames(options),{'HighpassHz','LowpassHz','LineHz','MaxGapSeconds'}))
    error('preprocess_eeg:Options','Unsupported preprocessing options.');
end
if ~isequal(size(data),size(art)) || ~(isnumeric(art) || islogical(art)) || ...
        any(~isfinite(art(:))) || any(art(:) ~= 0 & art(:) ~= 1)
    error('preprocess_eeg:Art','art must be a binary matrix matching data.');
end
high = 0.5; low = 45; line = []; maxGap = 0.5;
if isfield(options,'HighpassHz'), high = options.HighpassHz; end
if isfield(options,'LowpassHz'), low = options.LowpassHz; end
if isfield(options,'LineHz'), line = options.LineHz; end
if isfield(options,'MaxGapSeconds'), maxGap = options.MaxGapSeconds; end
validateattributes(high,{'numeric'},{'scalar','finite','positive'});
validateattributes(low,{'numeric'},{'scalar','finite','positive'});
validateattributes(maxGap,{'numeric'},{'scalar','finite','nonnegative'});
if high >= low || low >= fs/2
    error('preprocess_eeg:Band','Require 0 < HighpassHz < LowpassHz < fs/2.');
end
if ~isempty(line)
    validateattributes(line,{'numeric'},{'scalar','finite','positive'});
    if line-1 <= 0 || line+1 >= fs/2
        error('preprocess_eeg:Line','LineHz +/- 1 must be inside (0, fs/2).');
    end
end
data = double(data);
originalArt = logical(art) | ~isfinite(data);
art = originalArt;
cleaned = data;
interpolated = false(size(data));
maxSamples = floor(maxGap*fs);
[z,p,g] = butter(2,[high low]/(fs/2),'bandpass');
[sos,scale] = zp2sos(z,p,g);
if ~isempty(line) && line < low
    [nz,np,ng] = butter(2,[line-1 line+1]/(fs/2),'stop');
    [notchSos,notchScale] = zp2sos(nz,np,ng);
end
for ch = 1:size(data,1)
    good = find(~originalArt(ch,:));
    if numel(good) < 2
        cleaned(ch,:) = NaN;
        art(ch,:) = true;
        continue;
    end
    starts = find(diff([false originalArt(ch,:) false]) == 1);
    stops = find(diff([false originalArt(ch,:) false]) == -1)-1;
    for k = 1:numel(starts)
        a = starts(k); b = stops(k);
        if a > 1 && b < size(data,2) && b-a+1 <= maxSamples
            cleaned(ch,a:b) = interp1([a-1 b+1],data(ch,[a-1 b+1]),a:b,'linear');
            art(ch,a:b) = false;
            interpolated(ch,a:b) = true;
        end
    end
    % Provide a continuous signal to zero-phase filters; retain a mask for
    % long/edge gaps and their adjacent filter transient, never use extrapolated
    % boundary values as EEG observations.
    fill = interp1(good,data(ch,good),1:size(data,2),'linear');
    fill(1:good(1)-1) = data(ch,good(1));
    fill(good(end)+1:end) = data(ch,good(end));
    fill(interpolated(ch,:)) = cleaned(ch,interpolated(ch,:));
    try
        filtered = filtfilt(sos,scale,fill);
        if ~isempty(line) && line < low
            filtered = filtfilt(notchSos,notchScale,filtered);
        end
    catch ME
        error('preprocess_eeg:Filter','Filtering failed for channel %d: %s',ch,ME.message);
    end
    cleaned(ch,:) = filtered;
    % Do not expose filter output near missing long stretches as valid signal.
    missing = art(ch,:);
    guard = min(size(data,2),ceil(fs/max(high,0.1)));
    if any(missing)
        art(ch,:) = conv(double(missing),ones(1,2*guard+1),'same') > 0;
    end
    cleaned(ch,art(ch,:)) = NaN;
end
info = struct('originalArtFraction',mean(originalArt(:)), ...
    'interpolatedSamples',sum(interpolated(:)), ...
    'remainingArtFraction',mean(art(:)), ...
    'highpassHz',high,'lowpassHz',low,'lineHz',line,'maxGapSeconds',maxGap);
end
