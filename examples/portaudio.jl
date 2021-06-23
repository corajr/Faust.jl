# import Pkg; Pkg.add("PortAudio")
using Faust, PortAudio

dsp = compile("""
import("stdfaust.lib");

notes = 48, 55, 60, 62, 64, 67, 71;
n = ba.count(notes);

bank = par(i, n, fi.resonbp(ba.take(i+1, notes) : ba.midikey2hz, 1000, 0.007) : sp.spat(2, theta(i), d(i)))
with {
    theta(i) = (i / n) * 2 * ma.PI;
    d(i) = i / n;
};

process = sp.stereoize(_ <: bank :> _);
""")

devices = PortAudio.devices()
dev = filter(x -> x.maxinchans == 2 && x.maxoutchans == 2, devices)[1]

PortAudioStream(dev, dev) do stream
    block_size = 1024
    init!(dsp, block_size=block_size, samplerate=Int(stream.samplerate))
    while true
        dsp.inputs = convert(Matrix{Float32}, read(stream, block_size))
        write(stream, compute!(dsp))
    end
end
