import FunctionWrappers.FunctionWrapper
using BenchmarkTools
using MittagLeffler
using DSP

#############
# Motivation:
# test best possible functionwrappers and tuple implementation
# with realistic cost functions

#########################
# function wrapper set-up

struct DummyModelFW
  params::Vector{Symbol}
  Ga::FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64},Vector{Float64}}}
end

# reduced version of what is in definitions.jl
function DummyModelFW(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    @eval return(DummyModelFW($p,
        ((ta, params) -> begin $unpack_expr; [$G for t in ta]; end) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64},Vector{Float64}}})
    )
end

# simper modulus, SLS_zener.G
exmoresimple = quote kᵧ + kᵦ*exp(-t*kᵦ/η) end
# complicated modulus, FractSLS_Zener.G
exmorecomplex = quote kᵦ*mittleff(a, -(kᵦ/cₐ)*t^a) + kᵧ end

fwstruct_simple = DummyModelFW([:kᵦ, :kᵧ, :η], exmoresimple)
fwstruct_complex = DummyModelFW([:cₐ, :a, :kᵦ, :kᵧ], exmorecomplex)

##############
# tuple set-up

struct DummyModelTuples{T<:Function}
  free_params::Tuple
  G::T
end

# simper modulus, SLS_zener.G
function moresimple(t; kᵦ, kᵧ, η)
  kᵧ + kᵦ*exp(-t*kᵦ/η)
end
# complicated modulus, FractSLS_Zener.G
function morecomplex(t; cₐ, a, kᵦ, kᵧ)
  kᵦ*mittleff(a, -(kᵦ/cₐ)*t^a) + kᵧ
end

params_syms_simple = (:kᵦ, :kᵧ, :η)
tupstruct_simple = DummyModelTuples(params_syms_simple, moresimple)

params_syms_complex = (:cₐ, :a, :kᵦ, :kᵧ)
tupstruct_complex = DummyModelTuples(params_syms_complex, morecomplex)

######################
# cost function set-up

# reduced & modified versions of what is in base.jl

function cost_fw(params_numbers, modulus, time_series, dt, prescribed_dot, measured)

    modulus_numbers = modulus(time_series, params_numbers)

    convolved = conv(modulus_numbers, prescribed_dot)
    convolved = convolved[1:length(time_series)]*dt

    cost = sum((measured - convolved).^2)
    return cost
end

function cost_tuple(params_numbers, params_symbols, modulus, time_series, dt, prescribed_dot, measured)

    kwargz = NamedTuple{params_symbols}(params_numbers)
    modulus_numbers = modulus.(time_series; kwargz...)

    convolved = conv(modulus_numbers, prescribed_dot)
    convolved = convolved[1:length(time_series)]*dt

    cost = sum((measured - convolved).^2)
    return cost
end

###########
# benchmark

dt = 0.1
ta = Float64.(0.0:dt:100) # representative number of samples, 1000
prescribed = 2*ta .+ 1 # representative loading derivative
measured = 5*ta .- 1 # again, exact form doesn't matter

params_numbers_simple = [5.0, 10.0, 10.0]
params_numbers_complex = [5.0, 0.5, 10.0, 10.0]

@btime cost_fw($params_numbers_simple, $fwstruct_simple.Ga, $ta, $dt, $prescribed, $measured)
@btime cost_tuple($params_numbers_simple, $params_syms_simple, $tupstruct_simple.G, $ta, $dt, $prescribed, $measured)
# 113.005 μs (106 allocations: 126.23 KiB)
# 120.539 μs (128 allocations: 126.92 KiB)
# tuples add ~6% overhead for simple modulus

@btime cost_fw($params_numbers_complex, $fwstruct_complex.Ga, $ta, $dt, $prescribed, $measured)
@btime cost_tuple($params_numbers_complex, $params_syms_complex, $tupstruct_complex.G, $ta, $dt, $prescribed, $measured)
# 203.411 μs (106 allocations: 126.23 KiB)
# 210.341 μs (129 allocations: 127.05 KiB)
# named tuples add ~3% overhead complex modulus