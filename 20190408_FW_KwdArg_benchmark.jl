import FunctionWrappers.FunctionWrapper;
using BenchmarkTools;

const RheoFloat = Float64


#
# Comment / uncomment the paramteric types to test their effect
#
struct RheoModel#{GT, GaT}

    params::Tuple

    _G#::GT
    _Ga#::GaT
end





#
#  Helper functions to shape expressions
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

#
#  Create the scalar and vector function wrappers for the moduli.
#
function buildmoduli(G::Expr, paramsymbs::Tuple, Ga=nothing)
	#Ga=quote k.*exp.((-k./η).*ta) end

	if Ga==nothing
		Ge = expr_replace(G,NamedTuple{paramsymbs}((:(p_arr[1]), :(p_arr[2]))) )
		@eval return( (         ((t,p_arr) -> $Ge)                 |> FunctionWrapper{RheoFloat,Tuple{RheoFloat,Vector{RheoFloat}}},
		        ((ta,p_arr) -> [$Ge for t in ta] )  |> FunctionWrapper{Vector{RheoFloat},Tuple{Vector{RheoFloat},Vector{RheoFloat}}} ) )
	else
		Gae = expr_replace(Ga,NamedTuple{paramsymbs}((:(p_arr[1]), :(p_arr[2]))) )
		@eval return( (         ((t,p_arr) -> $Gae)                 |> FunctionWrapper{RheoFloat,Tuple{RheoFloat,Vector{RheoFloat}}},
				((t,p_arr) -> $Gae )  |> FunctionWrapper{Vector{RheoFloat},Tuple{Vector{RheoFloat},Vector{RheoFloat}}} ) )
	end
end


function buildmoduli_fixed(G::Expr, pvals::NamedTuple, Ga=nothing)

	if Ga==nothing
		Ge = expr_replace(G,pvals )
		println(Ge)
		@eval return( (         (t -> $Ge)                 	|> FunctionWrapper{RheoFloat,Tuple{RheoFloat}},
						(ta -> [$Ge for t in ta])  			|> FunctionWrapper{Vector{RheoFloat},Tuple{Vector{RheoFloat}}} ) )
	else
		println("here")
		Gae = expr_replace(Ga,pvals )
		@eval return( (         (t -> $Gae)                 |> FunctionWrapper{RheoFloat,Tuple{RheoFloat}},
						(t -> $Gae)  						|> FunctionWrapper{Vector{RheoFloat},Tuple{Vector{RheoFloat}}} ) )
	end
end
# julia> Meta.parse(":(p_arr[$i])").args[1]
# :(p_arr[1])


const nanexp = quote NaN end

function RheoModel1(;p::Tuple,         G::Expr = nanexp, Ga = nothing       )
    return(RheoModel(p,buildmoduli(G,p,Ga)... ))
end


function RheoModel1_fixed(;p::Tuple,         G::Expr = nanexp , pvals, Ga = nothing          )
    return(RheoModel(p,buildmoduli_fixed(G,pvals,Ga)... ))
end




function RheoModel2(;p::Tuple,   G = nothing, Ga = nothing )
	if Ga==nothing
    	return(RheoModel(p, (t::RheoFloat,p_arr) -> G(t; NamedTuple{p}(p_arr)...), (t_arr::Vector{RheoFloat},p_arr) -> begin nt=NamedTuple{p}(p_arr); [G(t; nt...) for t in t_arr]; end ))
	else
		return(RheoModel(p, (t::RheoFloat,p_arr) -> Ga(t; NamedTuple{p}(p_arr)...), (t::Vector{RheoFloat},p_arr) -> Ga(t; NamedTuple{p}(p_arr)...)  ))
	end
end


