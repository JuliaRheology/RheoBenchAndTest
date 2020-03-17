using Revise
using FunctionWrappers: FunctionWrapper
using BenchmarkTools

#=
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
Expressions, with function wrappers
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
=#
struct RheoModelClass

    name::String
    params::Vector{Symbol}

    G::FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}}
    Ga::FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}}
    J::FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}}
    Ja::FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}}
    Gp::FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}}
    Gpa::FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}}
    Gpp::FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}}
    Gppa::FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}}

    constraint::FunctionWrapper{Bool,Tuple{Vector{Float64}}}

    info::String
    expressions::NamedTuple

end

function RheoModelClass(;name::String="Custom model",
                         p::Array{Symbol}=[],
                         G::Expr = quote nothing end,
                         J::Expr = quote nothing end,
                         Gp::Expr = quote nothing end,
                         Gpp::Expr = quote nothing end,
                         constraint::Expr = quote true end,
                         info=name)

    # Expression to unpack parameter array into suitably names variables in the moduli expressions
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    expressions = (G=G,J=J,Gp=Gp,Gpp=Gpp,constraint=constraint)

    @eval return(RheoModelClass($name, $p,
        ((t,params) -> begin $unpack_expr; $G; end)                 |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ta,params) -> begin $unpack_expr; [$G for t in ta]; end)  |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((t,params) -> begin $unpack_expr; $J; end)                 |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ta,params) -> begin $unpack_expr; [$J for t in ta]; end)  |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((ω,params) -> begin $unpack_expr; $Gp; end)                |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ωa,params) -> begin $unpack_expr; [$Gp for ω in ωa]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((ω,params) -> begin $unpack_expr; $Gpp; end)               |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ωa,params) -> begin $unpack_expr; [$Gpp for ω in ωa]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        (params -> begin $unpack_expr; $constraint; end)            |> FunctionWrapper{Bool,Tuple{Vector{Float64}}},
        $info, $expressions) )
end

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

function model_parameters(nt::NamedTuple, params::Vector{Symbol}, err_string::String)
    # check that every parameter in m exists in the named tuple nt
    @assert all(i->i in keys(nt),params) "Missing parameter(s) in " * err_string
    # check that no extra parameters have been provided
    @assert length(params) == length(nt) "Mismatch number of model parameters and parameters provided in " * err_string

    p = map(i->Float64(nt[i]), params)
end

function freeze_params(m::RheoModelClass, nt0::NamedTuple)

    # check that every parameter in m exists in the named tuple nt
    @assert all( i-> i in m.params,keys(nt0)) "A parameter to freeze is not involved in the model"
    # convert values format for consistency
    nt=NamedTuple{keys(nt0)}([Float64(i) for i in nt0])

    # create array of remaining variables
    p = filter(s -> !(s in keys(nt)),m.params)

    name="$(m.name) with set parameters: $nt"
    info = m.info

    # Expression to unpack parameter array into suitably names variables in the moduli expressions
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))

    # This section creates moduli expressions with material parameters
    # replaced by specific values.

    G = expr_replace(m.expressions.G, nt)
    J = expr_replace(m.expressions.J, nt)
    Gp = expr_replace(m.expressions.Gp, nt)
    Gpp = expr_replace(m.expressions.Gpp, nt)
    constraint = expr_replace(m.expressions.constraint, nt)

    expressions=NamedTuple{(:G,:J,:Gp,:Gpp)}( ( G, J, Gp, Gpp ) )


    @eval return( RheoModelClass($name, $p,
        ((t,params) -> begin $unpack_expr; $G; end) |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ta,params) -> begin $unpack_expr; [$G for t in ta]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((t,params) -> begin $unpack_expr; $J; end) |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ta,params) -> begin $unpack_expr; [$J for t in ta]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((ω,params) -> begin $unpack_expr; $Gp; end) |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ωa,params) -> begin $unpack_expr; [$Gp for ω in ωa]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((ω,params) -> begin $unpack_expr; $Gpp; end) |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ωa,params) -> begin $unpack_expr; [$Gpp for ω in ωa]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        (params -> begin $unpack_expr; $constraint; end) |> FunctionWrapper{Bool,Tuple{Vector{Float64}}},
        $info, $expressions)   )
end

