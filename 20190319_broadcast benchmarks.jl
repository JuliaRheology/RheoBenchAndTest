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

# always worst by far, ignore for now
# println("test vectorised version of function")
# @btime G_vec($t, $params)
# println("\n")

# println("test broadcasting using . notation")
# @btime G_single.($t, $(params,))
# println("\n")

# println("test broadcast function explicitly (should be the same as . notation)")
# @btime broadcast($G_single, $t, $(params,))
# println("\n")

# println("test using array comprehension")
# @btime [G_single(ti, $params) for ti in $t]
# println("\n")

println("test using map")
@btime map(G_single, t, (params,))
println("\n")

# println("test using for loop")
# @btime G_loop($t, $params)
# println("\n")

println("Benchmarks complete")