function RheoModel2_fixed(;p::Tuple,   G = nothing, pvals , Ga = nothing   )
	if Ga==nothing
    	return(RheoModel(p, t::RheoFloat -> G(t; pvals...), t_arr::Vector{RheoFloat} -> [G(t; pvals...) for t in t_arr] ))
	else
		return(RheoModel(p, t::RheoFloat -> Ga(t; pvals...), t::Vector{RheoFloat}-> Ga(t; pvals...) ))
	end
end


function RheoModel3(;p::Tuple,   G::Function  )
    return(RheoModel(p, G, (t_arr,p_arr) -> [G(t, p_arr) for t in t_arr] ))
end


function RheoModel3_fixed(;p::Tuple,   G::Function, pvals  )
    return(RheoModel(p, t->G(t,pvals), t_arr -> [G(t, pvals) for t in t_arr] ))
end


function RheoModel4(;p::Tuple,   G::Function  )
    return(RheoModel(p, (t,p_arr) -> G([t], p_arr)[1], G ))
end


function RheoModel4_fixed(;p::Tuple,   G::Function  , pvals)
    return(RheoModel(p, t -> G([t], pvals)[1], t_arr->G(t_arr,pvals) ))
end







#
#  Choose between the scalar/vectorized for of the modulus
#

#m1 = RheoModel1(p=(:k, :η), G =quote k*exp((-k/η)*t) end)
m1 = RheoModel1(p=(:k, :η), Ga=quote k.*exp.((-k./η).*t) end)

#m1_fixed = RheoModel1_fixed(p=(:k, :η), G=quote k*exp((-k/η)*t) end, pvals=(k=1.0, η=2.0))
m1_fixed = RheoModel1_fixed(p=(:k, :η), Ga = quote k.*exp.((-k./η).*t) end, pvals=(k=1.0, η=2.0))








function G_Maxwell2(t::RheoFloat; k, η)::RheoFloat
    return( k * exp( (-k/η)*t) )
end

function Ga_Maxwell2(t::Union{RheoFloat,Vector{RheoFloat}}; k, η)::Union{RheoFloat,Vector{RheoFloat}}
    return( k .* exp.( (-k./η).*t) )
end


#
#  Choose between the scalar/vectorized for of the modulus
#
#m2 = RheoModel2( p=(:k, :η), G=G_Maxwell2 )
m2 = RheoModel2( p=(:k, :η), Ga=Ga_Maxwell2 )

#m2_fixed = RheoModel2_fixed( p=(:k, :η), G=G_Maxwell2, pvals=(k=1.0, η=2.0) )
m2_fixed = RheoModel2_fixed( p=(:k, :η), Ga=Ga_Maxwell2, pvals=(k=1.0, η=2.0) )










function G_Maxwell3(t, params)
    return(params[1]*exp((-params[1]/params[2])*t))
end
m3 = RheoModel3( p=(:k, :η), G=G_Maxwell3 )
m3_fixed = RheoModel3_fixed( p=(:k, :η), G=G_Maxwell3, pvals=[1.0,2.0] )


function G_Maxwell4(t_arr, params)
    return(params[1].*exp.((-params[1]/params[2]).*t_arr))
end

m4 = RheoModel4( p=(:k, :η), G=G_Maxwell4 )
m4_fixed = RheoModel4_fixed( p=(:k, :η), G=G_Maxwell4, pvals=[1.0,2.0]  )


t=RheoFloat.(0.0:0.001:1.0);
t0=1.0; k=1.0; η=2.0





function dosomething(m,t::RheoFloat)
	return((m._G(t)))
end

function dosomething(m,t::Vector{RheoFloat})
	return((m._Ga(t)))
end


function dosomething(m,t::Vector{RheoFloat},p)
	return((m._Ga(t,p)))
end


function dosomething(m,t::RheoFloat,p)
	return((m._G(t,p)))
end


################################################################


println("")
println("Tests...")
println("")
println("")



