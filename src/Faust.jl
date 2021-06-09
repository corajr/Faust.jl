module Faust

export DSP, compile, init, compute

include("llvm-c-dsp.jl")

mutable struct DSP
    factory::Ptr{llvm_dsp_factory}
    dsp::Ptr{llvm_dsp}
    block_size::Int
    inputs::Matrix{Float32}
    outputs::Matrix{Float32}
    function DSP(factory)
        d = new(factory, C_NULL)
        function f(d)
            if d.dsp != C_NULL
                deleteCDSPInstance(d.dsp)
            end
            if d.factory != C_NULL
                deleteCDSPFactory(d.factory)
            end
        end
        finalizer(f, d)
    end
end

function compile(code, name="score", argv=[], target="", opt=-1)
    factory = createCDSPFactoryFromString(name, code, argv, target, opt)
    DSP(factory)
end

function init(d::DSP, block_size=256, sr=22050)
    if d.dsp != C_NULL
        deleteCDSPInstance(d.dsp)
    end

    d.dsp = createCDSPInstance(d.factory)
    initCDSPInstance(d.dsp, sr)
    inputChannels = getNumInputsCDSPInstance(d.dsp)
    outputChannels = getNumOutputsCDSPInstance(d.dsp)
    d.block_size = block_size
    d.inputs = zeros(Float32, block_size, inputChannels)
    d.outputs = zeros(Float32, block_size, outputChannels)
    d
end

function compute(d::DSP)
    computeCDSPInstance(d.dsp, d.block_size, d.inputs, d.outputs)
end

end