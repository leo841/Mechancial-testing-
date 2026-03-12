function [t_fine, d_fine] = displacement_interpolation(t_raw, d_raw, t_fine_step, method)
% DISPLACEMENT_INTERPOLATION  Resample camera displacement data via interpolation.
%
%   [t_fine, d_fine] = displacement_interpolation(t_raw, d_raw)
%   [t_fine, d_fine] = displacement_interpolation(t_raw, d_raw, t_fine_step)
%   [t_fine, d_fine] = displacement_interpolation(t_raw, d_raw, t_fine_step, method)
%
%   Inputs:
%     t_raw       - time vector of camera measurements (s), e.g. every 0.5 s
%     d_raw       - displacement vector at those times (same length as t_raw)
%     t_fine_step - desired output time step (s)          [default: 0.1]
%     method      - interpolation method string           [default: 'pchip']
%                   'pchip'   shape-preserving cubic, no overshoot (recommended)
%                   'spline'  cubic spline, smoothest but may overshoot
%                   'linear'  piecewise linear, no assumptions
%                   'makima'  modified Akima, robust to outliers
%
%   Outputs:
%     t_fine - resampled time vector at t_fine_step intervals
%     d_fine - interpolated displacement at each t_fine point
%
%   Example (from main_function):
%     [t_out, d_out] = displacement_interpolation(t_camera, d_camera);
%     [t_out, d_out] = displacement_interpolation(t_camera, d_camera, 0.1, 'spline');

    %% defaults
    if nargin < 3 || isempty(t_fine_step), t_fine_step = 0.1;    end
    if nargin < 4 || isempty(method),      method      = 'pchip'; end

    %% interpolate
    t_fine = t_raw(1) : t_fine_step : t_raw(end);
    d_fine = interp1(t_raw, d_raw, t_fine, method);

    %% console summary
    fprintf('Interpolation method : %s\n', method);
    fprintf('Original points      : %d  (step %.2f s)\n', numel(t_raw),  mean(diff(t_raw)));
    fprintf('Interpolated points  : %d  (step %.2f s)\n', numel(t_fine), t_fine_step);

    %% plot
    figure('Name', 'Displacement Interpolation', 'NumberTitle', 'off');
    plot(t_raw,  d_raw,  'ko', 'MarkerSize', 7, 'LineWidth', 1.5, ...
         'DisplayName', 'Camera data');
    hold on;
    plot(t_fine, d_fine, 'b-', 'LineWidth', 2, ...
         'DisplayName', sprintf('Interpolated (%s)', method));
    plot(t_fine, d_fine, 'b.', 'MarkerSize', 6, 'HandleVisibility', 'off');
    xlabel('Time (s)');  ylabel('Displacement');
    title(sprintf('Camera Displacement — %s interpolation', method));
    legend('Location', 'best');
    grid on;  hold off;

    %% save CSV
    output_file = 'displacement_interpolated.csv';
    writetable(table(t_fine(:), d_fine(:), 'VariableNames', {'Time_s','Displacement'}), ...
               output_file);
    fprintf('Results saved to    : %s\n', output_file);
end
