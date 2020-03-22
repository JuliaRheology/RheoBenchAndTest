using Revise;
using BenchmarkTools

# Tests related to above
# function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
#     arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
# end

# allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
# firstkwargs = (kwarg1=1, kwarg2=2)
# lastkwargs = (kwarg3=3, kwarg4=4)

# L1(arg1; kwargs...) = L0(arg1; (kwarg1=1, kwarg2=2)..., kwargs...)

# @btime L0(0; $allkwargs...)
# @btime L1(0; $lastkwargs...)

#Further test
# function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
#     arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
# end

# function freeze_params(func_to_freeze, params_to_freeze)
#     lz = keys(params_to_freeze)
#     vz = values(params_to_freeze)

#     loco = NamedTuple{lz}(vz)

#     (arg1; kwargz...) -> func_to_freeze(arg1; loco..., kwargz...)
# end

# allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
# firstkwargs = (kwarg1=1, kwarg2=2)
# lastkwargs = (kwarg3=3, kwarg4=4)

# L1(arg1; kwargs...) = freeze_params(L0, firstkwargs)

# @btime L0(0; $allkwargs...)
# @btime L1(0; $lastkwargs...)

# another test
# function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
#     arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
# end

# allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
# firstkwargs = (kwarg1=1, kwarg2=2)
# lastkwargs = (kwarg3=3, kwarg4=4)

# const L1 = let firstkwargs = firstkwargs
#     (arg1; kwargs...) -> L0(arg1; firstkwargs..., kwargs...)
# end

# @btime L0(0; $allkwargs...)  # 1.421 ns (0 allocations: 0 bytes)
# @btime L1(0; $lastkwargs...) # 1.420 ns (0 allocations: 0 bytes)

# maybe final
# function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
#     arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
# end

# function freeze_params(func_to_freeze, params_to_freeze)
#     @generated out(arg1; kwargs...) = :(func_to_freeze(arg1; $(params_to_freeze)..., kwargs...))
# end

# allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
# firstkwargs = (kwarg1=1, kwarg2=2)
# lastkwargs = (kwarg3=3, kwarg4=4)

# L1 = freeze_params(L0, firstkwargs)

# @btime L0(0; $allkwargs...) 
# @btime L1(0; $lastkwargs...) 

# manual performance tip test
function L0(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
    arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
end

function freeze_params(func_to_freeze, params_to_freeze)
    f = let params_to_freeze = params_to_freeze
        (arg1; kwargs...) -> func_to_freeze(arg1; loco..., kwargs...)
    end
    f
end

allkwargs = (kwarg1=1, kwarg2=2, kwarg3=3, kwarg4=4)
firstkwargs = (kwarg1=1, kwarg2=2)
lastkwargs = (kwarg3=3, kwarg4=4)

L1(arg1; kwargs...) = freeze_params(L0, firstkwargs)

@btime L0(0; $allkwargs...)
@btime L1(0; $lastkwargs...)