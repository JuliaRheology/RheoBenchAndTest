using Revise; using BenchmarkTools; using FunctionWrappers:FunctionWrapper;

struct TT
   Ga::Function
   Ja::Function
end

struct TTFW{T<:FunctionWrapper}
   Ga::T
   Ja::T
end

function FWftest()
   # test base case
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   @eval return(TTFW(
      ((ta, a) -> ($unpack_expr; [$G for t in ta])) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}},
      ((ta, a) -> ($unpack_expr; [$J for t in ta])) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}},
      ))
end

function FUftest()
   # test base case
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   @eval return(TT((ta, a) -> ($unpack_expr; [$G for t in ta]), (ta, a) -> ($unpack_expr; [$J for t in ta])))
end

macro FUmtest()
   # test base case
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   return quote TT((ta, a) -> ($unpack_expr; [$G for t in ta]), (ta, a) -> ($unpack_expr; [$J for t in ta])) end
end

function localscopetesting()
    testvector = Vector(0.0:0.01:100.0)
    params = [1.0, 1.0];

    # global FUF

    # FW1 = FWftest()
    # FUF = FUftest()
    FUM = @FUmtest

    # FW1.Ga(testvector, params)
    # FUF.Ga(testvector, params)
    FUM.Ga(testvector, params)

    #=
    RESULTS

    NOTE THAT IF YOU ARE DECLARING WITH THE GLOBAL PREFIX ABOVE
    YOU NEED TO RESTART JULIA SEESIONS IN BETWEEN TESTS TO CLEAR
    VARIABLES IN THE GLOBAL SCOPE.

    FW1 (FunctionWrappers) works without declaring a global (FunctionWrapper compiled within current world age)
    FUF (Functions from expressions with @eval return) only works if you declare them global because @eval escapes to global scope and back
    FUM Works fine because it is literally a macro expansion that happens at parse time, no need to declare global
    =#
end

localscopetesting()

# Global scope testing
# testvector = Vector(0.0:0.01:100.0)
# params = [1.0, 1.0];

# FW1 = FWftest()
# FUF = FUftest()
# FUM = @FUmtest

# @btime FW1.Ga($testvector, $params) # 9.040 μs (3 allocations: 78.30 KiB)
# @btime FUF.Ga($testvector, $params) # 8.739 μs (3 allocations: 78.30 KiB)
# @btime FUM.Ga($testvector, $params) # 9.040 μs (3 allocations: 78.30 KiB)

# println("\nDone")

