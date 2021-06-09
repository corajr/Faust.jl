using Faust
using Test

@testset "Faust.jl" begin
    p0 = init(compile("process = 0, 0;"))
    p_ = init(compile("process = _, _;"))
    posc = init(compile("""
    import("stdfaust.lib");
    freq = hslider("freq", 110, 110, 880, 10);
    t = ba.time : ba.samp2sec;
    process = cos(2*ma.PI*freq*t);
    """))

    p_.inputs = rand(256, 2)

    @test compute(p0) == zeros(256, 2)
    @test compute(p_) == p_.inputs

    t = (0:255) / 22050
    t2 = (256:511) / 22050
    @test compute(posc) ≈ cos.(2*pi*110*t) atol=0.001
    unsafe_store!(posc.ui.paths["/score/freq"], 220.0)
    @test compute(posc) ≈ cos.(2*pi*220*t2) atol=0.001
end

@testset "llvm-c-dsp.jl" begin
    argv = ["-vec"]
    code = """
    import("stdfaust.lib");
    f0 = hslider("[foo:bar]f0", 110, 110, 880, 1);
    n = 2;
    inst = par(i, n, os.oscs(f0 * (n+i) / n)) :> /(n);
    process = inst, inst;
    """
    factory = createCDSPFactoryFromString("score", code, argv, "", -1)
    dsp = createCDSPInstance(factory)
    @test getNumInputsCDSPInstance(dsp) == 0
    @test getNumOutputsCDSPInstance(dsp) == 2

    sr = 22050
    initCDSPInstance(dsp, sr)
    out = computeCDSPInstance(dsp, 256)
    @test out[:, 1] == out[:, 2]

    deleteCDSPInstance(dsp)
    deleteCDSPFactory(factory)        
end
