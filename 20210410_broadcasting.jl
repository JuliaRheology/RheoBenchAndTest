# VERY SIMILAR TO 20190319_broadcastbenchmarks.jl
# EXTENDED FOR BEST CASE VS FUNCTION WRAPPERS

using BenchmarkTools

# see this section of docs https://docs.julialang.org/en/v1/base/arrays/#Broadcast-and-vectorization-1

function G_single(t::T, params::Vector{T}) where T<:Real

   G₀, G₁, η₁, G₂, η₂ = params

   G = G₀ + G₁*exp(-t*G₁/η₁) + G₂*exp(-t*G₂/η₂)

end

function G_vec(t::Vector{T}, params::Vector{T}) where T<:Real
    
   G₀, G₁, η₁, G₂, η₂ = params

   G = G₀ .+ G₁*exp.(-t*G₁/η₁) .+ G₂*exp.(-t*G₂/η₂)

end

function G_loop(t::Vector{T}, params::Vector{T}) where T<:Real

    out = Array{T}(undef, length(t))

    @inbounds for (i,ti) in enumerate(t)
        out[i] = G_single(ti, params)
    end

    out
end

t = collect(0.0:0.1:10000)
params = [1.0, 1.0, 1.0, 1.0, 1.0]

@btime G_single.($t, $(params,)) # 2.195 ms (2 allocations: 781.39 KiB)
@btime broadcast($G_single, $t, $(params,)) # 2.016 ms (2 allocations: 781.39 KiB)
@btime [G_single(ti, $params) for ti in $t] # 1.996 ms (2 allocations: 781.39 KiB)
@btime G_loop($t, $params) # 1.967 ms (2 allocations: 781.39 KiB)