% This project is licensed under the terms of the Creative Commons CC BY-NC 4.0 license.

% Select an OpenCL device
dev = oclDevice(1); % select the device
disp(dev); % display it

% Either load test image from .mat file or take an image using a camera(requires webcam support package)
addpath(fullfile('sub','MatCL','examples')); % 'imgData.mat', 'filter.cl'
load('imgData.mat', 'cam_img');
img = rgb2gray(cam_img); %transform to grayscale image
sz = size(cam_img,1:2); %get image size
W = 3; % median filter window size

% add artificial noise to the image
img = imnoise(img,'salt & pepper',0.06);

% Run native matlab medfilt function and track execution time
tic
K = medfilt2(img, [W W], 'zeros');
cpu_time=toc;

%% Configure and Run OpenCL Kernel via oclKernel
kern = oclKernel('filter.cl', 'filter');

% Set OpenCL workgroup dimensions depending on the size of the image(take care of bounds)
[kern.GridOffset, kern.GridSize] = deal([W W 0], [sz - 2*W, 1]);
kern.ThreadBlockSize(:) = 1;

% Set OpenCL kernel defines
kern.macros = ("WIDTH=" + sz(1));

% Precompile filter kernel
% 'macros', 'includes', and compiler options ('opts') must be set already
kern.build();

% Execute OpenCL median filter kernel and track total execution time
% Use implicit memory allocation (default).
tic
[~, img_out] = kern.feval(img, img, 'inplace', false);
ocl_time=toc;

%%

%Generate figure with results and runtimes
cpu_title=sprintf(   'CPU Runtime: %.3f ms',cpu_time*1000);
ocl_title=sprintf('OpenCL Runtime: %.3f ms',ocl_time*1000);

figure('units','normalized','outerposition',[0 0 1 1])
subplot(2,2,[1,2])
imshow(img)
title('Original')

subplot(2,2,3)
imshow(K)
title(cpu_title)

subplot(2,2,4)
imshow(img_out)
title(ocl_title)
% xlabel(cl_times)
