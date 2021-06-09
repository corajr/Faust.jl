# import Pkg; Pkg.add("FiniteDifferences")
using Faust, FiniteDifferences

process = compile("process = _ * 2;")
function f(x)
    init(process)
    process.inputs = x
    compute(process)
end

x = randn(256, 1)
∇f = jacobian(central_fdm(5, 1), f, zeros(256, 1))[1]