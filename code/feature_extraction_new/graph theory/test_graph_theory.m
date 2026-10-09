function test_graph_theory
root = fileparts(mfilename('fullpath'));
addpath(root,'-begin');
A = ones(3)-eye(3);
regions = struct('Left',[1 2],'Right',3);
[v,l,info] = graph_metrics(A,'PLV',1,regions);
assert(numel(v) == 23 && numel(l) == 23 && strcmp(info.status,'ok'));
assert(isequal(v(1:5),[2 2 2 2 2]));
assert(isequal(v(6:10),[2 2 2 2 2]));
assert(v(16) == 1 && all(abs(v(17:23)-1) < 1e-12));
assert(all(isnan(v(11:15))));
[v,~,~] = graph_metrics(zeros(3),'MSC',1,regions);
assert(all(v(1:10) == 0) && isinf(v(16)) && all(v(17:23) == 0));
chain = [0 1 0;1 0 1;0 1 0];
[v,~,~] = graph_metrics(chain,'PLV',1,regions);
assert(abs(v(16)-4/3) < 1e-12);
assert(abs(v(22)-5/6) < 1e-12);
[v,~,info] = graph_metrics(nan(3),'PLV',1,regions);
assert(all(isnan(v)) && strcmp(info.status,'missing_connections'));
missing = A; missing(1,2) = NaN; missing(2,1) = NaN;
[v,~,info] = graph_metrics(missing,'PLV',1,regions);
assert(all(isnan(v)) && strcmp(info.status,'missing_connections'));
diagNaN = A; diagNaN(1:4:end) = NaN;
[v,~,~] = graph_metrics(diagNaN,'PLV',1,regions);
assert(v(16) == 1);

psi = [0 0.3 -0.2;-0.3 0 0.1;0.2 -0.1 0];
[v,~,info] = graph_metrics(psi,'PSI',1,regions);
assert(nnz(info.weights) == 3 && all(info.weights(:) >= 0));
assert(all(v(1:5) == 1) && all(v(11:15) == 1));
assert(all(isnan(v(16:23))));
dpli = [0.5 0.8 0.5;0.2 0.5 0.4;0.5 0.6 0.5];
[~,~,info] = graph_metrics(dpli,'DPLI',1,regions);
assert(nnz(info.weights) == 2 && abs(info.weights(1,2)-0.3) < 1e-12);
[v,~,info] = graph_metrics(0.5*ones(3),'DPLI',1,regions);
assert(nnz(info.weights) == 0 && all(v(1:15) == 0));
[~,~,info] = graph_metrics(-A,'ImCoh',1,regions);
assert(isequal(info.weights,A));
[~,~,info] = graph_metrics(-A,'COR',1,regions);
assert(~any(info.weights,'all'));
[v,~,~] = graph_metrics(A*2,'MI',1,regions);
assert(all(abs(v(17:21)-1) < 1e-12) && v(16) == 0.5 && v(22) == 2);
assert(nnz(threshold_proportional(A,0)) == 0);
assert(isequal(threshold_proportional(A,1),A));
expect_error(@() threshold_proportional(A,1.1));
expect_error(@() graph_metrics([0 1;0 0],'PLV',1));
expect_error(@() graph_metrics(A,'unknown',1));
expect_error(@() graph_regions(3,struct('Left',[1 4])));

% Labels follow saved flist, and fully ART channels never become zero edges.
block = struct('feats',{{[10 20 30;40 50 60],A,psi}}, ...
    'flist',{{'FeatureB','FeatureA','PhaseLockingValue','PhaseSlopeIndex'}}, ...
    'art',false(3,100));
[values,labels,q] = organize_graph_block(block,1,regions);
assert(values(strcmp(labels,'FeatureB_Whole')) == 20);
assert(values(strcmp(labels,'FeatureA_Channel2')) == 50);
assert(numel(labels) == numel(values) && q.artFraction == 0);
assert(values(strcmp(labels,'Raw_PhaseSlopeIndex_betweenlr')) == -0.05);
assert(values(strcmp(labels,'Raw_PhaseSlopeIndex_betweenrl')) == 0.05);
block.art(3,:) = true;
block.feats{2}(3,:) = NaN; block.feats{2}(:,3) = NaN;
[values,labels,q] = organize_graph_block(block,1,regions);
assert(isnan(values(strcmp(labels,'FeatureB_Channel3'))));
assert(values(strcmp(labels,'FeatureB_Whole')) == 15);
assert(values(strcmp(labels,'Degreewhole_PhaseLockingValue')) == 1);
assert(sum(q.validChannels) == 2);
block.art(:) = true;
[values,~,q] = organize_graph_block(block,1,regions);
assert(all(isnan(values)) && q.artFraction == 1);
bad = block; bad.flist{end+1} = 'extra';
expect_error(@() organize_graph_block(bad,1,regions));

