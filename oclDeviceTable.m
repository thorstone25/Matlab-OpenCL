function T = oclDeviceTable(props)
% OCLDEVICETABLE - Table of properties of detected OpenCL devices
% 
% T = OCLDEVICETABLE returns a table indicating the name, index, and
% several other properties of each OpenCL platform and device detected 
% in your system.
%
% T = OCLDEVICETABLE(PROPS) returns an OpenCL device table with the device
% properties specified by PROPS as table variables. PROPS must be a
% string array or a cell array of character vectors where each entry is
% one of the properties returned by gpuDevice.
% 
% See also cl_get_device_info, oclDeviceCount, oclDevice, gpuDeviceTable

arguments
    props (1,:) string = subsref(getOclFields(),substruct('()',{1:17})) % first 19 fields
end

% field names (abbreviation)
flds = props;
flds = strrep(flds, "CL_DRIVER", "DRIVER");
flds = strrep(flds, "CL_DEVICE_VERSION", "DEVICE_VERSION");
pat = "CL_DEVICE_";
i = startsWith(flds, pat);
flds(i) = extractAfter(flds(i), pat);

% query
out = cl_get_device_info(cellstr(props))';

% get number of devices
N = size(out,1);

% turn snake_case into PascalCase (a.k.a. upper CamelCase)
i1 = substruct('()', {1});
cap = @(s) string(subsasgn(lower(char(s)), i1, upper(subsref(char(s), i1))));
snake2camel = @(c) join(arrayfun(cap, split(c,'_')),"");
flds = arrayfun(snake2camel, flds);

% prepend index
[out, flds] = deal([num2cell(1:N)', out], ["Index",flds]);

% format
T = cell2table(out, 'VariableNames', flds);

% reformat char arrays into strings
tprops = string(T.Properties.VariableNames);
for f = tprops
    if iscellstr(T.(f)) %#ok<ISCLSTR>
        T.(f) = cellfun(@string, T.(f)); 
    end 
end

% parse the extensions for convenience
if any(contains(tprops, "Extensions"))
    T.Extensions = arrayfun(@(s) {unique(split(s," ",2),'stable')}, T.Extensions);
end

return

% archive: using original package
%{
% capture values returned
out = cell(size(props)); % pre-allocate output
if N, [out{:}] = cl_get_devices; 
else, [out{:}] = deal([]); % empty if no devices
end

% insert device index
out  = [out(1) , {(1:N)'}, out( 2:end)];
props = [props(1), "index" , props(2:end)];

% construct table
T = table(out{:}, 'VariableNames', props);
%}

function props = getOclFields()
%% fields requested/returned within the mex function (OpenCL terminology)
props = [
"CL_DEVICE_NAME"
... "CL_DEVICE_PLATFORM"
"CL_DEVICE_VENDOR"
"CL_DEVICE_TYPE"
"CL_DEVICE_OPENCL_C_VERSION"
"CL_DEVICE_VERSION"
"CL_DRIVER_VERSION"
"CL_DEVICE_MAX_WORK_GROUP_SIZE"
"CL_DEVICE_LOCAL_MEM_SIZE"
"CL_DEVICE_MAX_WORK_ITEM_SIZES"
"CL_DEVICE_GLOBAL_MEM_SIZE"
"CL_DEVICE_MAX_COMPUTE_UNITS"
"CL_DEVICE_MAX_CLOCK_FREQUENCY"
"CL_DEVICE_AVAILABLE"
"CL_DEVICE_MAX_MEM_ALLOC_SIZE"
... "CL_DEVICE_MAX_GLOBAL_VARIABLE_SIZE"
"CL_DEVICE_GLOBAL_MEM_CACHE_SIZE"
"CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE"
"CL_DEVICE_EXTENSIONS"
"CL_DEVICE_ADDRESS_BITS"
"CL_DEVICE_BUILT_IN_KERNELS"
"CL_DEVICE_COMPILER_AVAILABLE"
"CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE"
"CL_DEVICE_LINKER_AVAILABLE"
"CL_DEVICE_MAX_CONSTANT_ARGS"
"CL_DEVICE_MAX_NUM_SUB_GROUPS"
"CL_DEVICE_MAX_ON_DEVICE_QUEUES"
"CL_DEVICE_MAX_PARAMETER_SIZE"
"CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR"
"CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT"
"CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT"
"CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG"
"CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT"
"CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE"
"CL_DEVICE_PREFERRED_VECTOR_WIDTH_HALF"
"CL_DEVICE_PRINTF_BUFFER_SIZE"
"CL_DEVICE_PROFILE"
"CL_DEVICE_PROFILING_TIMER_RESOLUTION"
"CL_DEVICE_QUEUE_ON_DEVICE_MAX_SIZE"
"CL_DEVICE_QUEUE_ON_DEVICE_PREFERRED_SIZE"
"CL_DEVICE_VENDOR_ID"
    ];
