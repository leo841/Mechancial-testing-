function [fitParams, yfit, gof] = fitThreeSegmentOptical(t, y, t_breaks, varargin)
% FITTHREESEGMENTOPTICAL Fits three-segment piecewise model to optical data
%
% Inputs:
%   t         - time vector (optical)
%   y         - displacement (optical)
%   t_breaks  - [t1, t2] breakpoints manually selected by user
%   varargin  - optional parameter-value pairs:
%               'ModelType': Single string ('linear', 'exponential', 'power') 
%                           OR cell array {seg1, seg2, seg3} for mixed models
%               'ContinuityType': 'C0' (default, continuous) or 'C1' (smooth)
%               'TargetR2': Target R-squared value (default: 0.9998)
%               'MaxRefinementIter': Maximum refinement iterations (default: 5)
%               'HorizontalSegments': Vector of segment indices to constrain as horizontal
%                                    (e.g., [1] or [1,3] for segments 1 and/or 3)
%
% Examples:
%   % Uniform model for all segments
%   [fitParams, yfit, gof] = fitThreeSegmentOptical(t, y, [t1, t2], 'ModelType', 'linear');
%
%   % Mixed models: linear-power-exponential
%   [fitParams, yfit, gof] = fitThreeSegmentOptical(t, y, [t1, t2], ...
%       'ModelType', {'linear', 'power', 'exponential'});
%
%   % High precision fit with target R² = 0.9999
%   [fitParams, yfit, gof] = fitThreeSegmentOptical(t, y, [t1, t2], ...
%       'ModelType', {'linear', 'linear', 'exponential'}, ...
%       'TargetR2', 0.9999, 'MaxRefinementIter', 10);
%
%   % First segment constrained to be horizontal (slope = 0)
%   [fitParams, yfit, gof] = fitThreeSegmentOptical(t, y, [t1, t2], ...
%       'ModelType', {'linear', 'linear', 'exponential'}, ...
%       'HorizontalSegments', [1]);
%
% Outputs:
%   fitParams - structure with fitted parameters
%   yfit      - fitted displacement values
%   gof       - goodness of fit metrics (R2, RMSE, adjR2, SSE)

    %% Parse inputs
    p = inputParser;
    addRequired(p, 't', @isnumeric);
    addRequired(p, 'y', @isnumeric);
    addRequired(p, 't_breaks', @(x) isnumeric(x) && length(x)==2);
    addParameter(p, 'ModelType', 'linear', @(x) ischar(x) || (iscell(x) && length(x)==3));
    addParameter(p, 'ContinuityType', 'C0', @(x) ismember(x, {'C0', 'C1'}));
    addParameter(p, 'TargetR2', 0.9998, @(x) isnumeric(x) && x > 0 && x < 1);
    addParameter(p, 'MaxRefinementIter', 5, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'HorizontalSegments', [], @(x) isnumeric(x) && all(ismember(x, [1,2,3])));
    parse(p, t, y, t_breaks, varargin{:});
    
    modelType = p.Results.ModelType;
    continuityType = p.Results.ContinuityType;
    targetR2 = p.Results.TargetR2;
    maxRefinementIter = p.Results.MaxRefinementIter;
    horizontalSegments = p.Results.HorizontalSegments;
    
    % Convert single model type to cell array
    if ischar(modelType)
        modelType = {modelType, modelType, modelType};
    end
    
    % Validate model types
    validModels = {'linear', 'exponential', 'power'};
    for i = 1:3
        assert(ismember(modelType{i}, validModels), ...
            'Segment %d: ModelType must be linear, exponential, or power', i);
    end
    
    % Validate horizontal segments - only linear segments can be horizontal
    for i = 1:length(horizontalSegments)
        segIdx = horizontalSegments(i);
        if ~strcmp(modelType{segIdx}, 'linear')
            error('Segment %d is constrained to be horizontal but is not linear. Only linear segments can be horizontal.', segIdx);
        end
    end
    
    %% Validate inputs
    assert(length(t) == length(y), 'Time and displacement vectors must match');
    t0 = t(1);
    t1 = t_breaks(1);
    t2 = t_breaks(2);
    assert(t0 < t1 && t1 < t2 && t2 <= t(end), 'Invalid breakpoint order');
    
    %% Segment indices
    idx1 = t < t1;
    idx2 = (t >= t1) & (t < t2);
    idx3 = t >= t2;
    
    %% Setup mixed model
    [x0, lb, ub, paramMap, modelFun] = setupMixedModel(t, y, t0, t1, t2, ...
        idx1, idx2, idx3, modelType, continuityType, horizontalSegments);
    
    %% Iterative refinement to reach target R²
    bestR2 = -Inf;
    bestParams = x0;
    bestYfit = [];
    bestGof = struct();
    
    for iter = 1:maxRefinementIter
        % Set optimization options with increasing precision
        if iter == 1
            % Initial fit with standard settings
            options = optimoptions('lsqcurvefit', 'Display', 'off', ...
                'MaxIterations', 2000, 'MaxFunctionEvaluations', 10000, ...
                'FunctionTolerance', 1e-10, 'OptimalityTolerance', 1e-10, ...
                'StepTolerance', 1e-10);
        else
            % Refinement with tighter tolerances
            options = optimoptions('lsqcurvefit', 'Display', 'off', ...
                'MaxIterations', 3000, 'MaxFunctionEvaluations', 15000, ...
                'FunctionTolerance', 1e-12, 'OptimalityTolerance', 1e-12, ...
                'StepTolerance', 1e-12, ...
                'Algorithm', 'trust-region-reflective');
        end
        
        % Fit using lsqcurvefit
        [paramVec, resnorm, residual, exitflag, output] = lsqcurvefit(modelFun, x0, t, y, lb, ub, options);
        
        % Get fitted values
        yfit = modelFun(paramVec, t);
        
        % Compute goodness of fit
        SSres = sum(residual.^2);
        SStot = sum((y - mean(y)).^2);
        R2 = 1 - SSres/SStot;
        RMSE = sqrt(mean(residual.^2));
        nParams = length(paramVec);
        n = length(y);
        adjR2 = 1 - (SSres/SStot) * (n-1)/(n-nParams-1);
        
        gof = struct('R2', R2, 'RMSE', RMSE, 'adjR2', adjR2, 'SSE', SSres, ...
                     'iteration', iter, 'exitflag', exitflag);
        
        % Check if this is the best fit so far
        if R2 > bestR2
            bestR2 = R2;
            bestParams = paramVec;
            bestYfit = yfit;
            bestGof = gof;
        end
        
        % Display progress
        fprintf('Iteration %d: R² = %.6f, RMSE = %.4e (exitflag=%d)\n', ...
            iter, R2, RMSE, exitflag);
        
        % Check if target achieved
        if R2 >= targetR2
            fprintf('Target R² = %.4f achieved! Final R² = %.6f\n', targetR2, R2);
            break;
        end
        
        % Prepare for next iteration with perturbed initial guess
        if iter < maxRefinementIter
            % Add small random perturbations to escape local minima
            perturbation = 0.05 * (1 - R2) * randn(size(paramVec)); % Smaller perturbation as R² improves
            x0 = paramVec + perturbation;
            
            % Ensure we stay within bounds
            x0 = max(lb, min(ub, x0));
        end
    end
    
    % Use the best fit found
    paramVec = bestParams;
    yfit = bestYfit;
    gof = bestGof;
    
    if bestR2 < targetR2
        warning('Target R² = %.4f not achieved after %d iterations. Best R² = %.6f', ...
            targetR2, maxRefinementIter, bestR2);
    end
    
    %% Package parameters
    fitParams = packageParameters(paramVec, modelType, paramMap, t0, t1, t2);
    fitParams.targetR2 = targetR2;
    fitParams.achievedR2 = bestR2;
    fitParams.totalIterations = iter;
