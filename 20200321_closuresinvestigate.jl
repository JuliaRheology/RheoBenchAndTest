using BenchmarkTools;
using Revise;

#########################################################################################
# HERE DEFINING THE NAMED TUPLE ON THE FLY FIXES THE ISSUE
#########################################################################################
# function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
#     arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
# end

# allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
# firstkwargs = (kwarg1=1, kwarg2=2)
# lastkwargs = (kwarg3=3, kwarg4=4)

# L1_fromglob(arg1; kwargs...) = L0(arg1; firstkwargs..., kwargs...)
# L1(arg1; kwargs...) = L0(arg1; (kwarg1=1, kwarg2=2)..., kwargs...)

# @btime L0(0; $allkwargs...) # 1.506 ns (0 allocations: 0 bytes)
# @btime L1_fromglob(0; $lastkwargs...) # 108.332 ns (2 allocations: 80 bytes)
# @btime L1(0; $lastkwargs...) # 1.205 ns (0 allocations: 0 bytes)

#########################################################################################
# TESTING ALL THE DIFFERENT CASES...
#########################################################################################
# function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
#     arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
# end

# function freezeparams(func_to_freeze, params_to_freeze)
#     (arg1; kwargz...) -> func_to_freeze(arg1; kwargz..., params_to_freeze...)
# end

# function freezeparams_let(func_to_freeze, params_to_freeze)
#     f = let params_to_freeze = params_to_freeze
#         (arg1; kwargs...) -> func_to_freeze(arg1; kwargs..., params_to_freeze...)
#     end
#     f
# end

# allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
# firstkwargs = (kwarg1=1, kwarg2=2)
# lastkwargs = (kwarg3=3, kwarg4=4)

# L1_FP_WITHARG_GLOBAL(arg1; kwargs...) = freezeparams(L0, firstkwargs)
# L1_FP_WITHARG_INTERP(arg1; kwargs...) = freezeparams(L0, (kwarg1=1, kwarg2=2))

# L1_FP_NOARG_GLOBAL = freezeparams(L0, firstkwargs)
# L1_FP_NOARG_INTERP = freezeparams(L0, (kwarg1=1, kwarg2=2))

# L1_FPL_WITHARG_GLOBAL(arg1; kwargs...) = freezeparams_let(L0, firstkwargs)
# L1_FPL_WITHARG_INTERP(arg1; kwargs...) = freezeparams_let(L0, (kwarg1=1, kwarg2=2))

# L1_FPL_NOARG_GLOBAL = freezeparams_let(L0, firstkwargs)
# L1_FPL_NOARG_INTERP = freezeparams_let(L0, (kwarg1=1, kwarg2=2))

# println("\nReference case with no freezing")
# @btime L0(0; $allkwargs...) # 1.205 ns (0 allocations: 0 bytes)

# println("\nL1_FP_WITHARG_GLOBAL")
# @btime L1_FP_WITHARG_GLOBAL(0; $lastkwargs...) # 271.585 ns (2 allocations: 64 bytes)

# println("\nL1_FP_WITHARG_INTERP")
# @btime L1_FP_WITHARG_INTERP(0; $lastkwargs...) # 1.506 ns (0 allocations: 0 bytes)

# println("\nL1_FP_NOARG_GLOBAL")
# @btime L1_FP_NOARG_GLOBAL(0; $lastkwargs...) # 43.997 ns (1 allocation: 32 bytes)

# println("\nL1_FP_NOARG_INTERP")
# @btime L1_FP_NOARG_INTERP(0; $lastkwargs...) # 43.092 ns (1 allocation: 32 bytes)

# println("\nL1_FPL_WITHARG_GLOBAL")
# @btime L1_FPL_WITHARG_GLOBAL(0; $lastkwargs...) # 269.493 ns (2 allocations: 64 bytes)

# println("\nL1_FPL_WITHARG_INTERP")
# @btime L1_FPL_WITHARG_INTERP(0; $lastkwargs...) # 1.506 ns (0 allocations: 0 bytes)

# println("\nL1_FPL_NOARG_GLOBAL")
# @btime L1_FPL_NOARG_GLOBAL(0; $lastkwargs...) # 42.490 ns (1 allocation: 32 bytes)

# println("\nL1_FPL_NOARG_INTERP")
# @btime L1_FPL_NOARG_INTERP(0; $lastkwargs...) # 42.490 ns (1 allocation: 32 bytes)

# println("\ntest done\n")

#########################################################################################
# Trying succesful approach above but within struct... Still doesn't work nicely.
#########################################################################################
# struct thang{T<:Function}
#     a::T
# end

# function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
#     arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
# end

# function freeze_params(struct_to_freeze, params_to_freeze)
#     newF(arg1; kwargs...) = let params_to_freeze = params_to_freeze
#                                 struct_to_freeze.a(arg1; kwargs..., params_to_freeze...)
#                             end
#     thang(newF)
# end

# thang1 = thang(L0)

# allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
# firstkwargs = (kwarg1=1, kwarg2=2)
# lastkwargs = (kwarg3=3, kwarg4=4)

# thang2 = freeze_params(thang1, firstkwargs)
# thang2_explicit = freeze_params(thang1, (kwarg1=1, kwarg2=2))

# @btime thang1.a(0; $allkwargs...) # 112.925 ns (1 allocation: 48 bytes)
# @btime thang2.a(0; $lastkwargs...) # 178.169 ns (7 allocations: 224 bytes)
# @btime thang2_explicit.a(0; $lastkwargs...) # 179.551 ns (7 allocations: 224 bytes)

#########################################################################################
# Try overload get property/field operators for struct.
#########################################################################################
import Base.getproperty

struct thingy{T<:Function}
    free_params::Tuple
    fixed_params::NamedTuple
    a::T
end

function Base.getproperty(inst::thingy, sym::Symbol)
    if sym==:a
        return (t; kwargs...) -> getfield(inst, sym)(t; kwargs..., inst.fixed_params...)
    elseif sym==:free_params || sym==:fixed_params
        return getfield(inst, sym)
    end
end

function freezeparams(orig::thingy, tofix::NamedTuple)
    newfree =  Tuple([i for i in orig.free_params if !(i in keys(tofix))])
    newfixed = merge(orig.fixed_params, tofix)
    return thingy(newfree, newfixed, orig.a)
end

function funk1(t; a, b, c)
    t+a+b+c
end

const pars = (a=1,b=2,c=3)
const spars = (b=2,c=3)

const t1 = thingy((:a, :b, :c), NamedTuple{}(), funk1)
const t2 = freezeparams(t1, (a=1,))

@btime t1.a(0.0; a=1, b=2, c=3)
@btime t2.a(0.0; b=2, c=3)