println("Direct function calls")
#@btime k*exp((-k/η)*t0)
#@btime 1.0*exp((-1.0/2.0)*t0)
println("Scalar function with keyword params with set parameters")
@btime G_Maxwell2(t0, k=1.0, η=1.0)
println("Scalar function with keyword params with passed parameters")
@btime G_Maxwell2(t0, k=k, η=η)
println("Scalar function with array params")
@btime G_Maxwell3(t0, [1.,2.])
println("Vector function with array params")
@btime G_Maxwell4([t0], [1.,2.])[1]
println("")

println("")
println("RheoModel function on scalar time values with free params")
println("")

println("Function wrappers")
print("   Direct call: "); @btime m1._G(1.,[1.,2.])
print("   In function: "); @btime dosomething(m1,2.0,[1.0,2.0]);
println("")

println("Scalar function with keyword params")
print("   Direct call: "); @btime m2._G(1.,[1.,2.])
print("   In function: "); @btime dosomething(m2,2.0,[1.0,2.0]);
println("")

println("Scalar function with array params")
print("   Direct call: "); @btime m3._G(1.,[1.,2.])
print("   In function: "); @btime dosomething(m3,2.0,[1.0,2.0]);
println("")

println("Vector function with array params")
print("   Direct call: "); @btime m4._G(1.,[1.,2.])
print("   In function: "); @btime dosomething(m4,2.0,[1.0,2.0]);
println("")





println("")
println("RheoModel function on array time values with free params")
println("")

println("Function wrappers")
print("   Direct call: "); @btime m1._Ga(t,[1.,2.]);
print("   In function: "); @btime dosomething(m1,t,[1.0,2.0]);
println("")

println("Scalar function with keyword params")
print("   Direct call: "); @btime m2._Ga(t,[1.,2.]);
print("   In function: "); @btime dosomething(m2,t,[1.0,2.0]);
println("")

println("Scalar function with array params")
print("   Direct call: "); @btime m3._Ga(t,[1.,2.]);
print("   In function: "); @btime dosomething(m3,t,[1.0,2.0]);
println("")

println("Vector function with array params")
print("   Direct call: "); @btime m4._Ga(t,[1.,2.]);
print("   In function: "); @btime dosomething(m4,t,[1.0,2.0]);
println("")



println("")
println("RheoModel function on scalar time values with fixed params")
println("")

println("Function wrappers")
print("   Direct call: "); @btime m1_fixed._G(1.0);
print("   In function: "); @btime dosomething(m1_fixed,2.0);
println("")
println("Scalar function with keyword params")
print("   Direct call: "); @btime m2_fixed._G(1.0);
print("   In function: "); @btime dosomething(m2_fixed,2.0);
println("")
println("Scalar function with array params")
print("   Direct call: "); @btime m3_fixed._G(1.0);
print("   In function: "); @btime dosomething(m3_fixed,2.0);
println("")
println("Vector function with array params")
print("   Direct call: "); @btime m4_fixed._G(1.0);
print("   In function: "); @btime dosomething(m4_fixed,2.0);
println("")



println("")
println("RheoModel function on array time values with fixed params")
println("")

println("Function wrappers")
print("   Direct call: "); @btime m1_fixed._Ga(t);
print("   In function: "); @btime dosomething(m1_fixed,t);
#println(m1_fixed._Ga(t)[end])
println()

println("Scalar function with keyword params")
print("   Direct call: "); @btime m2_fixed._Ga(t);
print("   In function: "); @btime dosomething(m2_fixed,t);
#println(m2_fixed._Ga(t)[end])
println()

println("Scalar function with array params")
print("   Direct call: "); @btime m3_fixed._Ga(t);
print("   In function: "); @btime dosomething(m3_fixed,t);
#println(m3_fixed._Ga(t)[end])
println()
println("Vector function with array params")
print("   Direct call: "); @btime m4_fixed._Ga(t);
print("   In function: "); @btime dosomething(m4_fixed,t);
#println(m4_fixed._Ga(t)[end])
println()




nothing
