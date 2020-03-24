using Revise; using BenchmarkTools; using FunctionWrappers:FunctionWrapper;

struct TT
   Ga::Function
end

struct TTFW{T<:FunctionWrapper}
   Ga::T
end

function FWftest(G::Expr)
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))

   @eval return(TTFW(((ta, a) -> ($unpack_expr; [$G for t in ta])) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}}))
end

macro FUmtest(z)
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))

   return quote TT((ta, a) -> ($unpack_expr; [$z for t in ta])) end
end

function localscopetesting()
   testvector = Vector(0.0:1.0:10.0)
   params = [1.0, 1.0];

   # FW1 = FWftest(:(a1*t + a2))
   # FW2 = FWftest(:(a1 + a2))
   # println(FW1.Ga(testvector, params))
   # println(FW2.Ga(testvector, params))

   # println("\n")

   FUM1 = @FUmtest a1*t+a2
   # FUM2 = @FUmtest a1+a2
   println(FUM1.Ga(testvector, params))
   # println(FUM2.Ga(testvector, params))

   #=
   FW1 (FunctionWrappers) works without declaring a global (FunctionWrapper compiled within current world age)
   FUM Works fine because it is literally a macro expansion that happens at parse time, no need to declare global
   =#
end

# localscopetesting();
# @macroexpand @FUmtest 

# Global scope testing
# testvector = Vector(0.0:0.01:100.0)
# params = [1.0, 1.0];

# FW1 = FWftest()
# FUM = @FUmtest

# @btime FW1.Ga($testvector, $params) # 9.040 μs (3 allocations: 78.30 KiB)
# @btime FUM.Ga($testvector, $params) # 9.040 μs (3 allocations: 78.30 KiB)

# println("\nDone")

