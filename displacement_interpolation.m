function [t_out, d_out] = displacement_interpolation(t_raw, d_raw, t_query, method)
% DISPLACEMENT_INTERPOLATION  Resample camera displacement data via interpolation.
%
%   [t_out, d_out] = displacement_interpolation(t_raw, d_raw, t_query)
%   [t_out, d_out] = displacement_interpolation(t_raw, d_raw, t_query, method)
%
%   Inputs:
%     t_raw   - time vector of camera measurements (s), e.g. every 0.5 s
%     d_raw   - displacement vector at those times (same length as t_raw)
%     t_query - EITHER a scalar step size (s) to build a regular grid,
%               OR a vector of explicit query times (e.g. tester_time)
%     method  - interpolation method string  [default: 'pchip']
%                 'pchip'   shape-preserving cubic, no overshoot (recommended)
%                 'spline'  cubic spline, smoothest but may overshoot
%                 'linear'  piecewise linear, no assumptions
%                 'makima'  modified Akima, robust to outliers
%
%   Outputs:
%     t_out - query time vector
%     d_out - interpolated displacement at each t_out point
%
%   Examples (from main_function):
%     % Regular 0.1 s grid
%     [t_out, d_out] = displacement_interpolation(optical_time, optical_displacement, 0.1);
%
%     % At exact tester time stamps (replaces fitThreeSegmentOptical)
%     [~, corrected_displacement] = displacement_interpolation( ...
%         optical_time, optical_displacement, tester_time);

    %% defaults
    if nargin < 3 || isempty(t_query), t_query = 0.1; end
    if nargin < 4 || isempty(method),  method  = 'pchip'; end

    %% build output time axis
    if isscalar(t_query)
        % treat as step size → regular grid
        t_out = t_raw(1) : t_query : t_raw(end);
    else
        % treat as explicit query times
        t_out = t_query(:)';
    end

    %% interpolate (extrapolate nearest outside the range)
    d_out = interp1(t_raw, d_raw, t_out, method, 'extrap');

    %% console summary
    fprintf('Interpolation method : %s\n', method);
    fprintf('Original points      : %d  (step ~%.2f s)\n', numel(t_raw), mean(diff(t_raw)));
    fprintf('Output points        : %d\n', numel(t_out));

    %% plot (only when using a regular grid, not when querying at tester times)
    if isscalar(t_query)
        figure('Name', 'Displacement Interpolation', 'NumberTitle', 'off');
        plot(t_raw,  d_raw,  'ko', 'MarkerSize', 7, 'LineWidth', 1.5, ...
             'DisplayName', 'Camera data');
        hold on;
        plot(t_out, d_out, 'b-', 'LineWidth', 2, ...
             'DisplayName', sprintf('Interpolated (%s)', method));
        plot(t_out, d_out, 'b.', 'MarkerSize', 6, 'HandleVisibility', 'off');
        xlabel('Time (s)');  ylabel('Displacement');
        title(sprintf('Camera Displacement — %s interpolation', method));
        legend('Location', 'best');
        grid on;  hold off;

        %% save CSV (only for regular-grid output)
        output_file = 'displacement_interpolated.csv';
        writetable(table(t_out(:), d_out(:), 'VariableNames', {'Time_s','Displacement'}), ...
                   output_file);
        fprintf('Results saved to    : %s\n', output_file);
    end
end
