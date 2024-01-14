classdef oclKernel < matlab.mixin.Copyable
    properties(SetAccess=protected)
        funcname (1,1) string % OpenCL C kernel function
    end
    properties(SetAccess=protected, Dependent)
        built (1,1) logical % whether the kernel has been built for these settings
    end
    properties
        ThreadBlockSize (1,3) double {mustBeInteger, mustBeNonnegative} = 1; % local range
        GridSize        (1,3) double {mustBePositive} = 1; % local range multiplier size (set/get 'GlobalSize')
    end
    properties(Dependent)
        GlobalSize      (1,3) double {mustBeInteger, mustBePositive   }; % global range size
    end
    properties
        GlobalOffset    (1,3) double {mustBeInteger, mustBeNonnegative} = 0; % global range offset
    end
    properties(Dependent, SetAccess=protected)
        MaxThreadsPerBlock (1,:) double % maximum number of concurrent work items
        NumRHSArguments (1,1) double % number of kernel inputs
        MaxNumLHSArguments (1,1) double % maximum number of kernel outputs
        ArgumentTypes (1,:) cellstr % ArgumentTypes - kernel argument 
    end
    properties
        Device oclDevice {mustBeScalarOrEmpty} = oclDevice() % oclDevice for build
    end
    properties
        macros (1,:) string = string.empty % macros - will be prepended with '-D' when building
        include (1,:) string = string.empty % includes - will be prepended with '-I' when building
        opts (1,:) string = "-cl-" + ["mad-enable", "fp32-correctly-rounded-divide-sqrt"] % options passed to the OpenCL C compiler
    end
    properties(SetAccess=protected)
        filename string % kernel filename
    end
    properties(Hidden,SetAccess=protected)
        ioro (1,:) logical % inputs / outputs - read-only
        signature (1,1) string % C declaration signature
        build_settings (1,1) string % cached compiler options string
        built_dev_ind (1,1) double % device index on (last) build
        built_stgs (1,:) string % device settings on (last) build
        user_def_types (1,:) string {mustBeMember(user_def_types, ["uint8","uint16","uint32","uint64","int8","int16","int32","int64","single","double"])} = string.empty
    end

    methods
        function kern = oclKernel(SRC, FUNC)
            % oclKernel OpenCL Kernel object
            % 
            % kern = oclKernel(CL) and
            % kern = oclKernel(CL, FUNC) return a kernel object
            % that you can use to call an OpenCL kernel on the associated
            % OpenCL device. CL is either the name of the file that
            % contains the CL code, or the contents of a CL file as a
            % character vector. If specified, FUNC must be a character
            % vector that unambiguously defines the appropriate kernel
            % entry name in the CL file. If FUNC is omitted, the CL file
            % must contain only a single entry point.
            %     
            % Example:
            % If simpleEx.cl contains the following:
            %   /*
            %   * Add a constant to a vector.
            %   */
            %   kernel void addToVector(global float * pi, float c, int vecLen)  {
            %      int idx = get_global_id(0);
            %      if ( idx < vecLen ) {
            %          pi[idx] += c;
            %      }
            %   }
            %
            % into PTX, both of the following return a kernel object 
            % that you can use to call the addToVector OpenCL kernel.
            %
            % kern = oclKernel('simpleEx.cl');
            % kern = oclKernel('simpleEx.cl', 'addToVector');
            %
            % See also parallel.gpu.CUDAKernel

            arguments
                SRC string % source code
                FUNC string {mustBeScalarOrEmpty} = string.empty % function name
            end

            % if this is a file we can find
            if isscalar(SRC) && exist(SRC, 'file')
                filename = which(SRC); % file we can find
            else % write to temp file
                filename = string(tempname) + ".cl";
                writelines(SRC, filename);
            end % get full path

            % read the code
            lns = readlines(filename);

            % parse code
            cod = lns;
            i = contains(lns,"//");
            cod(i) = arrayfun(@(l) extractBefore(l, "//"), cod(i)); % remove C line comments
            cod(startsWith(cod, "#")) = []; % delete lines starting with '#'
            cod = join(cod,'\n');
            cod = eraseBetween(cod,"/*","*/",'Boundaries','inclusive'); % remove C block comments
            cod = string(split(cod, '\n'));
            % cod = join(cod); % combine with spaces

            % CL kernel pattern
            if isempty(FUNC), fnm = alphanumericsPattern; else, fnm = FUNC; end
            pat = "kernel void" + whitespacePattern + fnm + "(" ...
            + (asManyOfPattern(alphanumericsPattern|whitespacePattern|","|"*"|"_"|"["|"]")) ...
            + lookAheadBoundary(")");

            % soft validate that ~a~ kernel exists and is probably valid
            if ~contains(join(cod), pat)
                error("oclKernel:invalidKernel",join(["Cannot find any kernels", "matching '"+FUNC+"'", "in file "+filename+"."]));
            end

            % get the matching kernel function signatures
            hfcns = extract(join(cod), pat); % signature line
            nfcns = extractBefore(extract(hfcns, alphanumericsPattern + "("), "("); % function names

            % parse function name
            if isempty(FUNC)
                if ~isscalar(nfcns), error("oclKernel:ambiguousKernel", "The kernel must be specified - the detected kernels are {" + join(nfcns, ", ") + "}.");
                end
            else
                if (FUNC == nfcns) % empty -> fail
                else, error("oclKernel:kernelNotFound","The requested kernel ("+FUNC+") was not found -  the detected kernels are {" + join(nfcns, ", ") + "}.");
                end
            end

            % parse number of inputs and read/write map
            % TODO: handle attributes with arguments e.g. '__attr__((val))'
            inps = split(extractAfter(hfcns,"("), ",")';
            ro = contains(inps, "const"); % read-only

            % include the (modified) path
            inc = string(split(path(), pathsep));
            inc = inc(~startsWith(inc, matlabroot));

            % create the oclKernel
            kern.filename = filename;
            kern.funcname = nfcns;
            kern.Device   = oclDevice();

            % set kernel info
            kern.ioro = ro;
            kern.signature = hfcns;
            kern.include = inc; % default 
        end

        function kern = build(kern, stgs)
            arguments
                kern oclKernel
                stgs (1,:) string = string.empty % further settings
            end

            % for each kernel ...
            for i = 1:numel(kern)
                % get kernel
                k = kern(i);

                % get compilation settings (with build first)
                s = [k.build_settings, stgs];

                % compile only
                [~, okn] = cl_run_kernel(double(k.Device.Index), char(k.filename), char(join(s)));

                % ensure that the kernel was included
                if ~(ismember(k.funcname, okn))
                    error( ...
                        "oclKernel:kernelNotFound", "Expected to find kernel " + k.funcname + ...
                        " but instead the kernels found were {" + okn + "}." ...
                        );
                end

                % save build settings
                k.built_dev_ind = k.Device.Index;
                k.built_stgs    = k.build_settings;
            end
        end

        function varargout = feval(kern, varargin, kwargs)
            % FEVAL - Evaluate Kernel on an OpenCL device
            %
            % feval(KERN, x1, ..., xn) evaluates the oclKernel KERN with the given
            % arguments x1, ..., xn.  The number of input arguments, n, must equal
            % the value of the NumRHSArguments property of KERN, and the types of the
            % input arguments x1, ..., xn must match the description in the
            % ArgumentTypes property of KERN. The input data must be native MATLAB
            % arrays.
            %
            % [y1, ..., ym] = feval(KERN, x1, ..., xn) returns multiple output arguments
            % from the evaluation of the kernel. Each output argument corresponds to the
            % value of the non-const pointer inputs to the OpenCL kernel after it has
            % executed. Each output argument is a native array. The number of output
            % arguments, m, must not exceed the value of the MaxNumLHSArguments property
            % of KERN.
            %
            % Example:
            % If the oclKernel has the following signature:
            %   kernel void myKernel(const global float * pIn,
            %           global float * pInOut1, global float * pInOut2)
            %
            % The corresponding oclKernel object in MATLAB then has the properties:
            %   MaxNumLHSArguments: 2
            %      NumRHSArguments: 3
            %        ArgumentTypes: {'in single vector'  'inout single vector'  ...
            %                        'inout single vector'}
            %
            % You can use feval on this code's kernel (KERN) with the syntax:
            %        [y1, y2] = feval(KERN, x1, x2, x3)
            %
            % The three input arguments, x1, x2, and x3, correspond to the three
            % arguments that are passed into the CUDA function. The output arguments,
            % y1 and y2, correspond to the values of pInOut1 and pInOut2 after the
            % CUDA kernel has executed.
            %
            % See also parallel.gpu.CUDAKernel/feval
            arguments
                kern (1,1) oclKernel
            end
            arguments(Repeating)
                varargin {mustBeNumeric}
            end
            arguments
                kwargs.inplace (1,1) logical = false
            end

            % if not built, build the kernel with defaults 
            if ~kern.built, kern = build(kern); end

            % validate inputs with the signature
            if numel(varargin) ~= numel(kern.ioro)
                error("oclKernel:wrongNumberInputs", ...
                    "Expected " + numel(kern.ioro) + " inputs. The kernel '" ...
                    + kern.funcname + "' has the following declaration:" ...
                    + newline + kern.signature + ";");
            end

            % validate ThreadBlockSize
            if any(kern.ThreadBlockSize > kern.Device.MaxThreadBlockSize)
                error("oclKernel:invalidThreadBlockSize", ...
                    "The work group size of [" ...
                    + join(string(kern.ThreadBlockSize),",") ...
                    + "] cannot exceed the device limit of [" ...
                    + join(string(kern.Device.MaxThreadBlockSize),",") ...
                    + "].");
            end
            if prod(kern.ThreadBlockSize) > kern.MaxThreadsPerBlock
                error("oclKernel:invalidThreadBlockSize", "The number of work items (" ...
                    + prod(kern.ThreadBlockSize) + ") cannot exceed " ...
                    + kern.MaxThreadsPerBlock + ".");
            end

            % init copy of inputs
            varargout = varargin;

            % whether input is complex
            tf = ~cellfun(@isreal, varargout);

            % always turn complex inputs into vectorized real data
            if kwargs.inplace && any(tf), warning("oclKernel:complexInputCopy","Complex inputs will be copied to work around data sizing issues in MatCL."); end
            varargout(tf) = cellfun(@C2R, varargout(tf), 'UniformOutput', 0);

            % cast data types to both a) ensure typing and b) force an 
            % explicit copy of all other inputs by confusing MATLAB
            % TODO: recognize / convert half to uint16 via StoredInteger
            if ~kwargs.inplace
                % get types
                typs = split((kern.ArgumentTypes)')'; % args: {rw, class, size}

                % cast recognized types, and recast unrecognized types
                i = logical(cellfun(@(t) exist(t,'builtin'), typs(2,:))); % whether recognized
                varargout( i) = cellfun(@(x,T) cast(1*x,T       ), varargout( i), typs(2, i), 'UniformOutput',0);
                varargout(~i) = cellfun(@(x,T) cast(1*x,'like',x), varargout(~i), typs(2,~i), 'UniformOutput',0);
            end

            % HACK: work-around a bug in MatCL (since I legally can't fix it ...):
            % if an argument is a const (in) pointer (vector) but the
            % MATLAB input data is scalar, set it to R/W so that MatCL
            % doesn't assume it's pass-by-value (scalar).
            ro = (kern.ioro ... only used as input
                & ~(cellfun(@isscalar, varargout) ... data is non-scalar
                & endsWith(kern.ArgumentTypes, " vector") ... kernel wants pointer
                & contains(kern.ArgumentTypes, "in "))) ... % marked no-output
                | endsWith(kern.ArgumentTypes, " scalar"); % set scalar inputs always read-only

            % launch the kernel
            cl_run_kernel(double(kern.Device.Index), cellstr(kern.funcname), ...
                [kern.GlobalOffset, kern.GlobalSize], kern.ThreadBlockSize, ...
                varargout{:}, double(ro));

            % don't return read-only arguments
            ro = kern.ioro == 1; % read-only
            varargout = varargout(~ro); 
            tf = tf(~ro);

            % return native complex outputs where native complex input
            varargout(tf) = cellfun(@R2C, varargout(tf), 'UniformOutput', 0);
        end

        function defineTypes(kern, types, aliases)
            arguments
                kern (1,1) oclKernel
                types (1,:) string {mustBeMember(types, ["uint8","uint16","uint32","uint64","int8","int16","int32","int64","single","double"])}
                aliases (1,:) string = unique(setdiff(extractBetween( ...
                    string(kern.ArgumentTypes), ("in"|"inout")+" ", " "+("scalar"|"vector") ...
                    ), ["uint8","uint16","uint32","uint64","int8","int16","int32","int64","single","double"] ...
                    , 'stable'), 'stable');
            end

            if numel(types) ~= numel(aliases) % check inputs
                error( ...
                    "oclKernel:definteTypes:invalidNumberOfAliases", ...
                    "Expected a matching type for each alias: [" ...
                    + join(aliases, ", ") + "] but instead got the types [" ...
                    +  join(types, ",") + "]." ...
                    );
            end

            ktps = extractBetween(string(kern.ArgumentTypes), ("in"|"inout")+" ", " "+("scalar"|"vector"));
            for a = 1:numel(aliases)
                ktps(ktps == aliases(a)) = types(a);
            end
            kern.user_def_types = ktps; % set all
        end

        % Dependent, Vector
        function tf = get.built(kern)
            tf = cellfun(@eq     , {kern.Device.Index  }, {kern.built_dev_ind}) ...
            &    cellfun(@isequal, {kern.build_settings}, {kern.built_stgs}   );
            tf = reshape(tf, size(kern));
        end

        % Dependent, Scalar
        % function set.ThreadBlockSize(kern, sz), kern.ThreadBlockSize(1:numel(sz)) = sz; end % no effect
        % function set.GridSize(       kern, sz), kern.GridSize(       1:numel(sz)) = sz; end % no effect
        % function set.GlobalOffset(   kern, sz), kern.GlobalOffset(   1:numel(sz)) = sz; end % no effect
        function set.GlobalSize(kern, sz) % set GlobalSize via GridSize at current ThreadBlockSize
            arguments, kern (1,1) oclKernel, sz (1,:) {mustBeNumeric, mustBePositive}, end
            i = 1:numel(sz);
            kern.ThreadBlockSize(i) = gcd(kern.ThreadBlockSize(i), sz); % force compatible thread size
            kern.GridSize(1:numel(sz)) = sz ./ kern.ThreadBlockSize(1:numel(sz));
        end 
        function sz = get.GlobalSize(kern), sz = kern.GridSize .* kern.ThreadBlockSize; end
        % get GridSize analagous to CUDAKernrl
        function n = get.MaxThreadsPerBlock(kern)
            arguments, kern (1,1) oclKernel, end
            if isempty(kern.Device), n = []; 
            else, n = kern.Device.MaxThreadsPerBlock;
            end
        end
        function n = get.NumRHSArguments(kern), n = length(kern.ioro); end
        function n = get.MaxNumLHSArguments(kern), n = nnz(kern.ioro ~= 1); end
        function s = get.build_settings(kern)
            arguments, kern (1,1) oclKernel, end
            s = join([
                "-I" + kern.include, ...
                "-D" + kern.macros , ...
                       kern.opts     ...
                ]);
        end

        function typs = get.ArgumentTypes(kern)
            arguments, kern (1,1) oclKernel, end

            inps = split(extractAfter(kern.signature,"("), ",")'; % inputs
            typs = repmat("", [3, length(inps)]);

            % set read vs. read/write
            typs(1, kern.ioro) = "in"; % read-onlies
            typs(1,~kern.ioro) = "inout"; % read-onlies

            % get vector vs. scalar
            isptr = contains(inps, ["*", "["+whitespacePattern(0,Inf)+digitsPattern+whitespacePattern(0,Inf)+"]"]); % pointer vs. constant
            typs(3, isptr) = "vector";
            typs(3,~isptr) = "scalar";

            if isempty(kern.user_def_types)
                % identify data type automatically
                attr = "__"+wildcardPattern+"__"; % attribute pattern
                qual = pattern(["__";"";"__"] + ["global", "const", "constant", "local", "private", "volatile"]+["";"";"__"]); % qualifiers
                % TODO: handle attributes with arguments e.g. '__attr__((val))'
                inps = erase(inps, attr);
                inps = erase(inps, qual);

                % data types
                dtyps = arrayfun(@(i) {split(strip(i))}, inps);
                dtyps = cellfun(@(i) join(i(1:end-1)), dtyps);
                dtyps = erase(dtyps, whitespacePattern(0,Inf) + "*"); % ignore pointers
                dtyps = erase(dtyps, digitsPattern(1,2) + textBoundary("end")); % vector types e.g. uchar2 -> uchar

                % convert type via translation table (optional)
                for i = 1:numel(dtyps)
                    switch dtyps(i)
                        case {"uchar"  , "unsigned char" }, t = "uint8" ;
                        case {"ushort" , "unsigned short"}, t = "uint16";
                        case {"uint"   , "unsigned int"  }, t = "uint32";
                        case {"ulong"  , "unsigned long" }, t = "uint64";
                        case {"char"                     }, t = "int8"  ;
                        case {"short"                    }, t = "int16" ;
                        case {"int"                      }, t = "int32" ;
                        case {"long"                     }, t = "int64" ;
                        case {"double", "single", "half" }, t = dtyps(i); % identical
                        otherwise, t = dtyps(i); % macro or template -> no translation
                    end
                    typs(2,i) = t;
                end
            else
                typs(2,:) = kern.user_def_types;
            end

            % convert to cell
            typs = cellstr(join(typs,1));
        end
    end
end

%% Helpers
% complex -> real
function x = C2R(x)
x = reshape(x, [1, size(x)]);
x = cast([real(x); imag(x)], 'like', x);
end

% real -> complex
function x = R2C(x)
x = cast(reshape(complex(x(1,:), x(2,:)), [size(x,2:ndims(x)),1]), 'like', x);
end