%% Displacement Interpolation (Camera Data)
% Replaces the previous 3-segment curve-fitting approach.
% Input:  displacement measured by camera at 0.5 s intervals
% Output: displacement resampled at 0.1 s intervals via interpolation
%
% Interpolation methods available (set 'method' below):
%   'linear'   - piecewise linear (fastest, no overshoot)
%   'spline'   - cubic spline    (smooth, may overshoot at ends)
%   'pchip'    - shape-preserving cubic (smooth, no overshoot) [DEFAULT]
%   'makima'   - modified Akima  (smooth, robust to outliers)

clear; clc; close all;

%% ── 1. INPUT DATA ────────────────────────────────────────────────────────
% Replace the values below with your actual camera measurements.
% t_raw : time vector in seconds, sampled every 0.5 s
% d_raw : corresponding displacement values (same units as your camera data)

t_raw = 0 : 0.5 : 10;                   % example: 0 to 10 s, step 0.5 s
d_raw = sin(t_raw) + 0.05*randn(size(t_raw));  % ← replace with real data

%% ── 2. INTERPOLATION SETTINGS ───────────────────────────────────────────
method     = 'pchip';   % choose: 'linear' | 'pchip' | 'spline' | 'makima'
t_fine_step = 0.1;       % desired output time step (seconds)

%% ── 3. INTERPOLATE ──────────────────────────────────────────────────────
t_fine = t_raw(1) : t_fine_step : t_raw(end);   % new time axis at 0.1 s
d_fine = interp1(t_raw, d_raw, t_fine, method);  % interpolated displacement

%% ── 4. DISPLAY RESULTS ──────────────────────────────────────────────────
fprintf('Interpolation method : %s\n', method);
fprintf('Original points      : %d  (every %.1f s)\n', numel(t_raw),  t_raw(2)-t_raw(1));
fprintf('Interpolated points  : %d  (every %.1f s)\n', numel(t_fine), t_fine_step);
fprintf('\n%-10s  %-15s\n', 'Time (s)', 'Displacement');
fprintf('%-10s  %-15s\n', '--------', '------------');
for k = 1:numel(t_fine)
    fprintf('%-10.1f  %-15.6f\n', t_fine(k), d_fine(k));
end

%% ── 5. PLOT ─────────────────────────────────────────────────────────────
figure('Name', 'Displacement Interpolation', 'NumberTitle', 'off');

% --- raw camera data ---
plot(t_raw, d_raw, 'ko', 'MarkerSize', 7, 'LineWidth', 1.5, ...
     'DisplayName', 'Camera data (0.5 s)');
hold on;

% --- interpolated curve ---
plot(t_fine, d_fine, 'b-', 'LineWidth', 2, ...
     'DisplayName', sprintf('Interpolated (%s, 0.1 s)', method));

% --- mark interpolated points ---
plot(t_fine, d_fine, 'b.', 'MarkerSize', 6, 'HandleVisibility', 'off');

xlabel('Time (s)');
ylabel('Displacement');
title(sprintf('Camera Displacement — %s interpolation', method));
legend('Location', 'best');
grid on;
hold off;

%% ── 6. SAVE RESULTS TO CSV ──────────────────────────────────────────────
output_file = 'displacement_interpolated.csv';
T = table(t_fine(:), d_fine(:), ...
    'VariableNames', {'Time_s', 'Displacement'});
writetable(T, output_file);
fprintf('\nResults saved to: %s\n', output_file);
