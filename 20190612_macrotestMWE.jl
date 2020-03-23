using Revise; using BenchmarkTools; using FunctionWrappers:FunctionWrapper;

RheoFloat = Float64

struct TT
   G::FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}}
   J::FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}}

   Ga::FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}}
   Ja::FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}}
end

function ftest()
   # test base case
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   @eval return(TT(
      ((t, a) -> ($unpack_expr; $G)) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},
      ((t, a) -> ($unpack_expr; $J)) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},

      ((ta, a) -> ($unpack_expr; [$G for t in ta])) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
      ((ta, a) -> ($unpack_expr; [$J for t in ta])) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
      ))
end

macro mtest()
   # test base case
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   return quote TT(
      ((t, a) -> ($unpack_expr; $G)) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},
      ((t, a) -> ($unpack_expr; $J)) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},

      ((ta, a) -> ($unpack_expr; [$G for t in ta])) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
      ((ta, a) -> ($unpack_expr; [$J for t in ta])) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
     ) end
end

params = [1.0, 1.0];
testvector = Vector(0.0:0.01:100.0)

t1 = ftest()
t2 = @mtest

#println("Function")
@btime t1.Ga($testvector, $params) # 8.739 μs (3 allocations: 78.30 KiB)
@btime t2.Ga($testvector, $params) # 8.437 μs (3 allocations: 78.30 KiB)