end

%% Setup Mixed Model
function [x0, lb, ub, paramMap, modelFun] = setupMixedModel(t, y, t0, t1, t2, ...
    idx1, idx2, idx3, modelType, continuityType, horizontalSegments)
    
    % Initialize parameter arrays
    x0 = [];
    lb = [];
    ub = [];
    paramMap = struct();
    paramMap.segments = modelType;
    paramMap.indices = cell(1, 3);
    paramMap.isHorizontal = false(1, 3);
    
    % Mark which segments are horizontal
    for i = 1:length(horizontalSegments)
        paramMap.isHorizontal(horizontalSegments(i)) = true;
    end
    
    currentIdx = 1;
    
    % Segment 1
    [x0_seg1, lb_seg1, ub_seg1] = getSegmentInitialGuess(t, y, idx1, t0, t1, ...
        modelType{1}, paramMap.isHorizontal(1));
    paramMap.indices{1} = currentIdx:(currentIdx + length(x0_seg1) - 1);
    x0 = [x0, x0_seg1];
    lb = [lb, lb_seg1];
    ub = [ub, ub_seg1];
    currentIdx = currentIdx + length(x0_seg1);
    
    % Segment 2
    [x0_seg2, lb_seg2, ub_seg2] = getSegmentInitialGuess(t, y, idx2, t1, t2, ...
        modelType{2}, paramMap.isHorizontal(2));
    paramMap.indices{2} = currentIdx:(currentIdx + length(x0_seg2) - 1);
    x0 = [x0, x0_seg2];
    lb = [lb, lb_seg2];
    ub = [ub, ub_seg2];
    currentIdx = currentIdx + length(x0_seg2);
    
    % Segment 3
    [x0_seg3, lb_seg3, ub_seg3] = getSegmentInitialGuess(t, y, idx3, t2, t(end), ...
        modelType{3}, paramMap.isHorizontal(3));
    paramMap.indices{3} = currentIdx:(currentIdx + length(x0_seg3) - 1);
    x0 = [x0, x0_seg3];
    lb = [lb, lb_seg3];
    ub = [ub, ub_seg3];
    
    % Create model function
    modelFun = @(params, t_eval) evaluateMixedModel(t_eval, params, paramMap, ...
        t0, t1, t2, continuityType);
