using BenchmarkTools;

# is it an issue?

function L0_tup(arg1; kwarg1, kwarg2, kwarg3, kwarg4)
  arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
end

function L0_arr(arg1, kwarg_arr)
  kwarg1, kwarg2, kwarg3, kwarg4 = kwarg_arr
  arg1 + kwarg1 + kwarg2 + kwarg3 + kwarg4
end

function L0_tup_wrapped(arg1, kwarg_arr)
  symbs = (:kwarg1, :kwarg2, :kwarg3, :kwarg4)
  return L0_tup(arg1; NamedTuple{symbs}(kwarg_arr)...)
end

# test array
vars = [5, 4, 3, 2]

# @btime L0_arr(5, $vars) # 1.808 ns
# @btime L0_tup_wrapped(5, $vars) # 468 ns

# the typ overhead adds ~ 400 ns overhead. Is this signifcant relative to Mittag-Leffler function?

using MittagLeffler
t = -Float64.(0.0:0.001:1.0) # 1000 time points, representative data set
# @btime mittleff.(0.75, $t); # 37.430 ms, ~100000x more time required than for creating the tuple
# @btime mittleff.(0.25, $t); # 39.961 ms, ~100000x more time required than for creating the tuple

# the time for sending array -> namedtuple is negligible compared to mittleff.

# a neatened up PoC of the original
-----------------------------------
struct dummy_type{T<:Function}
  free_params::Tuple
  fixed_params::NamedTuple
  afunc::T
end

function freeze_params(orig::dummy_type, tofix::NamedTuple)
  newfree =  Tuple([i for i in orig.free_params if !(i in keys(tofix))])
  newfixed = merge(orig.fixed_params, tofix)
  return dummy_type(newfree, newfixed, orig.afunc)
end

function get_frozen_func(orig::dummy_type)
  f = let func = orig.afunc, fixed = orig.fixed_params
    (t; kwargs...) -> func(t; kwargs..., fixed...)
  end
  return f
end

function func1(t; a, b, c)
  t + a + b + c
end

t1 = dummy_type((:a, :b, :c), NamedTuple{}(), func1)
t2 = freeze_params(t1, (a = 1,))
func2 = get_frozen_func(t2)

full_kwargs = (a = 1, b = 2, c = 3)
part_kwargs = (b = 2, c = 3)

@btime func1.(t; $full_kwargs...); # 1.085 us
@btime func2.(t; $part_kwargs...); # 1.085 us, exactly the same