SLS_exp_fw = RheoModelClass(
          # Model name
          name="SLS",
          # Model parameters,
          p = [ :η, :kᵦ, :kᵧ],
          # Relaxation modulus
          G = quote
                 kᵧ + kᵦ*exp(-t*kᵦ/η)
              end,
          # Creep modulus
          J = quote
                  c₀ = 1/kᵧ
                  c₁ = kᵦ/(kᵧ*(kᵧ + kᵦ))
                  τᵣ = η*(kᵧ + kᵦ)/(kᵧ*kᵦ)
                  c₀ - c₁*exp(-t/τᵣ)
              end,
          # Storage modulus
          Gp = quote
                  τ = η/kᵦ
                  denominator = 1 + τ^2*ω^2
                  numerator = ω^2*τ^2*kᵦ
                  numerator/denominator + kᵧ
               end,
         # Loss modulus
          Gpp = quote
                  τ = η/kᵦ
                  denominator = 1 + τ^2*ω^2
                  numerator = ω*τ*kᵦ
                  numerator/denominator
                end,
          # Network
          info= " "
          )

#=
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
Expressions, no function wrappers
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
=#

struct RheoModelClassNOFW

    name::String
    params::Vector{Symbol}

    G::Function
    Ga::Function
    J::Function
    Ja::Function
    Gp::Function
    Gpa::Function
    Gpp::Function
    Gppa::Function

    constraint::Function

    info::String
    expressions::NamedTuple

end

function RheoModelClassNOFW(;name::String="Custom model",
                         p::Array{Symbol}=[],
                         G::Expr = quote nothing end,
                         J::Expr = quote nothing end,
                         Gp::Expr = quote nothing end,
                         Gpp::Expr = quote nothing end,
                         constraint::Expr = quote true end,
                         info=name)

    # Expression to unpack parameter array into suitably names variables in the moduli expressions
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    expressions = (G=G,J=J,Gp=Gp,Gpp=Gpp,constraint=constraint)

    @eval return(RheoModelClassNOFW($name, $p,
        ((t,params) -> begin $unpack_expr; $G; end),
        ((ta,params) -> begin $unpack_expr; [$G for t in ta]; end),
        ((t,params) -> begin $unpack_expr; $J; end),
        ((ta,params) -> begin $unpack_expr; [$J for t in ta]; end),
        ((ω,params) -> begin $unpack_expr; $Gp; end),
        ((ωa,params) -> begin $unpack_expr; [$Gp for ω in ωa]; end),
        ((ω,params) -> begin $unpack_expr; $Gpp; end),
        ((ωa,params) -> begin $unpack_expr; [$Gpp for ω in ωa]; end),
        (params -> begin $unpack_expr; $constraint; end),
        $info, $expressions) )
end

function freeze_paramsNOFW(m::RheoModelClassNOFW, nt0::NamedTuple)
    # check that every parameter in m exists in the named tuple nt
    @assert all( i-> i in m.params,keys(nt0)) "A parameter to freeze is not involved in the model"
    # convert values format for consistency
    nt=NamedTuple{keys(nt0)}([Float64(i) for i in nt0])

    # create array of remaining variables
    p = filter(s -> !(s in keys(nt)),m.params)

    name="$(m.name) with set parameters: $nt"
    info = m.info

    # Expression to unpack parameter array into suitably names variables in the moduli expressions
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))

    # This section creates moduli expressions with material parameters
    # replaced by specific values.
    G = expr_replace(m.expressions.G, nt)
    J = expr_replace(m.expressions.J, nt)
    Gp = expr_replace(m.expressions.Gp, nt)
    Gpp = expr_replace(m.expressions.Gpp, nt)
    constraint = expr_replace(m.expressions.constraint, nt)

    expressions=NamedTuple{(:G,:J,:Gp,:Gpp)}( ( G, J, Gp, Gpp ) )


    @eval return( RheoModelClass($name, $p,
        ((t,params) -> begin $unpack_expr; $G; end),
        ((ta,params) -> begin $unpack_expr; [$G for t in ta]; end),
        ((t,params) -> begin $unpack_expr; $J; end),
        ((ta,params) -> begin $unpack_expr; [$J for t in ta]; end),
        ((ω,params) -> begin $unpack_expr; $Gp; end),
        ((ωa,params) -> begin $unpack_expr; [$Gp for ω in ωa]; end),
        ((ω,params) -> begin $unpack_expr; $Gpp; end),
        ((ωa,params) -> begin $unpack_expr; [$Gpp for ω in ωa]; end),
        (params -> begin $unpack_expr; $constraint; end),
        $info,
        $expressions))
end

