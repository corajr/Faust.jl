# import Pkg; Pkg.add("FiniteDifferences")
using Faust, FiniteDifferences

process = compile("process = _;")
function f(x)
    init(process, block_size=size(x, 1))
    process.inputs = x
    compute(process)
end

x = randn(256, 1)
∇f = jacobian(central_fdm(5, 1), f, x)[1]