function ftest()
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   @eval return(TT(
      ((t, a) -> ($unpack_expr; $G)) |> FunctionWrapper{Float64, Tuple{Float64, Vector{Float64}}},
      ((t, a) -> ($unpack_expr; $J)) |> FunctionWrapper{Float64, Tuple{Float64, Vector{Float64}}},

      ((ta, a) -> ($unpack_expr; [$G for t in ta])) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}},
      ((ta, a) -> ($unpack_expr; [$J for t in ta])) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}},
      ))
end

macro mtest()
   # test base case
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   return quote TT(
      ((t, a) -> ($unpack_expr; $G)) |> FunctionWrapper{Float64, Tuple{Float64, Vector{Float64}}},
      ((t, a) -> ($unpack_expr; $J)) |> FunctionWrapper{Float64, Tuple{Float64, Vector{Float64}}},

      ((ta, a) -> ($unpack_expr; [$G for t in ta])) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}},
      ((ta, a) -> ($unpack_expr; [$J for t in ta])) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}},
     ) end
end

ftest()
@mtest
