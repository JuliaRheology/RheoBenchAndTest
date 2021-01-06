import Core: typeof

struct Foo
  a::Int
  b::Int
end

function typeof(x::Foo)
  println("here")
end
