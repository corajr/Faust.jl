module Faust

export DSPBlock, compile, init, compute

include("llvm-c-dsp.jl")

mutable struct DSPBlock
    factory::Ptr{llvm_dsp_factory}
    dsp::Ptr{llvm_dsp}
    ui::UIGlue
    block_size::Int
    samplerate::Int
    inputs::Matrix{Float32}
    outputs::Matrix{Float32}
    function DSPBlock(factory)
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

function compile(code; name="score", argv=[], target="", opt=-1)
    factory = createCDSPFactoryFromString(name, code, argv, target, opt)
    DSPBlock(factory)
end

function init(d::DSPBlock; block_size=256, samplerate=44100)
    if d.dsp != C_NULL
        deleteCDSPInstance(d.dsp)
    end

    d.block_size = block_size
    d.samplerate = samplerate

    d.dsp = createCDSPInstance(d.factory)
    initCDSPInstance(d.dsp, d.samplerate)
    d.ui = UIGlue()
    buildUserInterfaceCDSPInstance(d.dsp, d.ui)
    inputChannels = getNumInputsCDSPInstance(d.dsp)
    outputChannels = getNumOutputsCDSPInstance(d.dsp)
    d.inputs = zeros(Float32, block_size, inputChannels)
    d.outputs = zeros(Float32, block_size, outputChannels)
    d
end

function compute(d::DSPBlock)
    computeCDSPInstance(d.dsp, d.block_size, d.inputs, d.outputs)
end

end