SLS_exp_NOFW = RheoModelClassNOFW(
          # Model name
          name="SLS",
          # Model parameters,
          p = [ :η, :kᵦ, :kᵧ],
          # Relaxation modulus
          G = quote
                 kᵧ + kᵦ*exp(-t*kᵦ/η)
              end,
          # Creep modulus
          J = quote
                  c₀ = 1/kᵧ
                  c₁ = kᵦ/(kᵧ*(kᵧ + kᵦ))
                  τᵣ = η*(kᵧ + kᵦ)/(kᵧ*kᵦ)
                  c₀ - c₁*exp(-t/τᵣ)
              end,
          # Storage modulus
          Gp = quote
                  τ = η/kᵦ
                  denominator = 1 + τ^2*ω^2
                  numerator = ω^2*τ^2*kᵦ
                  numerator/denominator + kᵧ
               end,
         # Loss modulus
          Gpp = quote
                  τ = η/kᵦ
                  denominator = 1 + τ^2*ω^2
                  numerator = ω*τ*kᵦ
                  numerator/denominator
                end,
          # Network
          info= " "
          )

#=
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
Functions, no freezing capability
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
=#
struct RheoModelClassNOFWNOEXP

    name::String
    params::Vector{Symbol}

    G::Function
    Ga::Function
    J::Function
    Ja::Function
    Gp::Function
    Gpa::Function
    Gpp::Function
    Gppa::Function

    constraint::Function

    info::String
    expressions::NamedTuple

end

function RheoModelClassNOFWNOEXP(;name::String="Custom model",
                         p::Array{Symbol}=[],
                         G::Function = (t, params) -> nothing,
                         J::Function = (t, params) -> nothing,
                         Gp::Function = (t, params) -> nothing,
                         Gpp::Function = (t, params) -> nothing,
                         constraint::Function = (params) -> true,
                         info=name)

    return(RheoModelClassNOFWNOEXP(name, p,
        G,
        (ta, params) -> G.(ta, (params,)),
        J,
        (ta, params) -> J.(ta, (params,)),
        Gp,
        (ωa, params) -> Gp.(ωa, (params,)),
        Gpp,
        (ωa, params) -> Gpp.(ωa, (params,)),
        constraint,
        info, 
        (DefinedAsFunctions = 1,)))
end

function SLSFunkNOFWNOEXPG(t, params)
    η, kᵦ, kᵧ = params
    kᵧ + kᵦ*exp(-t*kᵦ/η)
end

function SLSFunkNOFWNOEXPJ(t, params)
    η, kᵦ, kᵧ = params
    c₀ = 1/kᵧ
    c₁ = kᵦ/(kᵧ*(kᵧ + kᵦ))
    τᵣ = η*(kᵧ + kᵦ)/(kᵧ*kᵦ)
    c₀ - c₁*exp(-t/τᵣ)
end

function SLSFunkNOFWNOEXPGp(ω, params)
    η, kᵦ, kᵧ = params
    τ = η/kᵦ
    denominator = 1 + τ^2*ω^2
    numerator = ω^2*τ^2*kᵦ
    numerator/denominator + kᵧ
end

function SLSFunkNOFWNOEXPGpp(ω, params)
    η, kᵦ, kᵧ = params
    τ = η/kᵦ
    denominator = 1 + τ^2*ω^2
    numerator = ω*τ*kᵦ
    numerator/denominator
end

SLS_exp_NOFWNOEXP = RheoModelClassNOFWNOEXP(
          # Model name
          name="SLS",
          # Model parameters,
          p = [ :η, :kᵦ, :kᵧ],
          # Relaxation modulus
          G = SLSFunkNOFWNOEXPG,
          # Creep modulus
          J = SLSFunkNOFWNOEXPJ,
          # Storage modulus
          Gp = SLSFunkNOFWNOEXPGp,
         # Loss modulus
          Gpp = SLSFunkNOFWNOEXPGpp,
          # Network
          info= " "
          )

#=
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
Parametrised seems would be messy due to all the differently parameterised FunctionWrappers, trying generic
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
=#
struct RheoModelClassGENERIC

    name::String
    params::Vector{Symbol}

    G
    Ga
    J
    Ja
    Gp
    Gpa
    Gpp
    Gppa

    constraint

    info::String
    expressions::NamedTuple

end

function RheoModelClassGENERICfromfunk(;name::String="Custom model",
                         p::Array{Symbol}=[],
                         G::Function = (t, params) -> nothing,
                         J::Function = (t, params) -> nothing,
                         Gp::Function = (t, params) -> nothing,
                         Gpp::Function = (t, params) -> nothing,
                         constraint::Function = (params) -> true,
                         info=name)

    return(RheoModelClassGENERIC(name, p,
        G,
        (ta, params) -> G.(ta, (params,)),
        J,
        (ta, params) -> J.(ta, (params,)),
        Gp,
        (ωa, params) -> Gp.(ωa, (params,)),
        Gpp,
        (ωa, params) -> Gpp.(ωa, (params,)),
        constraint,
        info, 
        (DefinedAsFunctions = 1,)))
