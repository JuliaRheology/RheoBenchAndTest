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
function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
    arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
end

function freezeparams(func_to_freeze, params_to_freeze)
    (arg1; kwargz...) -> func_to_freeze(arg1; kwargz..., params_to_freeze...)
end

function freezeparams_let(func_to_freeze, params_to_freeze)
    f = let params_to_freeze = params_to_freeze
        (arg1; kwargs...) -> func_to_freeze(arg1; kwargs..., params_to_freeze...)
    end
    f
end

allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
firstkwargs = (kwarg1=1, kwarg2=2)
lastkwargs = (kwarg3=3, kwarg4=4)

L1_FP_WITHARG_GLOBAL(arg1; kwargs...) = freezeparams(L0, firstkwargs)
L1_FP_WITHARG_INTERP(arg1; kwargs...) = freezeparams(L0, (kwarg1=1, kwarg2=2))

L1_FP_NOARG_GLOBAL = freezeparams(L0, firstkwargs)
L1_FP_NOARG_INTERP = freezeparams(L0, (kwarg1=1, kwarg2=2))

L1_FPL_WITHARG_GLOBAL(arg1; kwargs...) = freezeparams_let(L0, firstkwargs)
L1_FPL_WITHARG_INTERP(arg1; kwargs...) = freezeparams_let(L0, (kwarg1=1, kwarg2=2))

L1_FPL_NOARG_GLOBAL = freezeparams_let(L0, firstkwargs)
L1_FPL_NOARG_INTERP = freezeparams_let(L0, (kwarg1=1, kwarg2=2))

println("\nReference case with no freezing")
@btime L0(0; $allkwargs...) 

println("\nL1_FP_WITHARG_GLOBAL")
@btime L1_FP_WITHARG_GLOBAL(0; $lastkwargs...)

println("\nL1_FP_WITHARG_INTERP")
@btime L1_FP_WITHARG_INTERP(0; $lastkwargs...)

println("\nL1_FP_NOARG_GLOBAL")
@btime L1_FP_NOARG_GLOBAL(0; $lastkwargs...)

println("\nL1_FP_NOARG_INTERP")
@btime L1_FP_NOARG_INTERP(0; $lastkwargs...)

println("\nL1_FPL_WITHARG_GLOBAL")
@btime L1_FPL_WITHARG_GLOBAL(0; $lastkwargs...)

println("\nL1_FPL_WITHARG_INTERP")
@btime L1_FPL_WITHARG_INTERP(0; $lastkwargs...)

println("\nL1_FPL_NOARG_GLOBAL")
@btime L1_FPL_NOARG_GLOBAL(0; $lastkwargs...)

println("\nL1_FPL_NOARG_INTERP")
@btime L1_FPL_NOARG_INTERP(0; $lastkwargs...)

println("\ntest done\n")
#########################################################################################
# 
#########################################################################################
struct thang
    a::Function
end

function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
    arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
end

function freeze_params(struct_to_freeze, params_to_freeze)
    newF(arg1; kwargs...) = let params_to_freeze = params_to_freeze
                                struct_to_freeze.a(arg1; kwargs..., params_to_freeze...)
                            end
    thang(newF)
end

thang1 = thang(L0)

allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
firstkwargs = (kwarg1=1, kwarg2=2)
lastkwargs = (kwarg3=3, kwarg4=4)

thang2 = freeze_params(thang1, firstkwargs)
thang2_explicit = freeze_params(thang1, (kwarg1=1, kwarg2=2))

@btime thang1.a(0; $allkwargs...)
@btime thang2.a(0; $lastkwargs...)
@btime thang2_explicit.a(0; $lastkwargs...)