end

%% Get Initial Guess for Each Segment
function [x0, lb, ub] = getSegmentInitialGuess(t, y, idx, t_start, t_end, modelType, isHorizontal)
    
    if sum(idx) < 2
        % Not enough points, use defaults
        switch modelType
            case 'linear'
                if isHorizontal
                    x0 = 0;
                    lb = 0;
                    ub = 0;
                else
                    x0 = 0.1;
                    lb = -Inf;
                    ub = Inf;
                end
            case 'exponential'
                x0 = [0.1, 0.1];
                lb = [-Inf, -Inf];
                ub = [Inf, Inf];
            case 'power'
                x0 = [0.1, 1.5];
                lb = [-Inf, 0.1];
                ub = [Inf, 5];
        end
        return;
    end
    
    t_seg = t(idx);
    y_seg = y(idx);
    dt = t_seg(end) - t_seg(1);
    dy = y_seg(end) - y_seg(1);
    
    switch modelType
        case 'linear'
            if isHorizontal
                % Constrain slope to be zero
                x0 = 0;
                lb = 0;
                ub = 0;
            else
                % Parameter: slope m
                m_guess = dy / (dt + eps);
                x0 = m_guess;
                lb = -Inf;
                ub = Inf;
            end
            
        case 'exponential'
            % Parameters: [A, k]
            y_range = max(y) - min(y);
            A_guess = y_range / 3;
            k_guess = log(2) / (dt + eps);  % Time constant based on segment length
            x0 = [A_guess, k_guess];
            lb = [-Inf, -10];  % Limit decay/growth rate
            ub = [Inf, 10];
            
        case 'power'
            % Parameters: [A, n]
            y_range = max(y) - min(y);
            A_guess = y_range / 3;
            n_guess = 1.5;
            x0 = [A_guess, n_guess];
            lb = [-Inf, 0.1];
            ub = [Inf, 5];
    end
end

%% Evaluate Mixed Model
function y = evaluateMixedModel(t, params, paramMap, t0, t1, t2, continuityType)
    
    % Extract parameters for each segment
    params1 = params(paramMap.indices{1});
    params2 = params(paramMap.indices{2});
    params3 = params(paramMap.indices{3});
    
    % Evaluate first segment
    idx1 = t < t1;
    y1 = evaluateSegment(t(idx1), params1, paramMap.segments{1}, t0, 0);
    
    % Compute continuity offset for segment 2
    y1_end = evaluateSegment(t1, params1, paramMap.segments{1}, t0, 0);
    
    if strcmp(continuityType, 'C1')
        % Also match derivatives
        dy1_end = evaluateSegmentDerivative(t1, params1, paramMap.segments{1}, t0);
        [y2, offset2] = evaluateSegmentC1(t(t >= t1 & t < t2), params2, ...
            paramMap.segments{2}, t1, y1_end, dy1_end);
    else
        % Only match values (C0)
        y2 = evaluateSegment(t(t >= t1 & t < t2), params2, ...
            paramMap.segments{2}, t1, y1_end);
        offset2 = y1_end;
    end
    
    % Compute continuity offset for segment 3
    y2_end = evaluateSegment(t2, params2, paramMap.segments{2}, t1, offset2);
    
    if strcmp(continuityType, 'C1')
        dy2_end = evaluateSegmentDerivative(t2, params2, paramMap.segments{2}, t1);
        [y3, ~] = evaluateSegmentC1(t(t >= t2), params3, ...
            paramMap.segments{3}, t2, y2_end, dy2_end);
    else
        y3 = evaluateSegment(t(t >= t2), params3, ...
            paramMap.segments{3}, t2, y2_end);
    end
    
    % Combine segments
    y = zeros(size(t));
    y(idx1) = y1;
    y(t >= t1 & t < t2) = y2;
    y(t >= t2) = y3;
end

%% Evaluate Single Segment
function y = evaluateSegment(t, params, modelType, t_shift, offset)
    
    switch modelType
        case 'linear'
            m = params(1);
            y = m * (t - t_shift) + offset;
            
        case 'exponential'
            A = params(1);
            k = params(2);
            y = A * (exp(k * (t - t_shift)) - 1) + offset;
            
        case 'power'
            A = params(1);
            n = params(2);
            y = A * max(t - t_shift, eps).^n + offset;
    end
