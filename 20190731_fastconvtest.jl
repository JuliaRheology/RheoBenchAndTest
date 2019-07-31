import DSP.conv, RHEOS.convn, BenchmarkTools

# realistic test data sizes for RHEOS workflow
x = collect(0.0:0.1:1000.0)
y = exp.(-x/2.0)
z = [i<500.0 ? i : 500.0 - i for i in x]

# convolve them yeh

@btime conv($z, $y)
@btime convn($z, $y)

