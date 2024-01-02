function D = oclDevice_(idx)
%oclDevice - Query or select an OpenCL device
% D = oclDevice() returns the currently selected OpenCL device as a struct.
% If no device is selected, D is empty.
%
% D = oclDevice(IDX) selects the OpenCL device by index IDX. IDX must be 
% between 1 and OCLDEVICECOUNT.
%
% D = oclDevice([]) deselects the OpenCL device.
%
% Note: oclDevice is meant to roughly emulate gpuDevice, with minimal API
% differences. However, since there is no native `oclArray` data type
% (analagous to `gpuArray`), calling oclDevice() does not produce an error 
% if no OpenCL device is available to facilitate device based dispatching.
%
% Note: some OpenCL compatiable devices do not support double-precision.
% 
% See also oclDeviceTable, gpuArray, parallel.gpu.GPUDevice
arguments
    idx {mustBePositive, mustBeInteger, mustBeScalarOrEmpty} = []
end

persistent OCL_CURRENT_DEVICE_INDEX;

% get number of devices
N = oclDeviceCount();

% make selection
if isempty(idx)  % OCL_CURRENT_DEVICE_INDEX  = -1;
elseif idx <= N, OCL_CURRENT_DEVICE_INDEX = idx;
else, error("Invalid OpenCL device id: "+idx+". Select a device id from the range 0:"+N+".");
end

% get device index
if isempty(OCL_CURRENT_DEVICE_INDEX) % uninitialized
    i = []; % don't select a device if uninitialized
else
    i = OCL_CURRENT_DEVICE_INDEX; % last selected device
end

% get the info from the device table
T = oclDeviceTable();

% make this output roughly analgous to gpuDevice
% append other inferred properties to match gpuDevice
T.Index                 = (1:N)';
T.SupportsDouble        = cellfun(@(c) ismember("cl_khr_fp64", c), T.Extensions);
T.SupportsHalf          = cellfun(@(c) ismember("cl_khr_fp16", c), T.Extensions);
T.MaxThreadsPerBlock    = T.MaxWorkGroupSize;
T.MaxShmemPerBlock      = T.LocalMemSize;
T.MaxThreadBlockSize    = T.MaxWorkItemSizes;
T.TotalMemory           = T.GlobalMemSize;
T.MultiprocessorCount   = T.MaxComputeUnits;
T.ClockRateKHz          = T.MaxClockFrequency*1e3;
T.DeviceSupported       = true(N,1); % if we can see it, it's "supported"
T.DeviceAvailable       = T.Available;
T.DeviceSelected        = arrayfun(@(x) isequal(x, i), T.Index);

% keep gpuDevice analagous fields only
pflds = strip([
"Name               "
... "Platform           "
"Vendor             "
"Index              "   
"SupportsDouble     "   
"SupportsHalf       "   
"DeviceVersion      "
"DriverVersion      "
"OpenclCVersion     "
"MaxThreadsPerBlock "   
"MaxShmemPerBlock   "   
"MaxThreadBlockSize "   
"TotalMemory        "   
"MultiprocessorCount"   
"ClockRateKHz       "   
"DeviceSupported    "   
"DeviceAvailable    "   
"DeviceSelected     "
"Extensions         "
]);

% move priority fields to the front of the list
D = removevars(T, setdiff(string(T.Properties.VariableNames),pflds));
D = movevars(D, pflds, "Before", 1); % order
D = table2struct(D);

% select active device
D = D(i);








