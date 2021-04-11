import FunctionWrappers.FunctionWrapper
using BenchmarkTools
using MittagLeffler
using DSP

#############
# Motivation:
# test best possible functionwrappers and tuple implementation
# with realistic cost functions
# WITH SIMD ENCOURAGEMENT

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
function moresimple(tarr; kᵦ, kᵧ, η)
  @. kᵧ + kᵦ*exp(-tarr*kᵦ/η)
end
# complicated modulus, FractSLS_Zener.G
function morecomplex(tarr; cₐ, a, kᵦ, kᵧ)
  @. kᵦ*mittleff(a, -(kᵦ/cₐ)*tarr^a) + kᵧ
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

    convolved = conv(modulus(time_series; kwargz...), prescribed_dot)

    return sum( (measured .- convolved[1:length(time_series)].*dt).^2 )
end

###########
# benchmark

dt = 0.05
ta = Float64.(0.0:dt:50) # representative number of samples, 1000
prescribed = 2*ta .+ 1 # representative loading derivative
measured = 5*ta .- 1 # again, exact form doesn't matter

params_numbers_simple = [5.0, 10.0, 10.0]
params_numbers_complex = [5.0, 0.25, 10.0, 10.0]

@btime cost_fw($params_numbers_simple, $fwstruct_simple.Ga, $ta, $dt, $prescribed, $measured) 
# 114.211 μs (106 allocations: 126.23 KiB)
@btime cost_tuple($params_numbers_simple, $params_syms_simple, $tupstruct_simple.G, $ta, $dt, $prescribed, $measured)
# 118.430 μs (125 allocations: 110.86 KiB)
@btime cost_fw($params_numbers_complex, $fwstruct_complex.Ga, $ta, $dt, $prescribed, $measured)
# 13.484 ms (111707 allocations: 2.63 MiB)
@btime cost_tuple($params_numbers_complex, $params_syms_complex, $tupstruct_complex.G, $ta, $dt, $prescribed, $measured)
# 13.288 ms (111727 allocations: 2.61 MiB)

# tuple approach was 3.7% slower for simple modulus, 1.4% faster for mittleff. No reason why that should be the case as tuple conversion
# certainly adds overhead. Demonstrates that difference is certainly negligible for more complex moduli though.

# simd encouraged tuple function yields negligible difference on intel i7-4770, even with -O3 flag
# parameters used in mittleff function have a much larger impact