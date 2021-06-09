using Faust
using PortAudio

dsp = compile("""
import("stdfaust.lib");
f0 = hslider("f0", 440, 110, 880, 1);
n = 2;
inst = par(i, n, fi.resonbp(f0 * (n+i) / n, 10, 0.1)) :> /(n);
process = _, _ <: inst, inst;
""")

PortAudioStream(2, 2) do stream
    block_size = 1024
    init(dsp, block_size=block_size, samplerate=Int(stream.samplerate))
    while true
        dsp.inputs = convert(Matrix{Float32}, read(stream, block_size))
        write(stream, compute(dsp))
    end
end
