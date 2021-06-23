module Faust

export DSPBlock, compile, init!, compute!, setparams!

include("llvm-c-dsp.jl")

FaustFloat = Union{Float32, Float64}

mutable struct DSPBlock{T <: FaustFloat}
    factory::Ptr{llvm_dsp_factory}
    dsp::Ptr{llvm_dsp}
    ui::UIGlue
    block_size::Int
    samplerate::Int
    inputs::Matrix{T}
    outputs::Matrix{T}
    function DSPBlock(factory, floattype)
        d = new{floattype}(factory, C_NULL)
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

"""
    compile(code; name="score", argv=[], target="", opt=-1)

Compiles `code` to a `DSPBlock`.

# Arguments
- `argv::Vector{String}`: List of args to the Faust compiler, e.g.
    "-double": double precision
    "-vec": vectorize code.
- `target::String`: target for which to build LLVM IR. Defaults to current machine.
- `opt::Integer`: -1 is "highest level available".

# Examples
```julia-repl
julia> d = compile("import(\"stdfaust.lib\"); process = os.osc(freq) : *(0.25) <: _, _;")
```
"""
function compile(code; name="score", argv=[], target="", opt=-1)
    factory = createCDSPFactoryFromString(name, code, argv, target, opt)
    floattype = "-double" in argv ? Float64 : Float32
    DSPBlock(factory, floattype)
end

"""
    init!(d; block_size=256, samplerate=44100)

Initializes the DSPBlock `d` for use.

Must be called before `compute!`. The old DSP instance will be deleted,
so this can be called repeatedly and will reset internal states, etc.
"""
function init!(d::DSPBlock{T}; block_size=256, samplerate=44100) where T <: FaustFloat
    if d.dsp != C_NULL
        deleteCDSPInstance(d.dsp)
    end

    d.block_size = block_size
    d.samplerate = samplerate

    d.dsp = createCDSPInstance(d.factory)
    initCDSPInstance(d.dsp, d.samplerate)
    d.ui = UIGlue()
    buildUserInterfaceCDSPInstance(d.dsp, d.ui)
    input_channels = getNumInputsCDSPInstance(d.dsp)
    output_channels = getNumOutputsCDSPInstance(d.dsp)
    d.inputs = zeros(T, block_size, input_channels)
    d.outputs = zeros(T, block_size, output_channels)
    d
end

"""
    compute!(d)

Computes `d.block_size` samples of signal and returns `d.outputs` (d.blocK_size, n_outputs).

`d.inputs` should be assigned an incoming signals matrix of dims (d.block_size, n_inputs)
before calling this function.

# Examples
```julia-repl
julia> d = init!(compile("import(\"stdfaust.lib\"); process = os.oscs(440);"));
julia> compute!(d)
256×1 Matrix{Float32}:
1.0
0.99607
0.9882256
0.9764974
0.96093166
0.9415895
0.9185469
⋮
-0.99841714
-1.0004897
-0.9986304
-0.99284655
-0.98316085
-0.96961135
-0.9522513
```

"""
function compute!(d::DSPBlock{T}) where T <: FaustFloat
    computeCDSPInstance(d.dsp, d.block_size, d.inputs, d.outputs)
end

"""
    setparams!(d, params)

Sets the parameters on `d` using keys from `params`.

One can extract the available params as UIRange structs from `d.ui.ranges`
after iniialization.

# Examples
```julia-repl
julia> d = init!(compile("process = nentry(\"v\", 0, 0, 1, 0.001);"))
julia> d.ui.ranges
Dict{String, Faust.UIRange} with 1 entry:
  "/score/v" => UIRange(0.0, 0.0, 1.0, 0.001)
julia> setparams!(d, Dict("/score/v" => 0.5f0))
```
"""
function setparams!(d::DSPBlock{T}, params) where T <: FaustFloat
    for (k, v) in params
        unsafe_store!(d.ui.paths[k], v)
    end
end

end