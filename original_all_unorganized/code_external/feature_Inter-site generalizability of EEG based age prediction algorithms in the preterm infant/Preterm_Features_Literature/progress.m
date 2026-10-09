fs = 500;                 % 采样率
prs = [1 2; 1 3;1 4;1 5;1 6;1 7;1 8;1 9;1 10;1 11;1 12;1 13;2 3;2 4;];         % 成对比较通道
art = zeros(1, fs*60);    % 无伪迹

fv = new_measures_bursts(dat, prs, fs, art);
