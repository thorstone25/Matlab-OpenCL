# Matlab-OpenCL

[![License](https://licensebuttons.net/l/by-nc/3.0/88x31.png)](https://creativecommons.org/licenses/by-nc/4.0/legalcode)

OpenCL kernel support to emulate CUDA kernel support in MATLAB

This project provides an interface to run OpenCL kernels analagously to CUDA kernels provided by the [Parallel Computing Toolbox](https://www.mathworks.com/products/parallel-computing.html) in MATLAB. The API emulates the analagous classes in MATLAB to maximize code re-use while allowing for architectural differences in OpenCL. 

| Native | Matlab-OpenCL |
| ------------ | ------------ |
| [parallel.gpu.CUDAKernel](https://www.mathworks.com/help/parallel-computing/parallel.gpu.cudakernel.html) | [oclKernel](oclKernel.m) |
| [gpuDevice](https://www.mathworks.com/help/parallel-computing/parallel.gpu.gpudevice.html) | [oclDevice](oclDevice.m) |
| [gpuDeviceCount](https://www.mathworks.com/help/parallel-computing/parallel.gpu.gpudevice.gpudevicecount.html) | [oclDeviceCount](oclDeviceCount.m) |
| [gpuDeviceTable](https://www.mathworks.com/help/parallel-computing/parallel.gpu.gpudevice.gpudevicetable.html) | [oclDeviceTable](oclDeviceTable.m) |

## Requirements
* MATLAB R2020b or later
* A working OpenCL installation with available devices (verifiable with e.g. `clinfo` on linux)
* A supported [mex compiler](https://www.mathworks.com/support/requirements/supported-compilers.html)

## Quick Start
1. Download the repository and its submodules
```
git clone --recurse-submodules https://github.com:thorstone25/Matlab-OpenCL.git
```
2. Open the [Project](https://www.mathworks.com/help/matlab/projects.html) in MATLAB
```
>> cd Matlab-OpenCL;
>> openProject MatlabOpenCL.prj;
```
3. Run the example script
```
>> addpath examples;
>> img_test_mocl;
```
## Documentation
Further documentation is provided internally via `help` and `doc`, e.g. `>> doc oclKernel`.

