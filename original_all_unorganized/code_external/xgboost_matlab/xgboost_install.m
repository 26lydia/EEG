% Step 1:
% Download the wheel file from https://s3-us-west-2.amazonaws.com/xgboost-nightly-builds/list.html
% (see https://xgboost.readthedocs.io/en/latest/build.html)

% Step 2:
% Set the xgboost_install_dir and wheel_fn in xgboost_install.m

% Step 3:
% run xgboost_install

%xgboost_install_dir = 'd:\cpcardio\physionet_2020\xgboost';
xgboost_install_dir = 'E:\code\xgboost_matlab\lib';
%wheel_fn = 'E:\code\xgboost_matlab\xgboost-2.1.3+b8cfb5691a318e9f2914cf89454a8b37bd8ec9b5-py3-none-win_amd64.whl';

%

mkdir(xgboost_install_dir);

xgboost_install_dir_tmp = [xgboost_install_dir '\' 'tmp'];
mkdir(xgboost_install_dir_tmp);

cd(xgboost_install_dir);
%url = 'https://s3-us-west-2.amazonaws.com/xgboost-nightly-builds/release_1.1.0/xgboost-1.1.0%2B115e4c33608c3b0cee75402f1193e67fdb11ef9a-py3-none-win_amd64.whl';
%filename = 'xgboost.whl';
%outfilename = websave(filename,url);

wheel_fn = 'E:\code\xgboost_matlab\xgboost-1.7.9+cf487d3cdf88780f778905434c3d32965919b603-py3-none-win_amd64.whl';
unzip(wheel_fn, xgboost_install_dir_tmp);

from = [xgboost_install_dir_tmp '\xgboost\lib\xgboost.dll'];
to = [xgboost_install_dir '\' 'xgboost.dll'];
movefile(from, to);

FileList = dir(fullfile(xgboost_install_dir_tmp, '**', 'vcomp140.dll'));

from = [FileList(1).folder '\' FileList(1).name];
to = [xgboost_install_dir '\' FileList(1).name];
movefile(from, to);

rmdir(xgboost_install_dir_tmp, 's');

url = 'https://raw.githubusercontent.com/dmlc/xgboost/master/include/xgboost/c_api.h';
filename = [xgboost_install_dir 'xgboost.h'];
% outfilename = websave(filename,url);



