using Revise; using BenchmarkTools; using FunctionWrappers:FunctionWrapper

function expgen(terms)
  unpacker = ""
  for i in 0:(2*terms)
    unpacker = string(unpacker, "a", i, ", ")
  end
  unpacker = string(unpacker, "= params")
  unpacker_expression = Meta.parse(unpacker)
  
  expsum = "a0"
  for i in 1:2:(2*terms)
    expsum = string(expsum, " + a", i, "*exp(-ti/a", i + 1, ")")
  end
  expsum_expression = Meta.parse(expsum)

  @eval return((t, params) -> ($unpacker_expression; [$expsum_expression for ti in t]) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}}) 
end

macro expgen(terms::Int)
  unpacker = ""
  for i in 0:(2*terms)
    unpacker = string(unpacker, "a", i, ", ")
  end
  unpacker = string(unpacker, "= params")
  unpacker_expression = Meta.parse(unpacker)
  
  expsum = "a0"
  for i in 1:2:(2*terms)
    expsum = string(expsum, " + a", string(i), "*exp(-ti/a", string(i + 1), ")")
  end
  expsum_expression = Meta.parse(expsum)

  return quote (t, params) -> ($unpacker_expression; [$expsum_expression for ti in t]) |> FunctionWrapper{Vector{Float64}, Tuple{Vector{Float64}, Vector{Float64}}} end
end

fgen = expgen(1)
mgen = @expgen 1

times = Vector(0.0:0.1:10.0);
params = [1.0 for i in 1:21]

println("Benching individual functions")
println("Using @eval function")
@btime fgen($times, $params)
println("Using a macro")
@btime mgen($times, $params)
println("\nResults: exactly the same.")

function fexpgenLooped()
  for i in 1:10
    expgen(10)
  end
end

function mexpgenLooped()
  for z in 1:10  
    @expgen 10 
  end
end

println("\nBenching looped function generations")
println("Using @eval function")
@btime fexpgenLooped()
println("Using a macro")
@btime mexpgenLooped() 
println("Macro much faster at generating the function, work is moved to compile time?")
