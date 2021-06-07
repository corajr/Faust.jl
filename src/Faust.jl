module Faust

using Base: UInt8

export llvm_dsp, llvm_dsp_factory, 
    createCDSPFactoryFromString, 
    writeCDSPFactoryToIR,
    createCDSPInstance,
    getNumInputsCDSPInstance,
    getNumOutputsCDSPInstance,    
    buildUserInterfaceCDSPInstance,
    getSampleRateCDSPInstance,
    initCDSPInstance,
    instanceInitCDSPInstance,
    instanceConstantsCDSPInstance,
    instanceResetUserInterfaceCDSPInstance,
    instanceClearCDSPInstance,
    cloneCDSPInstance,
    metadataCDSPInstance,
    computeCDSPInstance,
    deleteCDSPFactory,
    deleteCDSPInstance,
    freeCMemory

function find_faust()
    if haskey(ENV, "FAUSTLDDIR")
        ENV["FAUSTLDDIR"]
    elseif Sys.iswindows()
        "C:\\Program Files\\Faust\\lib\\faust.dll"
    else
        "libfaust"
    end
end

function find_faust_libraries()
    if haskey(ENV, "FAUSTLIB")
        ENV["FAUSTLIB"]
    elseif Sys.iswindows()
        "C:\\Program Files\\Faust\\share\\faust"
    else
        "/usr/local/share/faust"
    end
end

mutable struct llvm_dsp_factory
end

mutable struct llvm_dsp
end

# /**
# * Create a Faust DSP factory from a DSP source code as a string. Note that the library keeps an internal cache of all 
# * allocated factories so that the compilation of the same DSP code (that is same source code and 
# * same set of 'normalized' compilations options) will return the same (reference counted) factory pointer. You will 
# * have to explicitly use deleteCDSPFactory to properly decrement reference counter when the factory is no more needed.
# * 
# * @param name_app - the name of the Faust program
# * @param dsp_content - the Faust program as a string
# * @param argc - the number of parameters in argv array
# * @param argv - the array of parameters (Warning : aux files generation options will be filtered (-svg, ...) --> use generateAuxFiles)
# * @param target - the LLVM machine target: like 'i386-apple-macosx10.6.0:opteron',
# *                 using an empty string takes the current machine settings,
# *                 and i386-apple-macosx10.6.0:generic kind of syntax for a generic processor
# * @param error_msg - the error string to be filled, has to be 4096 characters long
# * @param opt_level - LLVM IR to IR optimization level (from -1 to 4, -1 means 'maximum possible value' 
# * since the maximum value may change with new LLVM versions)
# *
# * @return a valid DSP factory on success, otherwise a null pointer.
# */ 
# llvm_dsp_factory* createCDSPFactoryFromString(const char* name_app,
#                                              const char* dsp_content,
#                                              int argc, const char* argv[],
#                                              const char* target, 
#                                              char* error_msg,
#                                              int opt_level);
function createCDSPFactoryFromString(
    name_app,
    dsp_content,
    argv,
    target,
    opt_level)
    argc = length(argv)
    error_msg = Vector{UInt8}(undef, 4096)
    output_ptr = cd(() -> ccall(
        (:createCDSPFactoryFromString, find_faust()),
        Ptr{llvm_dsp_factory},
        (Cstring, Cstring, Cint, Ptr{Cstring}, Cstring, Ptr{UInt8}, Cint),
        name_app, dsp_content, argc, argv, target, error_msg, opt_level,
    ), find_faust_libraries())
    if output_ptr == C_NULL
        error = GC.@preserve error_msg unsafe_string(pointer(error_msg))
        throw(ErrorException("Could not initialize C DSP factory: $error"))
    end

    return output_ptr
end

# /**
# * Delete a Faust DSP factory, that is decrements it's reference counter, possibly really deleting the internal pointer. 
# * Possibly also delete DSP pointers associated with this factory, if they were not explicitly deleted with deleteCDSPInstance.
# * Beware : all kept factories and DSP pointers (in local variables...) thus become invalid. 
# * 
# * @param factory - the DSP factory to be deleted.
# *
# * @return true if the factory internal pointer was really deleted, and false if only 'decremented'.
# */                                 
# bool deleteCDSPFactory(llvm_dsp_factory* factory);
function deleteCDSPFactory(factory)
    ret = ccall(
        (:deleteCDSPFactory, find_faust()),
        Cuchar,
        (Ptr{llvm_dsp_factory},),
        factory
    )
    return Bool(ret)
end

function startMTDSPFactories()
    return Bool(ccall(
        (:startMTDSPFactories, find_faust()),
        Cuchar,
        (),
    ))
end

function stopMTDSPFactories()
    ccall(
        (:stopMTDSPFactories, find_faust()),
        Cuchar,
        (),
    )
end


# /**
# * Write a Faust DSP factory into a LLVM IR (textual) string.
# * 
# * @param factory - the DSP factory
# *
# * @return the LLVM IR (textual) as a string (to be deleted by the caller using freeCMemory).
# */
# char* writeCDSPFactoryToIR(llvm_dsp_factory* factory);
function writeCDSPFactoryToIR(factory)
    output_str = ccall(
        (:writeCDSPFactoryToIR, find_faust()),
        Cstring,
        (Ptr{llvm_dsp_factory},),
        factory
    )
    if output_str == C_NULL
        throw(ErrorException("Could not write DSP factory IR"))
    end
    copied = GC.@preserve output_str unsafe_string(output_str)
    freeCMemory(output_str)
    return copied
end

