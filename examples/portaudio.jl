using Faust
using PortAudio

argv = ["-vec"]
code = """
import("stdfaust.lib");
f0 = hslider("[foo:bar]f0", 440, 110, 880, 1);
n = 2;
inst = par(i, n, fi.resonbp(f0 * (n+i) / n, 10, 0.1)) :> /(n);
process = _, _ <: inst, inst;
"""
factory = createCDSPFactoryFromString("score", code, argv, "", -1)
dsp = createCDSPInstance(factory)

try
    PortAudioStream(2, 2) do stream
        initCDSPInstance(dsp, Int(stream.samplerate))
        while true
            input = convert(Matrix{Float32}, read(stream, 1024))
            write(stream, computeCDSPInstance(dsp, 1024, input))
        end
    end
finally
    deleteCDSPInstance(dsp)
    deleteCDSPFactory(factory)
end