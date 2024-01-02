/* This project is licensed under the terms of the Creative Commons CC
 * BY-NC 4.0 license. */


#include "matrix.h"
#include "mex.h"
#include "tmwtypes.h"
#include <math.h>

#include "ocl_dev_mgr.hpp" // use the same settings as in the MatCL dependency
#include <CL/cl.h>

#define PTYPE_BOOL 1 
#define PTYPE_CHAR 2 
#define PTYPE_UINT 3 
#define PTYPE_ULNG 4 
#define PTYPE_SIZT 5 
#define PTYPE_SZTA 6 
// not yet supported
#define PTYPE_PLFM 0 
#define PTYPE_DEVC 8 


std::vector<cl::Device> getOclDevices(){

  // Variables
  std::vector<cl::Device> devs, tmp; // devices
  std::vector<cl::Platform> platforms; // platforms

  // get devices per platform devices
  cl::Platform::get(&platforms); // all platforms
  for (cl::Platform const& p : platforms){ // for each platform
    p.getDevices(CL_DEVICE_TYPE_ALL, &tmp);
    devs.insert(devs.end(), tmp.begin(), tmp.end());
  }

  return devs;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {

    // input:  {cell-array of property names to request}
    // output: {cell-array of outputs}

  std::vector<cl::Device> devs = getOclDevices();
  
  // validate that the (only) input is a cell array
  if(nrhs < 1 || !mxIsCell(prhs[0])){
    // error case - requires one input char array
    mexErrMsgIdAndTxt("MatCL:cl_get_device_info:NonCellInput",
           "The input must be a cell array of character arrays. Use 'cellstr' to convert an array of strings to this format.");
    return;
  }

  // get sizing
  const mwSize num_props = mxGetNumberOfElements(prhs[0]); // number of requested fields

  // validate that each cell contains a char array
  {
  bool chars_in = true;
  for(mwIndex j = 0; j < num_props; ++j){
    chars_in = chars_in && mxIsChar(mxGetCell(prhs[0], j));
  }
  if(!chars_in){
    // error - not all contents are char type
    mexErrMsgIdAndTxt("MatCL:cl_get_device_info:NonCharInput",
           "The cell array contains non-character argument(s). Use 'char' to convert a string to a character array.");
    return;
  }
  }
  
  
  // get OpenCl device names  
  cl_device_info prop_num;
  char prop_type = 0;
  
  // allocate output
  mxArray * cell_array_ptr = mxCreateCellMatrix(num_props, devs.size());

  // for each device ...
  // mexPrintf("Discovering ..."); // DEBUG
  for (mwIndex i = 0; i < devs.size(); i++) {
    for(mwIndex j = 0; j < num_props; ++j){
        char * prop_name = (char *) mxArrayToString(mxGetCell(prhs[0], j)); // requested property
        
        // mexPrintf("Searching for '"); mexPrintf(prop_name); mexPrintf("' ... "); // DEBUG
        
        prop_type = 0; // init
        if (!strcmp(prop_name, "CL_DEVICE_ADDRESS_BITS"                   )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_ADDRESS_BITS                   ;} 
        if (!strcmp(prop_name, "CL_DEVICE_AVAILABLE"                      )){prop_type = PTYPE_BOOL; prop_num = CL_DEVICE_AVAILABLE                      ;} 
        if (!strcmp(prop_name, "CL_DEVICE_BUILT_IN_KERNELS"               )){prop_type = PTYPE_CHAR; prop_num = CL_DEVICE_BUILT_IN_KERNELS               ;} 
        if (!strcmp(prop_name, "CL_DEVICE_COMPILER_AVAILABLE"             )){prop_type = PTYPE_BOOL; prop_num = CL_DEVICE_COMPILER_AVAILABLE             ;} 
        if (!strcmp(prop_name, "CL_DEVICE_EXTENSIONS"                     )){prop_type = PTYPE_CHAR; prop_num = CL_DEVICE_EXTENSIONS                     ;} 
        if (!strcmp(prop_name, "CL_DEVICE_GLOBAL_MEM_CACHE_SIZE"          )){prop_type = PTYPE_ULNG; prop_num = CL_DEVICE_GLOBAL_MEM_CACHE_SIZE          ;} 
        if (!strcmp(prop_name, "CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE"      )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE      ;} 
        if (!strcmp(prop_name, "CL_DEVICE_GLOBAL_MEM_SIZE"                )){prop_type = PTYPE_ULNG; prop_num = CL_DEVICE_GLOBAL_MEM_SIZE                ;} 
        if (!strcmp(prop_name, "CL_DEVICE_LINKER_AVAILABLE"               )){prop_type = PTYPE_BOOL; prop_num = CL_DEVICE_LINKER_AVAILABLE               ;} 
        if (!strcmp(prop_name, "CL_DEVICE_LOCAL_MEM_SIZE"                 )){prop_type = PTYPE_ULNG; prop_num = CL_DEVICE_LOCAL_MEM_SIZE                 ;} 
        if (!strcmp(prop_name, "CL_DEVICE_MAX_CLOCK_FREQUENCY"            )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_MAX_CLOCK_FREQUENCY            ;}
        if (!strcmp(prop_name, "CL_DEVICE_MAX_COMPUTE_UNITS"              )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_MAX_COMPUTE_UNITS              ;}
        if (!strcmp(prop_name, "CL_DEVICE_MAX_CONSTANT_ARGS"              )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_MAX_CONSTANT_ARGS              ;} 
        if (!strcmp(prop_name, "CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE"       )){prop_type = PTYPE_ULNG; prop_num = CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE       ;} 
        if (!strcmp(prop_name, "CL_DEVICE_MAX_MEM_ALLOC_SIZE"             )){prop_type = PTYPE_ULNG; prop_num = CL_DEVICE_MAX_MEM_ALLOC_SIZE             ;}
        if (!strcmp(prop_name, "CL_DEVICE_MAX_PARAMETER_SIZE"             )){prop_type = PTYPE_ULNG; prop_num = CL_DEVICE_MAX_PARAMETER_SIZE             ;} 
        if (!strcmp(prop_name, "CL_DEVICE_MAX_WORK_GROUP_SIZE"            )){prop_type = PTYPE_SIZT; prop_num = CL_DEVICE_MAX_WORK_GROUP_SIZE            ;}
        if (!strcmp(prop_name, "CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS"       )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS       ;}
        if (!strcmp(prop_name, "CL_DEVICE_MAX_WORK_ITEM_SIZES"            )){prop_type = PTYPE_SZTA; prop_num = CL_DEVICE_MAX_WORK_ITEM_SIZES            ;}
        if (!strcmp(prop_name, "CL_DEVICE_OPENCL_C_VERSION"               )){prop_type = PTYPE_CHAR; prop_num = CL_DEVICE_OPENCL_C_VERSION               ;} 
        if (!strcmp(prop_name, "CL_DEVICE_MAX_PARAMETER_SIZE"             )){prop_type = PTYPE_ULNG; prop_num = CL_DEVICE_MAX_PARAMETER_SIZE             ;} 
        if (!strcmp(prop_name, "CL_DEVICE_NAME"                           )){prop_type = PTYPE_CHAR; prop_num = CL_DEVICE_NAME                           ;}
        if (!strcmp(prop_name, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR"    )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR    ;}
        if (!strcmp(prop_name, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT"   )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT   ;}
        if (!strcmp(prop_name, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT"     )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT     ;}
        if (!strcmp(prop_name, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG"    )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG    ;}
        if (!strcmp(prop_name, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT"   )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT   ;}
        if (!strcmp(prop_name, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE"  )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE  ;}
        if (!strcmp(prop_name, "CL_DEVICE_PREFERRED_VECTOR_WIDTH_HALF"    )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_PREFERRED_VECTOR_WIDTH_HALF    ;}
        if (!strcmp(prop_name, "CL_DEVICE_PRINTF_BUFFER_SIZE"             )){prop_type = PTYPE_SIZT; prop_num = CL_DEVICE_PRINTF_BUFFER_SIZE             ;}
        if (!strcmp(prop_name, "CL_DEVICE_PROFILE"                        )){prop_type = PTYPE_CHAR; prop_num = CL_DEVICE_PROFILE                        ;}
        if (!strcmp(prop_name, "CL_DEVICE_PROFILING_TIMER_RESOLUTION"     )){prop_type = PTYPE_SIZT; prop_num = CL_DEVICE_PROFILING_TIMER_RESOLUTION     ;}
        if (!strcmp(prop_name, "CL_DEVICE_VENDOR"                         )){prop_type = PTYPE_CHAR; prop_num = CL_DEVICE_VENDOR                         ;}
        if (!strcmp(prop_name, "CL_DEVICE_VENDOR_ID"                      )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_VENDOR_ID                      ;}
        if (!strcmp(prop_name, "CL_DEVICE_VERSION"                        )){prop_type = PTYPE_CHAR; prop_num = CL_DEVICE_VERSION                        ;}
        if (!strcmp(prop_name, "CL_DRIVER_VERSION"                        )){prop_type = PTYPE_CHAR; prop_num = CL_DRIVER_VERSION                        ;}        

        // these need an extra step or two of look-up to give a meaningful result
        if (!strcmp(prop_name, "CL_DEVICE_PLATFORM"                       )){prop_type = PTYPE_PLFM; prop_num = CL_DEVICE_PLATFORM                       ;}
        if (!strcmp(prop_name, "CL_DEVICE_TYPE"                           )){prop_type = PTYPE_DEVC; prop_num = CL_DEVICE_TYPE                           ;}

        // These are not supported by the header. They are likely > v1.2 queries.
        // if (!strcmp(prop_name, "CL_DEVICE_MAX_GLOBAL_VARIABLE_SIZE"       )){prop_type = PTYPE_SIZT; prop_num = CL_DEVICE_MAX_GLOBAL_VARIABLE_SIZE       ;}
        // if (!strcmp(prop_name, "CL_DEVICE_MAX_NUM_SUB_GROUPS"             )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_MAX_NUM_SUB_GROUPS             ;} 
        // if (!strcmp(prop_name, "CL_DEVICE_MAX_ON_DEVICE_QUEUES"           )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_MAX_ON_DEVICE_QUEUES           ;} 
        // if (!strcmp(prop_name, "CL_DEVICE_QUEUE_ON_DEVICE_MAX_SIZE"       )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_QUEUE_ON_DEVICE_MAX_SIZE       ;}
        // if (!strcmp(prop_name, "CL_DEVICE_QUEUE_ON_DEVICE_PREFERRED_SIZE" )){prop_type = PTYPE_UINT; prop_num = CL_DEVICE_QUEUE_ON_DEVICE_PREFERRED_SIZE ;}
        
        // extract data into a new variable
        mxArray * mw_info;
        switch (prop_type){
            case PTYPE_ULNG:{
                mw_info = mxCreateUninitNumericMatrix(1,1,mxUINT64_CLASS, mxREAL);
                (devs[i]).getInfo(prop_num, (uint64_t *) mxGetUint64s(mw_info)); // load 
                } break;
            case PTYPE_SIZT:{
                mw_info = mxCreateUninitNumericMatrix(1,1,mxUINT64_CLASS, mxREAL);
                (devs[i]).getInfo(prop_num, (uint64_t *) mxGetUint64s(mw_info)); // load 
                } break;
            case PTYPE_UINT:{
                mw_info = mxCreateUninitNumericMatrix(1,1,mxUINT32_CLASS, mxREAL);
                (devs[i]).getInfo(prop_num, (uint32_t *) mxGetUint32s(mw_info)); // load 
                } break;
            case PTYPE_BOOL:{
                cl_bool tf;
                (devs[i]).getInfo(prop_num, &tf); // load 
                mw_info = mxCreateLogicalScalar(tf); // store
                } break;
            case PTYPE_SZTA:{
                std::vector<size_t> tmp_size; // array of size_t values
                (devs[i]).getInfo(prop_num, &tmp_size); // load
                mw_info = mxCreateNumericMatrix(1,tmp_size.size(),mxUINT64_CLASS, mxREAL);
                uint64_t * x = (uint64_t *) mxGetData(mw_info);
                for(int k = 0; k < tmp_size.size(); ++k) {x[k] = tmp_size[k];}
                } break;
            case PTYPE_CHAR:{
                std::string txt;
                (devs[i]).getInfo(prop_num, &txt); // load 
                mw_info = mxCreateString(txt.c_str());
                } break;
            case PTYPE_DEVC:{
                cl_device_type id;
                (devs[i]).getInfo(prop_num, (cl_device_id *) &id); // load 
                std::string txt="";
                if (id == CL_DEVICE_TYPE_CPU        ) {txt += "cpu | ";}
                if (id == CL_DEVICE_TYPE_GPU        ) {txt += "gpu | ";}
                if (id == CL_DEVICE_TYPE_ACCELERATOR) {txt += "accelerator | ";}
                if (id == CL_DEVICE_TYPE_DEFAULT    ) {txt += "default | ";}
                if (id == CL_DEVICE_TYPE_CUSTOM     ) {txt += "custom | ";}
                txt.erase(txt.length() - 3); // delete separators at the end
                mw_info = mxCreateString(txt.c_str()); // pass string to MATLAB
                } break;
            default:{
                // not enumerated -> empty double
                // mexPrintf("No data has been placed."); // DEBUG
                mw_info = mxCreateNumericMatrix(0,0,mxDOUBLE_CLASS,mxREAL);
                } break;
        }

        // prop_type ? mexPrintf("Found matching type.\n") : mexPrintf("No matching type found.\n"); // DEBUG

        // store each data within the cell
        mxSetCell(cell_array_ptr, j + i * num_props, mxDuplicateArray(mw_info));
    } // each property
  } // each device
 
 
  // set output
  plhs[0] = cell_array_ptr;

  // mexPrintf("Done!\n"); // DEBUG

  return;
}