% Integration with the existing ART-aware feature_extraction_new output.
parent = '/Volumes/Elements/code/feature_extraction_new';
addpath(parent,'-end');
rng(11); t = (0:12*128-1)/128;
signal = [20*sin(2*pi*8*t)+randn(size(t)); ...
    15*sin(2*pi*8*t+0.4)+randn(size(t))];
[feats,flist] = features_all(signal,false(size(signal)),128,300,'alpha');
alpha = struct('feats',{feats},'flist',{flist},'art',false(size(signal)));
[values,labels,~] = organize_graph_block(alpha);
assert(numel(values) == numel(labels));
assert(isfinite(values(strcmp(labels,'Degreewhole_PhaseLockingValue'))));
assert(isnan(values(strcmp(labels,'Degreeleft_PhaseLockingValue'))));
% Original montage produces 11 region summaries + 13 channel values per row.
montage = alpha;
montage.feats{1} = repmat((1:20).',1,13);
for k = 2:13, montage.feats{k} = ones(13)-eye(13); end
montage.feats{6} = zeros(13); montage.feats{10} = 0.5*ones(13);
montage.art = false(13,100);
[v13,l13,~] = organize_graph_block(montage,1);
assert(numel(v13) == 806 && numel(unique(l13)) == 806);
assert(v13(strcmp(l13,'MedianAmplitudeEnvelope_Anterior')) == 1);
assert(v13(strcmp(l13,'Degreeleft_PhaseLockingValue')) == 12);
reordered = montage;
reordered.feats{1} = flipud(montage.feats{1});
reordered.feats(2:13) = montage.feats(13:-1:2);
reordered.flist = [montage.flist(20:-1:1) montage.flist(32:-1:21)];
[vr,lr,~] = organize_graph_block(reordered,1);
[~,order] = ismember(l13,lr);
assert(isequaln(v13,vr(order)));
[feats,flist] = features_all(signal,true(size(signal)),128,300,'alpha');
allArt = struct('feats',{feats},'flist',{flist},'art',true(size(signal)));
[values,~,~] = organize_graph_block(allArt);
assert(all(isnan(values)));

% Batch: distinct sleep/wake rows, optional clinical data, bad-block isolation.
tmp = tempname; mkdir(tmp); cleanup = onCleanup(@() rmdir(tmp,'s'));
input = fullfile(tmp,'input'); output = fullfile(tmp,'output'); mkdir(input);
EEG = struct('EEG_alpha_sleep',alpha,'EEG_alpha_wake',alpha,'bad',bad); %#ok<NASGU>
save(fullfile(input,'patient1.mat'),'EEG');
EEG = struct('full',allArt); save(fullfile(input,'patient2.mat'),'EEG');
clinical = table("patient1",38,1,2,'VariableNames',{'name','PMA','health','group'});
excel = fullfile(tmp,'clinical.csv'); writetable(clinical,excel);
[T,report,map] = features_all_organize_new(input,excel,output);
assert(height(T) == 3 && height(map) == width(T)-8);
assert(strcmp(report(1).status,'partial') && report(1).rows == 2);
assert(sum(contains(T.EEGVariable,'sleep')) == 1 && sum(contains(T.EEGVariable,'wake')) == 1);
assert(all(T.PMA(T.name == "patient1") == 38) && isnan(T.PMA(T.name == "patient2")));
assert(T.ARTFraction(T.name == "patient2") == 1);
assert(isfile(fullfile(output,'EEG_Feature_Combined.xlsx')));
assert(isfile(fullfile(output,'EEG_Feature_Columns.csv')));
expect_error(@() features_all_organize_new(input,excel,output));
expect_error(@() features_all_organize_new(input,'',input));
clinical = [clinical;clinical]; writetable(clinical,excel);
expect_error(@() features_all_organize_new(input,excel,fullfile(tmp,'duplicate')));
[T,~,~] = features_all_organize_new(input,'',fullfile(tmp,'no_clinical'));
assert(height(T) == 3 && ~ismember('PMA',T.Properties.VariableNames));

[required,~] = matlab.codetools.requiredFilesAndProducts(fullfile(root,'features_all_organize_new.m'));
for k = 1:numel(required), assert(startsWith(required{k},root),required{k}); end
files = dir(fullfile(root,'*.m'));
for k = 1:numel(files)
    issues = checkcode(fullfile(root,files(k).name),'-id');
    assert(~any(ismember({issues.id},{'PARSE','SYNER'})),files(k).name);
end
fprintf('All graph theory regression tests passed (%d MATLAB files).\n',numel(files));
end

function expect_error(fn)
thrown = false;
try, fn(); catch, thrown = true; end
assert(thrown,'Expected input validation to fail.');
end
