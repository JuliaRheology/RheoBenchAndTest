using BenchmarkTools

# see this section of docs https://docs.julialang.org/en/v1/base/arrays/#Broadcast-and-vectorization-1

function G_single(t::T) where T<:Real

   G = 1. + 2. *exp(-t*(2. /3.)) + 4. *exp(-t*(4. /5.))
   
end

function G_vec(t::Vector{T}) where T<:Real
    
   G = 1. .+ 2. .* exp.(-t .* (2. /3.)) .+ 4. .* exp.(-t .* (4. /5.))

end

function G_arraycomp(t::Vector{T}) where T<:Real
    [G_single(ti) for ti in t]
end

function G_loop(t::Vector{T}) where T<:Real

    out = Array{T}(undef, length(t))

    for (i,ti) in enumerate(t)
        out[i] = G_single(ti)
    end

    out
end

t = collect(0.0:0.1:10000)

println("test vectorised version of function")
@btime G_vec($t)
println("\n")

println("test broadcasting using . notation")
@btime G_single.($t)
println("\n")

println("test broadcast function explicitly (should be the same as . notation)")
@btime broadcast($G_single, $t)
println("\n")

println("test using array comprehension")
@btime G_arraycomp($t)
println("\n")

println("test using for loop")
@btime G_loop($t)
println("\n")

println("Benchmarks complete")
