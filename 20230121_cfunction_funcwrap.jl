import FunctionWrappers.FunctionWrapper
using BenchmarkTools

function DM0(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    @eval return(
    ((t, params) -> begin $unpack_expr; $G; end)
    |> FunctionWrapper{Float64, Tuple{Float64,Vector{Float64}}})
end

function DM1(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    return(
    (@eval ((t, params) -> begin $unpack_expr; $G; end))
    |> FunctionWrapper{Float64, Tuple{Float64,Vector{Float64}}})
end

function DM2(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    anonf = @eval ((t, params) -> begin $unpack_expr; $G; end)
    anonf |> FunctionWrapper{Float64, Tuple{Float64,Vector{Float64}}}
end

function DM3(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    anonf = @eval ((t, params) -> begin $unpack_expr; $G; end)
    @cfunction(
      $anonf,
      Float64,
      (Float64, Vector{Float64}))
end

sls = quote k0 + k1*exp((-t*k1) / η) end

fw0  = DM0([:k0, :k1, :η], sls)
fw1  = DM1([:k0, :k1, :η], sls)
fw2  = DM2([:k0, :k1, :η], sls)
fw3  = DM3([:k0, :k1, :η], sls)
pfw3 = Base.unsafe_convert(Ptr{Cvoid}, fw3)

t = 1.0
params_numbers = [2.0, 3.0, 5.0]

fw0(t, params_numbers)
fw1(t, params_numbers)
fw2(t, params_numbers)
fw3.f(t, params_numbers)
ccall(pfw3, Float64, (Float64, Vector{Float64}), t, params_numbers)

@btime fw0($t, $params_numbers)
@btime fw1($t, $params_numbers)
@btime fw2($t, $params_numbers)
@btime fw3.f($t, $params_numbers)
@btime ccall($pfw3, Float64, (Float64, Vector{Float64}), $t, $params_numbers)
