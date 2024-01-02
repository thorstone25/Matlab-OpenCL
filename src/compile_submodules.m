function compile_submodules(force)
arguments
    force (1,1) logical = false
end
og = pwd; % original cwd

%% Compile MatCL
if force || ~exist("cl_run_kernel."+mexext, 'file')
    % switch to folder that MatCL expects
    cd(fullfile(fileparts(mfilename('fullpath')),"..","sub","MatCL"));
    compile_matcl; % compile
end
cd(og); % restore cwd

% Compile Matlab-OpenCL
if force || ~exist("cl_get_device_info."+mexext, 'file')
    compile_cl_get_device_info; % compile
end

function compile_matcl
if     isunix,  compile_linux; 
elseif ismac,   compile_mac;
elseif ispc,    compile_windows;
end

