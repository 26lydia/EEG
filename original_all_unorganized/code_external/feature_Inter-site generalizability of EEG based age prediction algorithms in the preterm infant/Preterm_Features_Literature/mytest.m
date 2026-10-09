function visualize_signal_length()
    % 生成示例EEG信号
    fs = 100;  % 采样频率100Hz
    t = 0:1/fs:2;  % 2秒信号
    N = length(t);
    
    % 创建混合信号：正弦波 + 突发活动 + 噪声
    base_signal = 2*sin(2*pi*5*t);  % 5Hz基础节律
    burst = zeros(size(t));
    burst(80:120) = 3*sin(2*pi*15*(0:40));  % 突发活动
    noise = 0.3*randn(size(t));  % 噪声
    
    signal = base_signal + burst + noise;
    
    % 计算信号长度（绝对差分和）
    signal_diff = diff(signal);  % 一阶差分
    abs_diff = abs(signal_diff);  % 绝对差分
    signal_length = sum(abs_diff);  % 信号长度
    
    % 可视化
    figure('Position', [100, 100, 1200, 800]);
    
    % 1. 原始信号
    subplot(4,1,1);
    plot(t, signal, 'b-', 'LineWidth', 2);
    title('原始EEG信号');
    xlabel('时间 (s)'); ylabel('振幅');
    grid on;
    ylim([-6, 6]);
    
    % 标记突发区域
    hold on;
    burst_start = t(80); burst_end = t(120);
    fill([burst_start, burst_end, burst_end, burst_start], ...
         [-6, -6, 6, 6], [1, 0.9, 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
    text(mean([burst_start, burst_end]), 5, '突发活动', ...
         'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % 2. 一阶差分
    subplot(4,1,2);
    plot(t(1:end-1), signal_diff, 'g-', 'LineWidth', 2);
    title('一阶差分 (信号变化率)');
    xlabel('时间 (s)'); ylabel('差分值');
    grid on;
    ylim([-2, 2]);
    
    % 标记差分峰值区域
    hold on;
    fill([burst_start, burst_end, burst_end, burst_start], ...
         [-2, -2, 2, 2], [0.9, 1, 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
    
    % 3. 绝对差分
    subplot(4,1,3);
    stem(t(1:end-1), abs_diff, 'r', 'LineWidth', 1, 'MarkerSize', 3);
    title('绝对差分值 |x[i+1] - x[i]|');
    xlabel('时间 (s)'); ylabel('绝对差分');
    grid on;
    ylim([0, 2]);
    
    % 标记绝对差分区域
    hold on;
    fill([burst_start, burst_end, burst_end, burst_start], ...
         [0, 0, 2, 2], [1, 0.9, 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
    
    % 4. 累积信号长度
    subplot(4,1,4);
    cumulative_length = cumsum(abs_diff);
    plot(t(1:end-1), cumulative_length, 'm-', 'LineWidth', 3);
    title(sprintf('累积信号长度 (总长度 = %.1f)', signal_length));
    xlabel('时间 (s)'); ylabel('累积长度');
    grid on;
    
    % 标记最终值
    hold on;
    plot(t(end-1), signal_length, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    text(t(end-1), signal_length*0.8, sprintf('总和 = %.1f', signal_length), ...
         'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    
    % 显示计算详情
    fprintf('信号长度计算详情:\n');
    fprintf('信号长度 = sum(abs(diff(signal)))\n');
    fprintf('样本点数: %d\n', N);
    fprintf('差分点数: %d\n', length(signal_diff));
    fprintf('绝对差分总和: %.2f\n', signal_length);
    fprintf('平均绝对差分: %.4f\n', mean(abs_diff));
end