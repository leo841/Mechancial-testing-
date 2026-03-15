function driftData = Import_ImageJ_drift()
    % Prompt user to select the file
    [fileName, filePath] = uigetfile('*', 'Select Correct_3D_Drift file');
    if isequal(fileName, 0)
        error('File selection cancelled.');
    end

    % Read the selected file
    fullFilePath = fullfile(filePath, fileName);
    fid = fopen(fullFilePath, 'r');
    if fid == -1
        error('Failed to open the file.');
    end

    % Initialize arrays for drift values
    driftX = [];
    driftY = [];

    % Read file line-by-line
    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'frame') && contains(line, 'correcting drift')
            tokens = regexp(line, 'correcting drift\s+(-?[\d.]+),\s*(-?[\d.]+),\s*0\.0', 'tokens');
            if ~isempty(tokens)
                vals = str2double(tokens{1});
                driftX(end+1, 1) = vals(1); %#ok<AGROW>
                driftY(end+1, 1) = vals(2); %#ok<AGROW>
            end
        end
    end
    fclose(fid);

    % Combine into a table
    frameNum = (1:length(driftX))';
    driftTable = table(frameNum, driftX, driftY, ...
        'VariableNames', {'Frame', 'Drift_X', 'Drift_Y'});

    % Display first 5 rows
    disp('First 5 rows of drift correction:');
    disp(driftTable(1:min(5, height(driftTable)), :));

    % Plot X and Y drift over time
    figure('Name','X and Y Drift Over Time','NumberTitle','off');
    plot(driftTable.Frame, driftTable.Drift_X, 'r-', 'LineWidth', 1.5); hold on;
    plot(driftTable.Frame, driftTable.Drift_Y, 'b-', 'LineWidth', 1.5);
    legend('Drift X', 'Drift Y');
    xlabel('Frame Number');
    ylabel('Drift (\mum)');
    title('2D Drift Correction Over Time');
    grid on;

    % Return drift data table if needed
    driftData = driftTable;
end
