using Revise; using BenchmarkTools; using FunctionWrappers:FunctionWrapper;

function afunk()
    @eval return(2*$x)
end

afunk()







# ######## commented all below

# # https://discourse.julialang.org/t/how-to-bypass-the-world-age-problem/7012/22
# # https://discourse.julialang.org/t/running-in-world-age-x-while-current-world-is-y-errors/5871/2

# function h(t,e)
#    @eval f=(x->$e)
#    print(f(t))
# end

# function h1(t,e)
#    @eval f= (x->$e) |> FunctionWrapper{Float64,Tuple{Float64}}
#    print(f(t))
# end


# # try h(1.,:(x+1)) and h1(1.,:(x+1))




# using BenchmarkTools

# e0=:(exp(x+1))
# #e0=:(x+1)

# function g(e)
#    @eval return( (x->$e)  )
# end

# fe=g(e0)

# # ja(1., e0) should work
# function ja(t,e)
#    print(fe(t))
# end

# # jb(1., e0) should trigger world age problem
# function jb(t,e)
#    f=g(e)
#    print(f(t))
# end


# function gw(e)
#    @eval return( (x->$e) |> FunctionWrapper{Float64,Tuple{Float64}} )
# end

# # Now this should be fine again
# function jc(t,e)
#    f=gw(e)
#    print(f(t))
# end


# # jd(1., e0) should trigger world age problem
# function jd(t,e)
#    f=g(e)
#    print(Base.invokelatest(f,t))
# end






# f1(x,a)=exp(x+a)
# f0=x->f1(x,1.)
# # f2=g(e0)
# f2 = x->exp(x+1)
# # f2 = gw(e0)

# function jt(e)
#    print("With FunctionWrapper")
#    f=gw(e)
#    @btime for i=0.:0.01:10.; $f(i); end
#    #println(f(-1.))

#    print("Using invokelatest")
#    fl=g(e)
#    @btime for i=0.:0.01:10.; Base.invokelatest($fl,i); end
#    #println(Base.invokelatest(fl,0.))

#    print("Nested function calls")
#    @btime for i=0.:0.01:10.; f0(i); end
#    #println(f0(0.))

#    print("Single function calls")
#    @btime for i=0.:0.01:10.; f2(i); end
#    #println(f2(0.))

#    print("Optimum - in loop expression")
#    @btime for i=0.:0.01:10.; exp(i+1); end
# end


# # e0 = :(x+1)

# # julia> jt(e0)
# # With FunctionWrapper  6.244 μs (0 allocations: 0 bytes)
# # Using invokelatest  51.916 μs (3003 allocations: 46.92 KiB)
# # Nested function calls  18.857 μs (2002 allocations: 31.28 KiB)
# # Optimum - in loop expression  503.855 ns (0 allocations: 0 bytes)

# # e0 = :(exp(x+1))

# # julia> jt(e0)
# # With FunctionWrapper  18.099 μs (0 allocations: 0 bytes)
# # 2.718281828459045
# # Using invokelatest  73.238 μs (3003 allocations: 46.92 KiB)
# # 2.718281828459045
# # Nested function calls  36.860 μs (2002 allocations: 31.28 KiB)
# # 2.718281828459045
# # Single function calls  38.826 μs (2002 allocations: 31.28 KiB)     Why is that so big???
# # 2.718281828459045
# # Optimum - in loop expression  13.058 μs (0 allocations: 0 bytes)
# # 2.718281828459045






# @eval f=(x->$e)

# f(t)=t


# function h0(t)
#    f(i)=3*i
#    print(f(t))
# end

# function h1(t)
#    @eval f(i)=3*i
#    print(f(t))
# end
# function h2(t)
#    @eval f(i)=3*i
#    g=Base.invokelatest(f,t)
# end