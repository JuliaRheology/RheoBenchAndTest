using BenchmarkTools
#
#	tool to replace params with values in an expression
#

expr_replace!(ex, s, v) = ex
expr_replace!(ex::Symbol, s, v) = s == ex ? v : ex

function expr_replace!(ex::Expr, s, v)
    for i=1:length(ex.args)
        ex.args[i] = expr_replace!(ex.args[i], s, v)
    end
    return ex
end

expr_replace(ex, s, v) = expr_replace!(copy(ex), s, v)

function expr_replace(ex, nt)
    e = copy(ex)
    k=keys(nt)
    v=values(nt)
    for i in 1:length(nt)
        expr_replace!(e, k[i], v[i])
    end
    return e
end





# see this section of docs https://docs.julialang.org/en/v1/base/arrays/#Broadcast-and-vectorization-1



t = collect(0.0:0.1:10000)
params = [1.0, 1.0, 1.0, 1.0, 1.0]
nt=(G₀=1., G₁=1., η₁=1., G₂=1., η₂=1.)



#
#	Vectorised function
#

function G_vec(t::Vector{T}, params::Vector{T}) where T<:Real
   G₀, G₁, η₁, G₂, η₂ = params
   G = G₀ .+ G₁*exp.(-t*G₁/η₁) .+ G₂*exp.(-t*G₂/η₂)
end

println("test vectorised version of function")
@btime G_vec($t, $params)
println("\n")





#
#	Broadcasting functions
#

function G_single(t::T, params::Array{T,1}) where T<:Real
   G₀, G₁, η₁, G₂, η₂ = params
   G = G₀ + G₁*exp(-t*G₁/η₁) + G₂*exp(-t*G₂/η₂)
end

println("test broadcasting using . notation")
@btime G_single.($t, $(params,))
println("\n")

println("test broadcast function explicitly (should be the same as . notation)")
@btime broadcast($G_single, $t, $(params,))
println("\n")






#
#	Array comprehension
#

function G_arraycomp(t::Vector{T}, params::Vector{T}) where T<:Real
    [G_single(ti, params) for ti in t]
end


println("test using array comprehension")
@btime G_arraycomp($t, $params)
println("\n")



#
#	parameter substitution
#

e = :( G₀ + G₁*exp(-t*G₁/η₁) + G₂*exp(-t*G₂/η₂) )

function G_arrayexp(ta::Vector{T}, nt) where T<:Real
	e2 = expr_replace(e, nt)
    @eval f(t::T) where T<:Real = begin  $e2   end
    #@eval [f(t) for t in $ta]
    @eval broadcast(f,$ta)
end

println("test using local function from expression with parameter replacement")
@btime G_arrayexp($t, $nt)
println("\n")



println("test using array comprehension in external function from expression with parameter replacement")

function paramsubst(e,nt)
	e2 = expr_replace(e, nt)
    @eval f(t::T) where T<:Real = begin  $e2   end
    @eval g(ta::Vector{T}) where T<:Real = begin [f(t) for t in ta] end
    #g = ta -> [f(t) for t in ta] 
    return g
end

@btime paramsubst(e,nt)
g=paramsubst(e,nt)

@btime g($t)
println("\n")


println("test using array broadcast in external function from expression with parameter replacement")
    @eval g2(ta::Vector{T}) where T<:Real = begin broadcast(f, ta) end
    #g2 = t -> broadcast(f, t)
    
@btime g2($t)
println("\n")





println("test using array comprehension with external lambda function")
    gl = ta -> G_arraycomp(  ta, params)
        
@btime gl($t)
println("\n")

println("test using array braodcast with external lambda function")
    gl2 = ta -> broadcast(G_single, ta, (params,))
        
@btime gl2($t)
println("\n")








#
#	for loop
#

function G_loop(t::Vector{T}, params::Vector{T}) where T<:Real

    out = Array{T}(undef, length(t))

    for (i,ti) in enumerate(t)
        out[i] = G_single(ti, params)
    end

    out
end

    
println("test using for loop")
@btime G_loop($t, $params)
println("\n")

println("Benchmarks complete")
