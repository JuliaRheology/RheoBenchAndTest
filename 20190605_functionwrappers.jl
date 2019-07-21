using Revise; using RHEOS; using BenchmarkTools; using FunctionWrappers:FunctionWrapper;

RheoFloat = Float64

struct TT
   G::FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}}
   J::FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}}

   Ga::FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}}
   Ja::FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}}
end

function test1()
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

function test2()
   # check if quote ... end affects speed
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = quote a1*t + a2 end
   J = quote a2*t + a1 end
   @eval return(TT(
      ((t, a) -> ($unpack_expr; $G)) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},
      ((t, a) -> ($unpack_expr; $J)) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},

      ((ta, a) -> ($unpack_expr; [$G for t in ta])) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
      ((ta, a) -> ($unpack_expr; [$J for t in ta])) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
      ))
end

function test3()
   # check if begin ... end affects speed
   p=(:a1, :a2)
   unpack_expr = Meta.parse(string(join(string.(p), ","), ", = a"))
   G = :(a1*t + a2)
   J = :(a2*t + a1)
   @eval return(TT(
      ((t, a) -> begin $unpack_expr; $G end) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},
      ((t, a) -> begin $unpack_expr; $J end) |> FunctionWrapper{RheoFloat, Tuple{RheoFloat, Vector{RheoFloat}}},

      ((ta, a) -> begin $unpack_expr; [$G for t in ta] end) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
      ((ta, a) -> begin $unpack_expr; [$J for t in ta] end) |> FunctionWrapper{Vector{RheoFloat}, Tuple{Vector{RheoFloat}, Vector{RheoFloat}}},
      ))
end

function test4()
   # check if . broadcast has any affect on speed
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

params = [1.0, 1.0];
testvector = Vector(0.0:0.001:100.0)

println("Testing broadcast over single-entry function wrapper\n=======================================================")
t1 = test1()
println("Array argument function wrapper")
@btime t1.Ga($testvector, $params)
# 76.687 μs // 781 KiB
println("Broadcast over single-entry function wrapper")
paramsTuple = ([1.0, 1.0],);
@btime t1.G.($testvector, $paramsTuple)
# 798 μs // 781 KiB
println("Test complete.\n\n\n")
# Array argument function wrapper always ~1 order of magnitude faster.

println("Testing quote ... end vs :( ... ) syntax\n=======================================================")
t2 = test2()
println("quote ... end syntax")
@btime t2.Ga($testvector, $params)
# 77 μs // 781 KiB
println(":( ) syntax")
paramsTuple = ([1.0, 1.0],);
@btime t1.Ga($testvector, $params)
# 77 μs // 781 KiB
println("Test complete.\n\n\n")
# Alternating very slight difference, negligible. Stick with quote ... end for now.

println("Testing begin ... end vs ( ... ) syntax\n=======================================================")
t3 = test3()
println("begin ... end syntax")
@btime t3.Ga($testvector, $params)
# 76 μs // 781 KiB
println("( ) syntax")
paramsTuple = ([1.0, 1.0],);
@btime t1.Ga($testvector, $params)
# 76 μs // 781 KiB
println("Test complete.\n\n\n")
# Alternating very slight difference, negligible. Stick with begin ... end for now.

println("Testing . broadcast vs array comprehension syntax\n=======================================================")
t4 = test4()
println("dot broadcast")
@btime t4.Ga($testvector, $params)
#  μs //  KiB
println("array comprehension")
paramsTuple = ([1.0, 1.0],);
@btime t1.Ga($testvector, $params)
#  μs //  KiB
println("Test complete.\n\n\n")
# 