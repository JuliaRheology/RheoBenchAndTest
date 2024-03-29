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

# This one leads to world age problems
function DM4(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    anonf = @eval ((t, params) -> begin $unpack_expr; $G; end)
    @cfunction(
      $anonf,
      Float64,
      (Float64, Vector{Float64})).f
end

# Seems to avoid world age problem?
function DM5(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    anonf = @eval ((t, params) -> begin $unpack_expr; $G; end)
    (t, params_numbers) -> ccall( @cfunction(  $anonf,  Float64, (Float64, Vector{Float64})).ptr , Float64, (Float64, Vector{Float64}), t, params_numbers)
end



sls = quote k0 + k1*exp((-t*k1) / η) end

fw0  = DM0([:k0, :k1, :η], sls)
fw1  = DM1([:k0, :k1, :η], sls)
fw2  = DM2([:k0, :k1, :η], sls)
fw3  = DM3([:k0, :k1, :η], sls)
pfw3 = Base.unsafe_convert(Ptr{Cvoid}, fw3)
fw4  = DM4([:k0, :k1, :η], sls)
fw5  = DM5([:k0, :k1, :η], sls)

t = 1.0
params_numbers = [2.0, 3.0, 5.0]

fw0(t, params_numbers)
fw1(t, params_numbers)
fw2(t, params_numbers)
fw3.f(t, params_numbers)
ccall(pfw3, Float64, (Float64, Vector{Float64}), t, params_numbers)
fw4(t, params_numbers)
fw5(t, params_numbers)

@btime fw0($t, $params_numbers)
@btime fw1($t, $params_numbers)
@btime fw2($t, $params_numbers)
@btime fw3.f($t, $params_numbers)
@btime ccall($pfw3, Float64, (Float64, Vector{Float64}), $t, $params_numbers)
@btime fw4($t, $params_numbers)
@btime fw5($t, $params_numbers)


# World age issue test
# Works with DM0, DM1, DM2 (i.e. functionwrappers) and DM5
function f()
         sls_l  = quote k0 + k1*exp((-t*k1) / η) end
         fw  = DM5([:k0, :k1, :η], sls_l)
         fw(t,params_numbers)
       end

f()



# Tests on time arrays


function DM1v(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    return(
    (@eval ((t, params) -> begin $unpack_expr; @. $G; end))
    |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64},Vector{Float64}}})
end

function DM5v(p::Array{Symbol}, G::Expr)
    unpack_expr = Meta.parse(string(join(string.(p), ","), ",=params"))
    anonf = @eval ((t, params) -> begin $unpack_expr; @. $G; end)
    (t, params_numbers) -> ccall( @cfunction(  $anonf,  Vector{Float64}, (Vector{Float64}, Vector{Float64})).ptr , Vector{Float64}, (Vector{Float64}, Vector{Float64}), t, params_numbers)
end

ta=Array(0:0.1:10)
fw1v  = DM1v([:k0, :k1, :η], sls)
fw5v  = DM5v([:k0, :k1, :η], sls)
fw1v(ta, params_numbers);
fw5v(ta, params_numbers);

@btime fw1v($ta, $params_numbers);
@btime fw5v($ta, $params_numbers);

# Reference for performance
function fslsv(t,k)
   k[1].+k[2].*exp.((.- t.*k[2])./k[3])
end
fslsv(ta, params_numbers);
@btime fslsv($ta, $params_numbers);







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
  169.451 ns (2 allocations: 32 bytes)
  173.386 ns (2 allocations: 32 bytes)
  172.940 ns (2 allocations: 32 bytes)
  51.171 ns (2 allocations: 32 bytes)
  29.483 ns (2 allocations: 32 bytes)
  27.946 ns (2 allocations: 32 bytes)
  30.390 ns (2 allocations: 32 bytes)
  742.040 ns (1 allocation: 896 bytes)
  724.879 ns (1 allocation: 896 bytes)
  711.021 ns (1 allocation: 896 bytes)
  51.606 ns (4 allocations: 64 bytes)

=#

# https://github.com/JuliaLang/julia/pull/32737
# may be of interest as well.
