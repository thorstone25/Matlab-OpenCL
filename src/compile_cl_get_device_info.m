function compile_cl_get_device_info
% mex -R2018a -g COMPFLAGS='$COMPFLAGS -std=c++11 -O2' '-LC /usr/lib/x86_64-linux-gnu' -lOpenCL cl_get_device_info.cpp -I../sub/MatCL/src -outdir src/
fpath = fileparts(mfilename("fullpath")); % this file's path
opts = ["-R2018a" "-g" "COMPFLAGS='$COMPFLAGS -std=c++11 -O2'" "-LC /usr/lib/x86_64-linux-gnu" "-lOpenCL" fullfile(fpath,"cl_get_device_info.cpp") "-I"+fullfile(fpath,"..","sub","MatCL","src") "-outdir" fullfile(fpath,"..")];
opts = cellstr(opts);
mex(opts{:});
