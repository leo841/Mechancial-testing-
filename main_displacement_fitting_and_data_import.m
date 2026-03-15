%%% This is the code for J-R curve measurement, for J-R curve measurement,
%%% there are following steps: input sample dimension data 
%%% 1. Load-displacement data import-- 2. displacement
%%% correction--3. Crack measurement---4. Area of elastic measurement---5.
%%% Area of plastic measurement
clear all
close all
%%
rootfolder = uigetdir('', 'Select ROOT folder for pictures and results');
%% create excel file for data collection
% Ask user for the fileMG M1 toughness sample 2 data file name (without extension)
answer = inputdlg('Enter the Excel filename (without extension):', 'Filename Input');

if isempty(answer)
    disp('No filename provided. Operation canceled.');
else
     % Ensure the folder exists
    if ~exist(rootfolder, 'dir')
        mkdir(rootfolder);  % Optional: create folder if it doesn't exist
    end

    % Build full file path in rootfolder
    dataexcelfilename = fullfile(rootfolder, [answer{1} '.xlsx']);
end

%% sample dimension input

thickness = input('Enter sample thickness (top-to-bottom) in mm: ');
if isempty(thickness) || ~isnumeric(thickness) || thickness <= 0
    error('Invalid thickness. Must be a positive number.');
end

width = input('Enter sample width (front-to-back) in mm: ');
if isempty(width) || ~isnumeric(width) || width <= 0
    error('Invalid width. Must be a positive number.');
end

spanLength = input('Enter sample span length in mm: ');
if isempty(spanLength) || ~isnumeric(spanLength) || spanLength <= 0
    error('Invalid span length. Must be a positive number.');
end

fprintf('Sample dimensions entered (mm):\n');
fprintf('Thickness (top-to-bottom): %.2f\n', thickness);
fprintf('Width (front-to-back): %.2f\n', width);
fprintf('Span length: %.2f\n', spanLength);
Dimensions = {thickness, width, spanLength};
writematrix('Thickness(topbot)', dataexcelfilename, 'Sheet',1,'Range','A1');
writematrix('Width(frontback)', dataexcelfilename, 'Sheet',1,'Range','B1');
writematrix('spansize', dataexcelfilename, 'Sheet',1,'Range','C1');
writecell(Dimensions, dataexcelfilename, 'Sheet',1,'Range','A2');

%%
% section 1 - load-displacement input
[ headers, units, TesterdataTable, clockTimeValue, trueTestStartTime] = Testerdatatable();
tester_time = TesterdataTable{:,"Time"}-TesterdataTable.Time(1);
tester_displacement = TesterdataTable{:,"Deformation"};
tester_force = TesterdataTable{:,"StandardForce"};
writetable(TesterdataTable, dataexcelfilename, 'Sheet', 2,'Range','a1');

%%

% check whether there is delay between Testing and optical frame 
diffSec = Timedelay(trueTestStartTime);

%write data to excel
TesterdataTable{:,"Time"} = TesterdataTable{:,"Time"} - TesterdataTable{1,"Time"};
writetable(TesterdataTable, dataexcelfilename, 'Sheet', 2,'Range','a1');
%%
% Section 2- displacemenet correction-- function filename: importAndPlot2DDrift.m,
% it will import ImageJ 3D drift output file, you will select the file and read automatically
% the reason use ImageJ is because compared to Normalised cross-correction
% it is more accurate, you can change to different method if you want.

% import data2

driftTable = Import_ImageJ_drift();
largeCameraScale = 996.0833;   % pixels/mm for large camera
smallCameraScale = 203.8383;   % pixels/mm for small camera

% Ask user to choose scale or enter custom
fprintf('Choose scale to use:\n');
fprintf('1: Large camera (996.0833 pixels/mm)\n');
fprintf('2: Small camera (203.8383 pixels/mm)\n');
fprintf('3: Enter custom scale\n');

choice = input('Enter your choice (1, 2, or 3): ');

if choice == 1
    scale = largeCameraScale;
elseif choice == 2
    scale = smallCameraScale;
elseif choice == 3
    scale = input('Enter custom scale (pixels/mm): ');
    if isempty(scale) || ~isnumeric(scale) || scale <= 0
        error('Invalid scale input. Must be a positive number.');
    end
else
    error('Invalid choice. Please enter 1, 2, or 3.');
end

% Apply the scale to the data
optical_displacement = driftTable{:,"Drift_Y"} / scale;
optical_time = driftTable{:,"Frame"}*0.5;
fprintf('Using scale: %.4f pixels/mm\n', scale);
%%
%write to excel file
writematrix('Optical time', dataexcelfilename, 'Sheet', 2, 'Range', 'D1' );
writematrix(optical_time, dataexcelfilename, 'Sheet', 2, 'Range', 'D2' );
writematrix('Optical displacement', dataexcelfilename, 'Sheet', 2, 'Range', 'E1' );
writematrix(optical_displacement, dataexcelfilename, 'Sheet', 2, 'Range', 'E2' );

%%
%%% Displacement correction via direct interpolation
%%% Replaces the previous 3-segment curve-fitting approach.
%%% optical_displacement (0.5 s camera data) is interpolated directly at
%%% tester_time stamps using pchip (shape-preserving, no overshoot).

% Plot optical vs tester displacement for visual check
figure(1);
plot(optical_time, optical_displacement, 'b', 'DisplayName', 'Optical'); grid on;
hold on;
plot(tester_time, tester_displacement, 'r', 'DisplayName', 'Tester');
xlabel('Time (s)'); ylabel('Displacement');
title('Optical vs Tester Displacement');
legend('Location', 'best');
saveas(gcf, fullfile(rootfolder, 'Displacement compare.png'));

% Interpolate optical data at tester time stamps
[~, corrected_displacement] = displacement_interpolation( ...
    optical_time, optical_displacement, tester_time, 'pchip');

% Plot interpolation result
figure(2);
plot(optical_time, optical_displacement, 'ko', 'MarkerSize', 5, ...
    'DisplayName', 'Camera data (0.5 s)');
hold on;
plot(tester_time, corrected_displacement, 'b-', 'LineWidth', 2, ...
    'DisplayName', 'Interpolated (pchip)');
xlabel('Time (s)'); ylabel('Displacement');
title('Displacement Interpolation (pchip)');
legend('Location', 'best');
grid on;
saveas(gcf, fullfile(rootfolder, 'displacement interpolation.png'));

%write to excel file
writematrix('Corrected displacement', dataexcelfilename, 'Sheet', 2, 'Range', 'F1' )
writematrix(corrected_displacement, dataexcelfilename, 'Sheet', 2, 'Range', 'F2' )
matfile = fullfile(rootfolder, [answer{1} '.mat']);
save(matfile,'optical_time','optical_displacement', 'tester_force', 'tester_time','tester_displacement', 'corrected_displacement' );  % Save the MAT file with the updated variab
save(matfile); 
%% Section 3 crack measurement
Miji;


