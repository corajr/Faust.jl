# Faust.jl

Julia wrapper for the [Faust](https://faust.grame.fr/) compiler.

Uses the Faust LLVM [C API](https://github.com/grame-cncm/faust/blob/master-dev/architecture/faust/dsp/llvm-c-dsp.h).

## Usage

```julia
using Faust

# Create a DSP factory.
dsp = compile("""
import("stdfaust.lib");

freq = hslider("freq", 440, 20, 20000, 1);
gain = hslider("gain", 0.25, 0, 1, 0.001);
process = os.oscs(freq) * gain;
""")

# Initialize DSP instance and controls.
init!(dsp; block_size=1024, samplerate=48000)

# Compute one block of audio.
compute!(dsp)
```

By default, programs are compiled as single-precision; you can give `-double` or
other arguments to the compiler like so:

```
compile("process = _;"; name="passthrough", argv=["-double", "-vec"])
```

Each call to `compute!` will calculate `block_size` samples and return the
output as a matrix of (block_size, n_channels). If the program takes input,
set `dsp.inputs` to a similar matrix before calling `compute!`:

```julia
passthrough = init!(compile("process = _, _;"))
x = rand(Float32, 256, 2)
passthrough.inputs = x
@test compute!(passthrough) == x
```

After calling `init!`, any UI elements declared in your code will have their
path names and ranges available via `dsp.ui.ranges`.

```julia
julia> dsp.ui.ranges
Dict{String, Faust.UIRange} with 2 entries:
  "/score/gain" => UIRange(0.25, 0.0, 1.0, 0.001)
  "/score/freq" => UIRange(440.0, 20.0, 20000.0, 1.0)

julia> ctrl = dsp.ui.ranges["/score/freq"]; (ctrl.min, ctrl.max)
(20.0f0, 20000.0f0)
```

One can then set the values of these params like:

```
setparams!(dsp, Dict("/score/freq" => 220.0f0))
```

See [examples/portaudio.jl](examples/portaudio.jl) to see how the DSP can be
wrapped for audio IO.