# int getNumInputsCDSPInstance(llvm_dsp* dsp);
function getNumInputsCDSPInstance(dsp)
    ret = ccall(
        (:getNumInputsCDSPInstance, find_faust()),
        Cint,
        (Ptr{llvm_dsp},),
        dsp
    )
    return ret
end

# int getNumOutputsCDSPInstance(llvm_dsp* dsp);
function getNumOutputsCDSPInstance(dsp)
    return ccall(
        (:getNumOutputsCDSPInstance, find_faust()),
        Cint,
        (Ptr{llvm_dsp},),
        dsp
    )
end

mutable struct UIGlue
end

# void buildUserInterfaceCDSPInstance(llvm_dsp* dsp, UIGlue* interface);
function buildUserInterfaceCDSPInstance(dsp, interface)
    return ccall(
        (:buildUserInterfaceCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp}, Ptr{UIGlue}),
        dsp, interface
    )
end

# /**
#  * The free function to be used on memory returned by getCDSPMachineTarget, getCName, getCSHAKey,
#  * getCDSPCode, getCLibraryList, getAllCDSPFactories, writeCDSPFactoryToBitcode,
#  * writeCDSPFactoryToIR, writeCDSPFactoryToMachine,expandCDSPFromString and expandCDSPFromFile.
#  *
#  * This is MANDATORY on Windows when otherwise all nasty runtime version related crashes can occur.
#  *
#  * @param ptr - the pointer to be deleted.
#  */
function freeCMemory(p)
    ccall(
        (:freeCMemory, find_faust()),
        Cvoid,
        (Cstring,),
        p
    )
end

# int getSampleRateCDSPInstance(llvm_dsp* dsp);
function getSampleRateCDSPInstance(dsp)
    return ccall(
        (:getSampleRateCDSPInstance, find_faust()),
        Cint,
        (Ptr{llvm_dsp},),
        dsp
    )
end

# void initCDSPInstance(llvm_dsp* dsp, int sample_rate);
function initCDSPInstance(dsp, sample_rate)
    ccall(
        (:initCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp}, Cint),
        dsp, sample_rate
    )
end

# void instanceInitCDSPInstance(llvm_dsp* dsp, int sample_rate);
function instanceInitCDSPInstance(dsp, sample_rate)
    ccall(
        (:instanceInitCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp}, Cint),
        dsp, sample_rate
    )
end

# void instanceConstantsCDSPInstance(llvm_dsp* dsp, int sample_rate);
function instanceConstantsCDSPInstance(dsp, sample_rate)
    ccall(
        (:instanceConstantsCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp}, Cint),
        dsp, sample_rate
    )
end

# void instanceResetUserInterfaceCDSPInstance(llvm_dsp* dsp);
function instanceResetUserInterfaceCDSPInstance(dsp)
    ccall(
        (:instanceResetUserInterfaceCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp},),
        dsp
    )
end

# void instanceClearCDSPInstance(llvm_dsp* dsp);
function instanceClearCDSPInstance(dsp)
    ccall(
        (:instanceClearCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp},),
        dsp
    )
end

# llvm_dsp* cloneCDSPInstance(llvm_dsp* dsp);
function cloneCDSPInstance(dsp)
    return ccall(
        (:cloneCDSPInstance, find_faust()),
        Ptr{llvm_dsp},
        (Ptr{llvm_dsp},),
        dsp
    )
end

mutable struct MetaGlue
end

# void metadataCDSPInstance(llvm_dsp* dsp, MetaGlue* meta);
function metadataCDSPInstance(dsp, meta)
    ccall(
        (:metadataCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp}, Ptr{MetaGlue}),
        dsp, meta,
    )
end

# void computeCDSPInstance(llvm_dsp* dsp, int count, FAUSTFLOAT** input, FAUSTFLOAT** output);
function computeCDSPInstance(dsp, count, input = nothing, output = nothing)
    if isnothing(input)
        inputChannels = getNumInputsCDSPInstance(dsp)
        input = zeros(Float32, count, inputChannels)
    end
    if isnothing(output)
        outputChannels = getNumOutputsCDSPInstance(dsp)
        output = zeros(Float32, count, outputChannels)
    end
    inputRef = [pointer(input, i) for i=1:size(input, 1):length(input)]
    outputRef = [pointer(output, i) for i=1:size(output, 1):length(output)]

    ccall(
        (:computeCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp}, Cint, Ptr{Ptr{Float32}}, Ptr{Ptr{Float32}}),
        dsp, count, inputRef, outputRef
    )
    return output
end

# /**
# * Create a Faust DSP instance.
# * 
# * @param factory - the Faust DSP factory
# * 
# * @return the DSP instance on success, otherwise a null pointer.
# */
# llvm_dsp* createCDSPInstance(llvm_dsp_factory* factory);
function createCDSPInstance(factory)
    output_ptr = ccall(
        (:createCDSPInstance, find_faust()),
        Ptr{llvm_dsp},
        (Ptr{llvm_dsp_factory},),
        factory
    )
    if output_ptr == C_NULL
        throw(ErrorException("Could not initialize C DSP instance"))
    end
    return output_ptr
end

# /**
#  * Delete a Faust DSP instance.
#  * 
#  * @param dsp - the DSP instance to be deleted.
#  */ 
# void deleteCDSPInstance(llvm_dsp* dsp);
function deleteCDSPInstance(dsp)
    ccall(
        (:deleteCDSPInstance, find_faust()),
        Cvoid,
        (Ptr{llvm_dsp},),
        dsp
    )
end

end