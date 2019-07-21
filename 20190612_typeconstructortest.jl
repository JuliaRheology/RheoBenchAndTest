struct aType
  a::Integer
end

function (::Type{aType})(arg1::Int, arg2::Int)
  println("thang")
end

outputty = aType(1, 3)

println(outputty.a)
