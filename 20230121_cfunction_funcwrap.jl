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

function DM_expectfail(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    anonf = @eval ((t, params) -> begin $unpack_expr; $G; end)
    anonf
end

function thang()
  sls_l  = quote k0 + k1*exp((-t*k1) / η) end

  #! works ok
  fw3_l  = DM3([:k0, :k1, :η], sls_l)
  pfw3_l = Base.unsafe_convert(Ptr{Cvoid}, fw3)
  ccall(pfw3_l, Float64, (Float64, Vector{Float64}), t, params_numbers)

  #! fails as expected
  #fw3_l  = DM_expectfail([:k0, :k1, :η], sls_l)
  #fw3_l(t, params_numbers)

  #! try get same interface as funcwrapper
  #! fails as well with world age
  #ffw3_l = fw3_l.f
  #ffw3_l(t, params_numbers)

  #! try via wrapper
  ffw3 = (t, params_numbers) -> ccall(pfw3_l, Float64, (Float64, Vector{Float64}), t, params_numbers)
end

wrapped = thang()

@btime wrapped($t, $params_numbers)

# looks like we would need the `unsafe_convert` and a wrapper
# to get this to work with a similar interface to that currently
# used

#= Results
  262.908 ns (2 allocations: 32 bytes)
  263.174 ns (2 allocations: 32 bytes)
  263.205 ns (2 allocations: 32 bytes)
  100.000 ns (2 allocations: 32 bytes)
  58.359 ns (2 allocations: 32 bytes)
  99.367 ns (4 allocations: 64 bytes)
=#