end

%% Evaluate Segment with C1 Continuity
function [y, offset] = evaluateSegmentC1(t, params, modelType, t_shift, y_match, dy_match)
    
    switch modelType
        case 'linear'
            % For linear, the slope is fixed by previous segment's derivative
            y = dy_match * (t - t_shift) + y_match;
            offset = y_match;
            
        case 'exponential'
            A = params(1);
            k = params(2);
            % Match both value and derivative at junction
            % At t = t_shift: y = y_match, dy/dt = A*k = dy_match
            % This constrains A = dy_match/k
            A_constrained = dy_match / (k + eps);
            y = A_constrained * (exp(k * (t - t_shift)) - 1) + y_match;
            offset = y_match;
            
        case 'power'
            A = params(1);
            n = params(2);
            % At t = t_shift: dy/dt = 0 for power law starting at origin
            % Use small offset to avoid singularity
            epsilon = 1e-6;
            % Match derivative: dy_match = A * n * epsilon^(n-1)
            A_constrained = dy_match / (n * epsilon^(n - 1) + eps);
            y = A_constrained * (max(t - t_shift + epsilon, epsilon)).^n - ...
                A_constrained * epsilon^n + y_match;
            offset = y_match;
    end
end

%% Evaluate Segment Derivative
function dy = evaluateSegmentDerivative(t, params, modelType, t_shift)
    
    switch modelType
        case 'linear'
            m = params(1);
            dy = m;
            
        case 'exponential'
            A = params(1);
            k = params(2);
            dy = A * k * exp(k * (t - t_shift));
            
        case 'power'
            A = params(1);
            n = params(2);
            dy = A * n * max(t - t_shift, eps)^(n - 1);
    end
end

%% Package Parameters
function fitParams = packageParameters(paramVec, modelType, paramMap, t0, t1, t2)
    fitParams.modelTypes = modelType;
    fitParams.breakpoints = [t1, t2];
    fitParams.t0 = t0;
    
    for i = 1:3
        segParams = paramVec(paramMap.indices{i});
        segName = sprintf('segment%d', i);
        
        switch modelType{i}
            case 'linear'
                fitParams.(segName).type = 'linear';
                fitParams.(segName).slope = segParams(1);
                if abs(segParams(1)) < 1e-10
                    fitParams.(segName).isHorizontal = true;
                    fitParams.(segName).equation = 'y = constant';
                else
                    fitParams.(segName).isHorizontal = false;
                    fitParams.(segName).equation = sprintf('y = %.4f*t', segParams(1));
                end
                
            case 'exponential'
                fitParams.(segName).type = 'exponential';
                fitParams.(segName).A = segParams(1);
                fitParams.(segName).k = segParams(2);
                fitParams.(segName).equation = sprintf('y = %.4f*(exp(%.4f*t) - 1)', ...
                    segParams(1), segParams(2));
                
            case 'power'
                fitParams.(segName).type = 'power';
                fitParams.(segName).A = segParams(1);
                fitParams.(segName).n = segParams(2);
                fitParams.(segName).equation = sprintf('y = %.4f*t^%.4f', ...
                    segParams(1), segParams(2));
        end
    end
end

%% Visualization Helper Function (call separately)
function plotFit(t, y, yfit, fitParams, gof)
    % Helper function to visualize the fit
    % Usage: plotFit(t, y, yfit, fitParams, gof);
    
    figure('Position', [100 100 1000 600]);
    
    subplot(2,1,1);
    hold on;
    plot(t, y, 'ko', 'MarkerSize', 4, 'DisplayName', 'Data');
    plot(t, yfit, 'r-', 'LineWidth', 2, 'DisplayName', 'Fit');
    
    % Mark breakpoints
    t1 = fitParams.breakpoints(1);
    t2 = fitParams.breakpoints(2);
    xline(t1, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Breakpoint 1');
    xline(t2, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Breakpoint 2');
    
    xlabel('Time');
    ylabel('Displacement');
    title(sprintf('Three-Segment Fit: %s | %s | %s (R^2=%.4f)', ...
        fitParams.modelTypes{1}, fitParams.modelTypes{2}, fitParams.modelTypes{3}, gof.R2));
    legend('Location', 'best');
    grid on;
    
    subplot(2,1,2);
    residuals = y - yfit;
    plot(t, residuals, 'ko-', 'MarkerSize', 4);
    xline(t1, 'b--', 'LineWidth', 1.5);
    xline(t2, 'g--', 'LineWidth', 1.5);
    yline(0, 'r-', 'LineWidth', 1);
    xlabel('Time');
    ylabel('Residuals');
    title(sprintf('Residuals (RMSE=%.4e)', gof.RMSE));
    grid on;
end
