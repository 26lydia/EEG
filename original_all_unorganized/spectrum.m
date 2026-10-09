%% Codes for calculating power spectrum and band power

clc;clear
cd("E:\eegdata_infant_2_cut");
Path = "E:\eegdata_infant_2_cut";                     % 设置数据存放的文件夹路径
File = dir(fullfile(Path,'*.mat'));  % 显示文件夹下所有符合后缀名为.txt文件的完整信息
FileNames = {File.name}';
load("E:\info\chanlocs.mat")
% chanloc==
% {'Fp1';'Fp2';'F3';'F4';'C3';'C4';'P3';'P4';'O1';'O2';'T3';'T4';'Cz'}
%额叶：'Fp1';'Fp2';'F3';'F4';
%中央区：'C3';'C4';'Cz';
%顶叶：'P3';'P4';
%枕叶：'O1';'O2';
%颞叶:'T3';'T4';
for region=1:6
    switch region
        case 1
            ROI= {'Fp1';'Fp2';'F3';'F4';'C3';'C4';'P3';'P4';'O1';'O2';'T3';'T4';'Cz'};
        case 2
            ROI= {'Fp1';'Fp2';'F3';'F4'};
        case 3
            ROI= {'C3';'C4';'Cz'};
        case 4
             ROI= {'P3';'P4'};
        case 5
            ROI= {'O1';'O2'};
        case 6
            ROI= {'T3';'T4'};
    end
  chan_id=[];
for i = 1:length(ROI)
    chan_id = [chan_id find(strcmpi(ROI{i},{chanloc.labels}))];
end

%%
for pnum=1
   thre=100;
%    if pnum==27
%        thre=300;
%    end
  cd("E:\eegdata_infant_2_cut");
load(FileNames{pnum,1});
data_sleep=EEG_sleep;
data_sleep_seg=[];num_seg_sleep=floor(size(data_sleep,2)/1000);nt_sleep=1;
for num_seg=1:num_seg_sleep
    data_seg=data_sleep(:,(num_seg-1)*1000+1:1000*num_seg);
    if(max( data_seg(:))<thre&&min(data_seg(:))>-thre)
        data_sleep_seg(:,:,nt_sleep)= data_seg;
        nt_sleep=nt_sleep+1;
    end
end
% cd('D:\jiayang\child_mother_cooperation\code');

% data_wake=EEG_wake;
% data_wake_seg=[];num_seg_wake=floor(size(data_wake,2)/1000);nt_wake=1;
% for num_seg=1:num_seg_wake
%     data_seg=data_wake(:,(num_seg-1)*1000+1:1000*num_seg);
%     if(max( data_seg(:))<thre&&min(data_seg(:))>-thre)
%         data_wake_seg(:,:,nt_wake)= data_seg;
%         nt_wake=nt_wake+1;
%     end
% end

%% loading data and preparation
for con=1:2
    switch con
        case 1
            
EEGdata=data_sleep_seg;
        case 2
            % EEGdata=data_wake_seg;
    end
Ne=size(EEGdata,1); % 导联数目
Np=size(EEGdata,2); % 每个trail的时间点
Nt=size(EEGdata,3); % trial数目

%% pwelch method
win=500;
overlap=100;
fs=500;
Pwelch=[];
for i = 1:Nt
    for channel = 1:Ne
        [Pwelch(channel,:,i),f_welch] = pwelch(EEGdata(channel,:,i),win,overlap,[],fs);
    end
end

% 数据段平均

Pwelch_AVG=mean(Pwelch,3);

Pwelch_AVG_ROI=mean(Pwelch_AVG(chan_id,:),1);
y_welch = Pwelch_AVG_ROI;
delta=find(f_welch>1 & f_welch < 3);
theta=find(f_welch>3 & f_welch < 6);
alpha=find(f_welch>6 & f_welch < 9);
beta=find(f_welch>9 & f_welch < 12);

power_delta=sum(y_welch(delta));
power_theta=sum(y_welch(theta));
power_alpha=sum(y_welch(alpha));
power_beta=sum(y_welch(beta));

power_all=sum(y_welch);

switch con
    case 1
        power_welch_sleep(pnum,:)=[power_delta power_theta power_alpha  power_beta  power_all];
        power_relative_welch_sleep(pnum,:)=[power_delta/power_all power_theta/power_all power_alpha/power_all power_beta/power_all ];
    case 2
        %  power_welch_wake(pnum,:)=[power_delta power_theta power_alpha  power_beta  power_all];
        % power_relative_welch_wake(pnum,:)=[power_delta/power_all power_theta/power_all power_alpha/power_all power_beta/power_all ];
  
end
     

end
end
% result{region,1}= [power_welch_sleep power_welch_wake power_relative_welch_sleep power_relative_welch_wake];
% clear power_welch_sleep power_welch_wake power_relative_welch_sleep power_relative_welch_wake
result{region,1}= [power_welch_sleep power_relative_welch_sleep];
clear power_welch_sleep power_relative_welch_sleep
end
result_all=[];
for r=1:6
result_all=[result_all result{r,1}];
end