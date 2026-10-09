function test_feature_extraction
% Synthetic regression tests; no original EEG files are modified.
root = fileparts(mfilename('fullpath'));
addpath(root,'-begin');
rng(7);
fs = 128;
t = (0:12*fs-1)/fs;
data = [20*sin(2*pi*8*t)+randn(size(t)); ...
    15*sin(2*pi*8*t+0.4)+randn(size(t))];
[f,names] = features_all(data,false(size(data)),fs,300,'alpha');
assert(isequal(size(f),[1 13]) && numel(names) == 32);
assert(isequal(size(f{1}),[20 2]));
assert(all(isfinite(f{1}([1:5 20],:)),'all'));
for k = 2:13, assert(isequal(size(f{k}),[2 2])); end
assert(abs(f{7}(1,2)-f{7}(2,1)) < 1e-12);
assert(abs(f{10}(1,2)+f{10}(2,1)-1) < 1e-12);
assert(f{6}(1,1) == 0 && f{10}(1,1) == 0.5);

[f,~] = features_all(data,true(size(data)),fs,300,'full');
for k = 1:13, assert(all(isnan(f{k}),'all')); end
mask = false(size(data)); mask(1,1:6*fs) = true;
[f,~] = features_all(data,mask,fs,300,'alpha');
assert(all(isnan(f{1}(1:5,1))));
assert(all(isnan(f{7}(1,:))) && isfinite(f{7}(2,2)));
[f,~] = features_all(data(:,1:fs),false(2,fs),fs,300,'full');
assert(isequal(size(f{1}),[20 2]));
assert(all(isnan(f{7}),'all'));
[f,~] = features_all(zeros(2,fs*12),false(2,fs*12),fs,300,'full');
assert(all(isnan(f{7}),'all'));
thrown = false;
try, features_all(data,false(1,3),fs,300,'full');
catch ME, thrown = strcmp(ME.identifier,'features_all:InvalidArt'); end
assert(thrown);

% One-sample ART survives downsampling; partial seconds are not false ART.
assert(isnan(calculate_MI(ones(10,1),ones(10,1),18)));
assert(isnan(SampEn(2,0,[1 1 1])));
assert(isequaln(SampEn(2,0.2,data(1,:),2),SampEn(2,0.2,data(1,1:2:end))));
nonfinite = data; nonfinite(1,1) = NaN;
[f,~] = features_all(nonfinite,false(size(data)),fs,300,'alpha');
assert(isfinite(f{1}(1,1)) && isnan(f{7}(1,2)));
mask = false(1,5000); mask(2500) = true;
assert(any(resample_art(mask,500,128,1280)));
assert(~any(detect_art(ones(1,501),500,500,0.01,0)));
mask = detect_art([ones(1,500),600],500,500,0.01,0);
assert(mask(end) && ~any(mask(1:500)));
mask = detect_art([ones(1,500),NaN],500,500,0.01,0);
assert(mask(end));
assert(all(isnan(calculateSC_NS_pch(data,fs,true(size(data))))));
assert(isnan(estimate_mse_pch_fast(data(1,:),fs,true(size(t)))));
assert(isfinite(calculateSC_NS_pch(data(1,:),fs,false(size(t)))));

% All long epochs contribute, rather than only the first/last epoch.
t = (0:220*fs-1)/fs;
longData = 20*sin(2*pi*2*t).*(1+0.8*sin(2*pi*0.05*t))+randn(size(t));
[f,~] = features_all(longData,false(size(longData)),fs,100,'full');
assert(isfinite(f{1}(19)));
assert(isfinite(f{1}(16)));
a = burst_features(longData(1:100*fs),false(1,100*fs),fs);
b = burst_features(longData(100*fs+1:200*fs),false(1,100*fs),fs);
c = burst_features(longData(200*fs+1:end),false(1,20*fs),fs);
expected = mean([a b c],2,'omitnan');
assert(isequaln(f{1}(6:18),expected));

% Non-integer resample length and supplied ART in the batch interface.
t = (0:500*12)/500;
x = [20*sin(2*pi*8*t);15*sin(2*pi*8*t+0.4)];
[f,~] = features_all(x,false(size(x)),500,300,'alpha');
assert(isequal(size(f{1}),[20 2]));
tmp = tempname; mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp,'s'));
input = fullfile(tmp,'input'); output = fullfile(tmp,'output');
mkdir(input); mkdir(output);
alpha = x; alpha_art = false(size(x)); meta = 'metadata'; %#ok<NASGU>
save(fullfile(input,'test.mat'),'alpha','alpha_art','meta');
report = main(input,output,500,300);
assert(strcmp(report.status,'saved'));
loaded = load(fullfile(output,'test.mat'));
assert(isequal(fieldnames(loaded.EEG),{'alpha'}));
assert(isequal(loaded.EEG.alpha.art,alpha_art));
assert(numel(loaded.EEG.alpha.flist) == 32);
report = main(input,output,500,300);
assert(strcmp(report.status,'skipped'));
thrown = false;
try, main(input,input,500,300);
catch ME, thrown = strcmp(ME.identifier,'main:SameFolder'); end
assert(thrown);

% Dependency resolution must not use the original feature_extraction folder.
[required,~] = matlab.codetools.requiredFilesAndProducts(fullfile(root,'main.m'));
for k = 1:numel(required)
    assert(startsWith(required{k},root),required{k});
end
fprintf('All feature extraction regression tests passed.\n');
end
