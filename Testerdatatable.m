function [ headers, units, TesterdataTable, clockTimeValue, trueTestStartTime] = Testerdatatable()
    % importCustomExcel imports data from an Excel file with custom layout:
    % - Sheet 3: row 1 = sample name, row 2 = headers, row 3 = units, row 4+ = data
    % - Sheet 2: clock time stored in cell C3 (HH:mm:ss)
    % 
    % Outputs:
    %   sampleName         - cell array of sample names (row 1 of sheet 3)
    %   headers            - cell array of headers (row 2 of sheet 3)
    %   units              - cell array of units (row 3 of sheet 3)
    %   dataTable          - table of data from sheet 3 (rows 4 onward)
    %   clockTimeValue     - raw value from sheet 2 cell C3 (usually string or datetime)
    %   trueTestStartTime  - duration object representing clock time + first time (seconds)
    
    % Select the Excel file
    [filename, pathname] = uigetfile('*.xls*', 'Select the Excel file');
    if isequal(filename, 0)
        error('File selection canceled.');
    end
    fullFile = fullfile(pathname, filename);
    
    % Read entire sheet 3 as raw cells
    rawData = readcell(fullFile, 'Sheet', 3);
    
    % Extract headers from row 2
    headers = rawData(2, :);
    
    % Extract units from row 3
    units = rawData(3, :);
    
    % Extract actual data from row 4 onward
    dataCells = rawData(4:end, :);
    
    % Clean headers to valid MATLAB variable names
    validHeaders = matlab.lang.makeValidName(headers);
    
    % Convert data cells to table
    TesterdataTable = cell2table(dataCells, 'VariableNames', validHeaders);
    
    % Read clock time from sheet 2 cell C3
    clockTimeCell = readcell(fullFile, 'Sheet', 2, 'Range', 'C3');
    clockTimeValue = clockTimeCell{1};
    
    % Convert clockTimeValue to duration if needed
    if ischar(clockTimeValue) || isstring(clockTimeValue)
        clockTimeDuration = duration(clockTimeValue, 'InputFormat', 'hh:mm:ss');
    elseif isdatetime(clockTimeValue)
        % Convert datetime to duration since start of day
        clockTimeDuration = clockTimeValue - dateshift(clockTimeValue, 'start', 'day');
    elseif isa(clockTimeValue, 'duration')
        clockTimeDuration = clockTimeValue;
    else
        error('Unexpected clock time format.');
    end
    
    % Get first time value from dataTable (assumes variable named 'Time')
    if any(strcmp(TesterdataTable.Properties.VariableNames, 'Time'))
        firstTimeSeconds = TesterdataTable.Time(1);
    else
        error('No variable named "Time" found in dataTable.');
    end
    
    % Calculate true test start time (clock time + first time in seconds)
    trueTestStartTime = clockTimeDuration + seconds(firstTimeSeconds);
    
    % Display summary
    
    fprintf('First 5 rows of data (sheet 3, from row 4 onward):\n');
    disp(TesterdataTable(1:min(5,height(TesterdataTable)), :));
    
    fprintf('Clock time value (sheet 2, cell C3):\n');
    disp(clockTimeValue);
    
    fprintf('True test start time (clock time + first time in seconds):\n');
    disp(char(trueTestStartTime));
end
