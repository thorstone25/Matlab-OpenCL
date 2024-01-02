function [N, IDX] = oclDeviceCount(COUNTMODE)
% oclDeviceCount Count OpenCL devices present in system
% 
% N = oclDeviceCount returns the number of OpenCL devices in your system as
% reported by the ICD device loader via MatCL. 
% oclDeviceCount counts all detected
% devices, including any unsupported devices or devices that are not
% available for use in this MATLAB session.
% 
% N = oclDeviceCount(COUNTMODE) returns the number of OpenCL devices counted
% according to the COUNTMODE input. COUNTMODE must be one of:
%    'all'       - (default) counts all OpenCL devices reported by the
%                  driver. 
%    'gpu' - counts only gpu OpenCL devices
%    'cpu' - counts only cpu OpenCL devices
% 
% [N,IDX] = oclDeviceCount(...) also returns a vector of indices for
% the counted devices.
% 
% % Example: Count and return supported devices
% [n, indx] = oclDeviceCount("gpu");
% T = oclDeviceTable();
% disp(T(indx, ["Index", "Name", "DeviceVersion"]));
%
% See also oclDeviceTable oclDevice cl_get_device_info

arguments
    COUNTMODE (1,1) string {mustBeMember(COUNTMODE, ["all","gpu","cpu","accelerator","default","custom"])} = "all"
end

T = cl_get_device_info(cellstr(["CL_DEVICE_TYPE"]));
switch COUNTMODE
    case "all", IDX = 1:numel(T);
    otherwise,  IDX = find(contains(string(T),COUNTMODE));
end
N = numel(IDX);

end