end

function RheoModelClassGENERICfromexp(;name::String="Custom model",
                         p::Array{Symbol}=[],
                         G::Expr = quote nothing end,
                         J::Expr = quote nothing end,
                         Gp::Expr = quote nothing end,
                         Gpp::Expr = quote nothing end,
                         constraint::Expr = quote true end,
                         info=name)

    # Expression to unpack parameter array into suitably names variables in the moduli expressions
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    expressions = (G=G,J=J,Gp=Gp,Gpp=Gpp,constraint=constraint)

    @eval return(RheoModelClassGENERIC($name, $p,
        ((t,params) -> begin $unpack_expr; $G; end)                 |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ta,params) -> begin $unpack_expr; [$G for t in ta]; end)  |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((t,params) -> begin $unpack_expr; $J; end)                 |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ta,params) -> begin $unpack_expr; [$J for t in ta]; end)  |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((ω,params) -> begin $unpack_expr; $Gp; end)                |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ωa,params) -> begin $unpack_expr; [$Gp for ω in ωa]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        ((ω,params) -> begin $unpack_expr; $Gpp; end)               |> FunctionWrapper{Float64,Tuple{Float64,Vector{Float64}}},
        ((ωa,params) -> begin $unpack_expr; [$Gpp for ω in ωa]; end) |> FunctionWrapper{Vector{Float64},Tuple{Vector{Float64},Vector{Float64}}},
        (params -> begin $unpack_expr; $constraint; end)            |> FunctionWrapper{Bool,Tuple{Vector{Float64}}},
        $info, $expressions) )
end

function SLSFunkGENERICG(t, params)
    η, kᵦ, kᵧ = params
    kᵧ + kᵦ*exp(-t*kᵦ/η)
end

function SLSFunkGENERICJ(t, params)
    η, kᵦ, kᵧ = params
    c₀ = 1/kᵧ
    c₁ = kᵦ/(kᵧ*(kᵧ + kᵦ))
    τᵣ = η*(kᵧ + kᵦ)/(kᵧ*kᵦ)
    c₀ - c₁*exp(-t/τᵣ)
end

function SLSFunkGENERICGp(ω, params)
    η, kᵦ, kᵧ = params
    τ = η/kᵦ
    denominator = 1 + τ^2*ω^2
    numerator = ω^2*τ^2*kᵦ
    numerator/denominator + kᵧ
end

function SLSFunkGENERICGpp(ω, params)
    η, kᵦ, kᵧ = params
    τ = η/kᵦ
    denominator = 1 + τ^2*ω^2
    numerator = ω*τ*kᵦ
    numerator/denominator
end

SLS_exp_GENERIC = RheoModelClassGENERICfromfunk(
          # Model name
          name="SLS",
          # Model parameters,
          p = [ :η, :kᵦ, :kᵧ],
          # Relaxation modulus
          G = SLSFunkNOFWNOEXPG,
          # Creep modulus
          J = SLSFunkNOFWNOEXPJ,
          # Storage modulus
          Gp = SLSFunkNOFWNOEXPGp,
         # Loss modulus
          Gpp = SLSFunkNOFWNOEXPGpp,
          # Network
          info= " "
          )

SLS_exp_GENERIC_fw = RheoModelClassGENERICfromexp(
          # Model name
          name="SLS",
          # Model parameters,
          p = [ :η, :kᵦ, :kᵧ],
          # Relaxation modulus
          G = quote
                 kᵧ + kᵦ*exp(-t*kᵦ/η)
              end,
          # Creep modulus
          J = quote
                  c₀ = 1/kᵧ
                  c₁ = kᵦ/(kᵧ*(kᵧ + kᵦ))
                  τᵣ = η*(kᵧ + kᵦ)/(kᵧ*kᵦ)
                  c₀ - c₁*exp(-t/τᵣ)
              end,
          # Storage modulus
          Gp = quote
                  τ = η/kᵦ
                  denominator = 1 + τ^2*ω^2
                  numerator = ω^2*τ^2*kᵦ
                  numerator/denominator + kᵧ
               end,
         # Loss modulus
          Gpp = quote
                  τ = η/kᵦ
                  denominator = 1 + τ^2*ω^2
                  numerator = ω*τ*kᵦ
                  numerator/denominator
                end,
          # Network
          info= " "
          )

