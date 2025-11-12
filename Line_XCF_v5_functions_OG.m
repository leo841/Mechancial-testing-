% Script for analysis of SEM video for the measurement of fracture energy from beam displacement and crack length
% - Read video
% - Use of cross correlation to stabilise movement of the DCB with respect
% to window
% - Edge tracking to measure lateral displacement of the beam
% - Function to help measurement of crack length
% - Measurement of fracture energy using values obtained in the previous steps 

clear all; close all;

root_folder = 'C:\Users\Oriol\PDRA\Matlab\DCB_Fracture_Energy';
addpath(fullfile(root_folder, 'Sub_Scripts'));
VideoFileName = 'Interphase_21_DCB06'; %Input video file name 
output_folder = fullfile(root_folder, 'Results', VideoFileName);

%% AVI Reader
Frame_Num=1; %preview frame number

% disp('Would you like to reload existing data?');
%         iPut.query = input('(Y/[N]) : ','s');
%         
%         if strcmpi(iPut.query,'y')
            redo_Avi=1; %set redo to 0 to load existing data
            
[nFrames, Frame_Start,FrameList, VideoFile1, vidTime,vidFRate] = AviRead_Cust_OG (VideoFileName, output_folder, redo_Avi); % reads <VideoFileName>.avi from microscope and saves data in <VideoFileName>_VideoData.mat

fprintf("Video frame rate", vidFRate)

%% Registration Boxes and stack of cropped images
VideoRegBoxSize=25;  %half edge of box for image registration
TestBoxFactor=3; %multiplication factor for test box size -> TestBoxSize=VideoRegBoxSize*TestBoxFactor; 
redo_Crop=0; %set redo to 0 to load existing data

if redo_Avi~=0
     redo_Crop=1;
 end
    
[yrange, xrange, img_box1, img_box2, img_TestBox1, img_TestBox2] = Crop_RegistrationBox_OG (redo_Crop, output_folder, VideoFileName, nFrames, FrameList, Frame_Start,VideoRegBoxSize, VideoFile1,TestBoxFactor);

% AviWrite_Cust( 'test_preXC.avi',6,image_stack ); %writes an image file, with 'fname',frame rate,image_data as (y,x,1,nframes)

%% cross correlate (pixelwise) to find the registration required

[image_stack2,offset, PeakPos] = CrossCorrelation_1box_OG(redo_Crop, yrange, xrange, img_box1, img_TestBox1, VideoFile1, FrameList, nFrames, VideoFileName, output_folder);


%% write the image video%% Edge tracking by cross correlation 

redo_Edge=0; %set redo to 0 to load existing data

if redo_Crop~=0
     redo_Edge=1;
 end

[row_shift_l, row_shift_r, row_shift] = Edge_tracking_XCF_lr_OG(redo_Edge, FrameList, nFrames, VideoFileName, image_stack2, output_folder);

%% Measure pixel to micron ratio
PixelSize_OG

%% Tip Tracking by cross correlation
% 
% VideoRegBoxSize=15;  %half edge of box for image registration
% [offset_tip, PeakPos_tip] = Tip_tracking (VideoRegBoxSize, yrange, xrange,FrameList, nFrames, VideoFileName, image_stack2)

%% Crack Measurement
redo_Crack=0; %set redo to 0 to load existing data

if redo_Crop~=0
     redo_Crack=1;
 end

%Run script for crack measurement
[crack_length_coord, crack_length_fit, crack_length_fit_frame, x_time_vector_crack, FrameList_Crack, frame_start, frame_end, step] = Crack_measurement_OG(redo_Crack, FrameList, vidFRate , VideoFileName, output_folder, image_stack2);


%% Measure cantilevers width
%measure left cantilever width
[Left_cantitlever_width, Left_cantitlever_width_ave]= Cantilever_size_OG (image_stack2, FrameList_Crack);
%measure right cantilever width
[Right_cantitlever_width, Right_cantitlever_width_ave]= Cantilever_size_OG (image_stack2, FrameList_Crack);

% save measurements;
DCB_dimension=[VideoFileName '_DCB_dimensions.mat'];
save ([output_folder '/' DCB_dimension],'Left_cantitlever_width','Left_cantitlever_width_ave','Right_cantitlever_width','Right_cantitlever_width_ave', '-append');


%% Fracture energy measurement

% row_shift=row_shift_r;
NameMod_prompt = 'Input append for file name (useful if comparing different raw vs fit data) : '; 
NameMod = input(NameMod_prompt, 's');
% NameMod = '_c_raw_d_fit_480GPa_CrackV1';
c_raw=1; %set to 1 to use raw data instead of fit for crack length
d_raw=0; %set to 1 to use raw data instead of fit for lateral displacement of beam

[G_ave, displacement,displacement_l,displacement_r, cracklength]= FractureEnergy_ave_OG (VideoFileName, output_folder, NameMod, crack_length_coord, crack_length_fit, x_time_vector_crack, FrameList,FrameList_Crack, row_shift, row_shift_l, row_shift_r, frame_start, frame_end, step, d_raw, c_raw, pixel_to_micron, Left_cantitlever_width_ave, Right_cantitlever_width_ave);

clearvars -except VideoFileName NameMod

%% Crack and edge position/fract energy plot
% %generates frames with crack tip and edge position superimposed to image and plot of fracture energy
% 
% VideoName=[VideoFileName NameMod];
% Kicmat = matfile ([VideoName '_Kic.mat']);
% Edgemat = matfile([VideoFileName '_EdgeTrackingFile.mat']);
% Crackmat= matfile([VideoFileName '_Crack_measurement.mat']);
% 
% namemod_prompt = 'Input append for file name (useful if comparing different tracking strategies) : '; 
% % namemod = input(namemod_prompt);
% namemod='test2'; % name modifier for files. Useful if comparing different tracking strategies
% 
% crack_pos_fract_energy_plot_OG
% 
% WriteCustFile=[FolderName '/' VideoFileName '_2fps_1x_XCF.avi'];
% AviWrite_Cust_OG(WriteCustFile,2,image_stack2); %writes an image file, with 'fname',frame rate,image_data as (y,x,1,nframes)
%e left cantilever width
[Left_cantitlever_width, Left_cantitlever_width_ave]= Cantilever_size_OG (image_stack2, FrameList_Crack);



