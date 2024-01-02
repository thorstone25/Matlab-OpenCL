classdef oclDevice
    properties(SetAccess=protected)
        Name (1,1) string
        Vendor (1,1) string
        Index (1,1) double
        SupportsDouble (1,1) logical
        SupportsHalf  (1,1) logical
        DeviceVersion (1,1) string
        DriverVersion (1,1) string
        OpenclCVersion (1,1) string
        Extensions (1,:) string
        MaxThreadsPerBlock (1,1) double
        MaxShmemPerBlock (1,1) double
        MaxThreadBlockSize (1,3) double
        TotalMemory (1,1) double
        MultiprocessorCount (1,1) double
        ClockRateKHz (1,1) double
        DeviceSupported (1,1) logical
        DeviceAvailable (1,1) logical
        DeviceSelected (1,1) logical
    end


    methods
        function D = oclDevice(idx)

            %oclDevice - Query or select an OpenCL device
            % D = oclDevice() returns the currently selected OpenCL device.
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
                idx {mustBeNonnegative, mustBeInteger, mustBeScalarOrEmpty} = 0
            end

            % get number of devices
            N = oclDevice.numDevices();

            % get device index - select if requested
            idx = oclDevice.deviceSelection(idx);

            % get the info from the device table
            T = oclDevice.deviceInfo();

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
            T.DeviceSelected        = arrayfun(@(x) isequal(x, idx), T.Index);

            % keep gpuDevice analagous fields only
            S = table2struct(T);

            % select active device
            S = S(idx);

            % re-init device
            D = repmat(D, size(S));

            % set the fields
            for f = string(fieldnames(D))', [D.(f)] = S.(f); end
        end
    end

    methods(Static,Hidden)
        % cached indexing
        function idx = deviceSelection(idx)
            arguments, idx double {mustBeNonnegative, mustBeInteger, mustBeScalarOrEmpty} = 0, end
            
            persistent OCL_CURRENT_DEVICE_INDEX; % index

            if idx > oclDevice.numDevices()
                error( ...
                    "oclDevice:invalidDeviceIndex", ...
                    "Invalid OpenCL device id: "+idx ...
                    +". Select a device id from the range 1:"+oclDevice.numDevices()+"." ...
                    );
            end

            if ~idx, else, OCL_CURRENT_DEVICE_INDEX = idx; end % don't set if '0'
            idx = OCL_CURRENT_DEVICE_INDEX;
        end

        % cached call to oclDeviceTable
        function T = deviceInfo()
            persistent T_;
            if isempty(T_), T_ = oclDeviceTable(); end
            T = T_;
        end

        function N = numDevices()
            T = oclDevice.deviceInfo();
            N = height(T);
        end
    end
end