#=
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
Defined as functions, named tuple arguements with wrapper function for optimisation
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
=#
struct RheoModelFunkNT
    name::String
    free_params::Tuple
    fixed_params::NamedTuple
    G::Function
    J::Function
    Gp::Function
    Gpp::Function
end

function RheoModelFunkNT(;name::String="Custom model", free::Tuple=(), fixed::NamedTuple=NamedTuple{}(), G, J, Gp, Gpp)
   return(RheoModelFunkNT(name, 
                         free,
                         fixed,
                         G,
                         J,
                         Gp,
                         Gpp))
end

function SLSFunk1G(t; η, kᵦ, kᵧ)
    kᵧ + kᵦ*exp(-t*kᵦ/η)
end

function SLSFunk1J(t; η, kᵦ, kᵧ)
    c₀ = 1/kᵧ
    c₁ = kᵦ/(kᵧ*(kᵧ + kᵦ))
    τᵣ = η*(kᵧ + kᵦ)/(kᵧ*kᵦ)
    c₀ - c₁*exp(-t/τᵣ)
end

function SLSFunk1Gp(ω; η, kᵦ, kᵧ)
    τ = η/kᵦ
    denominator = 1 + τ^2*ω^2
    numerator = ω^2*τ^2*kᵦ
    numerator/denominator + kᵧ
end

function SLSFunk1Gpp(ω; η, kᵦ, kᵧ)
    τ = η/kᵦ
    denominator = 1 + τ^2*ω^2
    numerator = ω*τ*kᵦ
    numerator/denominator
end

# function freeze_params(orig::RheoModelFunkNT, nt0::NamedTuple)

#     return RheoModelFunkNT(orig.name, , , orig.G, orig.J, orig.Gp, orig.Gpp)
# end

function moduluswitharrayinput(t_or_ω::Vector{Float64}, numparams::Vector{Float64}, modulusfunc::Function, freeparams::Tuple, fixedargs::NamedTuple)
    freeargs = NamedTuple{freeparams}(numparams)
    args = merge(freeargs, fixedargs)

    modulusfunc.(t_or_ω; args...)
end

SLSFunk = RheoModelFunkNT(
          name="SLSFunk",
          free = (:η, :kᵦ, :kᵧ),
          G = SLSFunk1G,
          J = SLSFunk1J,
          Gp = SLSFunk1Gp,
          Gpp = SLSFunk1Gpp)

#=
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
Benchmarking
=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~=~-~#
=#
test_time = collect(0.0:0.1:1000.0);
test_params = [1.0, 1.0, 1.0];
test_params_tuple = (η=1.0, kᵦ=1.0, kᵧ=1.0)
test_params_symbols = (:η, :kᵦ, :kᵧ)
no_fixed = NamedTuple{}()

# TO BE REMOVED ONCE FIXING FUNCTION WRITTEN
test_p_fixed = [1.0, 1.0];
test_fixed_fixed = (kᵦ=1.0,)
test_fixed_free = (:η, :kᵧ)

println("Expressions and Function wrappers")
@btime SLS_exp_fw.Ga($test_time, $test_params);

println("\nExpressions and Functions")
@btime SLS_exp_NOFW.Ga($test_time, $test_params);

println("\nJust functions predefined (no freezing capability)")
@btime SLS_exp_NOFWNOEXP.Ga($test_time, $test_params);

println("\nGeneric struct that can accept functions or functionwrappers (functions tested first then FW)")
@btime SLS_exp_GENERIC.Ga($test_time, $test_params);
@btime SLS_exp_GENERIC_fw.Ga($test_time, $test_params);
println("note another option is to have two different structs and all functions accept both... They interact with RHEOS in the same way so should be fine...")

println("\nNamed tuple approach, testing function directly...")
@btime SLSFunk.G.($test_time; $test_params_tuple...)

println("\nName tuple approach with calling wrapper function that would be used from optimiser")
@btime moduluswitharrayinput($test_time, $test_params, $SLSFunk.G, $test_params_symbols, $no_fixed)

println("\nSame as above but with one parameter 'fixed'")
@btime moduluswitharrayinput($test_time, $test_p_fixed, $SLSFunk.G, $test_fixed_free, $test_fixed_fixed)

println("\n===============\n[Test Complete]\n===============")


# note there is also one more option similar to named tuples but with an array wrapper function like seen on Julia discourse