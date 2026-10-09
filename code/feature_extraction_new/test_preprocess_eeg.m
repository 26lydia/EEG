function test_preprocess_eeg
% Synthetic checks for explicit preprocessing and optional batch integration.
root = fileparts(mfilename('fullpath'));
addpath(root,'-begin');
fs = 128;
t = (0:20*fs-1)/fs;
base = 20*sin(2*pi*8*t) + 5*sin(2*pi*50*t);
x = [base; base];
x(1,500:520) = NaN;
x(1,1000:1200) = NaN;
x(1,1:10) = NaN;
[clean,mask,info] = preprocess_eeg(x,fs,[],struct('MaxGapSeconds',0.25,'LowpassHz',30));
assert(all(isfinite(clean(1,500:520))) && ~any(mask(1,500:520)));
assert(all(isnan(clean(1,1000:1200))) && all(mask(1,1000:1200)));
assert(all(mask(1,1:10)) && all(isnan(clean(1,1:10))));
assert(info.interpolatedSamples == 21);
assert(all(isfinite(clean(2,:))));
assert(abs(dot(clean(2,:),sin(2*pi*8*t))/numel(t)*2-20) < 2);
assert(abs(dot(clean(2,:),sin(2*pi*50*t))/numel(t)*2) < 0.5);
[notched,~,~] = preprocess_eeg(x,fs,[],struct('LowpassHz',45,'LineHz',20));
assert(all(isfinite(notched(2,:))));
bad = false(size(x)); bad(2,800:805) = true;
[y,a] = preprocess_eeg(x,fs,bad);
assert(all(isfinite(y(2,800:805))) && ~any(a(2,800:805)));
failed = false;
try, preprocess_eeg(x,fs,[],struct('LowpassHz',fs));
catch ME, failed = strcmp(ME.identifier,'preprocess_eeg:Band'); end
assert(failed);
failed = false;
try, preprocess_eeg(x,fs,ones(1,2));
catch ME, failed = strcmp(ME.identifier,'preprocess_eeg:Art'); end
assert(failed);
tmp = tempname; mkdir(tmp); cleanup = onCleanup(@() rmdir(tmp,'s'));
input = fullfile(tmp,'in'); output = fullfile(tmp,'out');
mkdir(input); mkdir(output);
alpha = [base; base]; alpha(1,500:520) = NaN; %#ok<NASGU>
save(fullfile(input,'case.mat'),'alpha');
report = main(input,output,fs,300,struct('MaxGapSeconds',0.25));
assert(strcmp(report.status,'saved'),report.message);
result = load(fullfile(output,'case.mat'));
assert(result.EEG.alpha.preprocessing.interpolatedSamples == 21);
assert(~any(result.EEG.alpha.art(1,500:520)));
assert(numel(result.EEG.alpha.flist) == 32);
fprintf('All preprocessing regression tests passed.\n');
end
