# import Pkg; Pkg.add(["FiniteDifferences", "Plots"])
using Faust, FiniteDifferences, Plots

process = compile("""
import("stdfaust.lib");

process = pm.ks(pm.f2l(ba.midikey2hz(60)), 0.1);
""")

function f(x)
    init!(process, block_size=size(x, 1))
    process.inputs = x
    compute!(process)
end

x = randn(1024, 1)
∇f = jacobian(central_fdm(5, 1), f, x)[1]
heatmap(∇f)
