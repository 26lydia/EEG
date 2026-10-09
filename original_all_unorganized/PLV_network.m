clc;clear
cd('F:\infant\脑电数据\母乳喂养预处理');
Path = 'F:\infant\脑电数据\母乳喂养预处理\';                   % 设置数据存放的文件夹路径
File = dir(fullfile(Path,'*.mat'));  % 显示文件夹下所有符合后缀名为.txt文件的完整信息
FileNames = {File.name}'; 
%%
load('hehaohan.mat')
%for i=9
    plv_sleep_all=[];plv_wake_all=[];
%     cd('F:\infant\脑电数据\母乳喂养预处理');
% load(File(i,1).name)
for fre=1:4
    %每个频率分开计算PLV
    switch fre
        case 1
            data_sleep=EEG_delta_sleep;
            data_wake=EEG_delta_wake;
        case 2
            data_sleep=EEG_theta_sleep;
            data_wake=EEG_theta_wake;
        case 3
            data_sleep=EEG_alpha_sleep;
            data_wake=EEG_alpha_wake;
        case 4
            data_sleep=EEG_beta_sleep;
            data_wake=EEG_beta_wake;
    end
    %睡眠状态PLV
    data_sleep_seg=[];num_seg_sleep=floor(size(data_sleep,2)/1000);nt_sleep=1;
    for num_seg=1:num_seg_sleep
        data_seg=data_sleep(:,(num_seg-1)*1000+1:1000*num_seg);
        if(max( data_seg(:))<100&&min(data_seg(:))>-100)
            data_sleep_seg(:,:,nt_sleep)= data_seg;
            nt_sleep=nt_sleep+1;
        end
    end
    cd('F:\infant');
    toi=1:1000;
      [plv_sleep] = pn_eegPLV_hyper( data_sleep_seg,toi);
      plv_sleep_all(:,:,fre)=plv_sleep;
      
      
       data_wake_seg=[];num_seg_wake=floor(size(data_wake,2)/1000);nt_wake=1;
    for num_seg=1:num_seg_wake
        data_seg=data_wake(:,(num_seg-1)*1000+1:1000*num_seg);
        if(max( data_seg(:))<100&&min(data_seg(:))>-100)
            data_wake_seg(:,:,nt_wake)= data_seg;
            nt_wake=nt_wake+1;
        end
    end
    % cd('D:\jiayang\child_mother_cooperation\code');
    toi=1:1000;
      [plv_wake] = pn_eegPLV_hyper( data_wake_seg,toi);
      plv_wake_all(:,:,fre)=plv_wake;
end
%%
cd('F:\infant\2019_03_03_BCT');i=1;
for fre=1:4

plv_sleep=plv_sleep_all(:,:,fre);
p=0.3;
%W= threshold_proportional(plv_infant, p);
W= threshold_proportional(plv_sleep, p);
W1= weight_conversion(W, 'binarize'); % 两个参数，weight_conversion.m代码里有说
Degree=degrees_und(W1);

D=distance_bin(W1);
[lambda_sleep(i,fre),efficiency_sleep(i,fre),ecc,radius,diameter] = charpath(D,0,0);
eff_global_sleep(i,fre)=efficiency_wei(W1);%全局效率
eff_local_sleep(i,fre)=mean(efficiency_wei(W1,1));%局部效率
cc_all_sleep(i,fre) =mean(clustering_coef_wu(W1));%聚类系数


plv_wake=plv_wake_all(:,:,fre);
p=0.3;
%W= threshold_proportional(plv_infant, p);
W= threshold_proportional(plv_wake, p);
W1= weight_conversion(W, 'binarize'); % 两个参数，weight_conversion.m代码里有说
Degree=degrees_und(W1);

D=distance_bin(W1);
[lambda_wake(i,fre),efficiency_wake(i,fre),ecc,radius,diameter] = charpath(D,0,0);
eff_global_wake(i,fre)=efficiency_wei(W1);%全局效率
eff_local_wake(i,fre)=mean(efficiency_wei(W1,1));%局部效率
cc_all_wake(i,fre) =mean(clustering_coef_wu(W1));%聚类系数
end
%end