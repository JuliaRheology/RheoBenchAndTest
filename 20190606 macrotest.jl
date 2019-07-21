function ftest()
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

ftest()
@mtest
