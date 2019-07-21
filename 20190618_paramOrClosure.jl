using DSP:conv; using BenchmarkTools

function boltzconvolve_closure(mod, t, dt, ϵdot)
  mod_vector = mod(t)
  out = conv(mod_vector, ϵdot)
end

function objectivefunction_closure(params, grad, modulus, t, dt, ϵdot)
  mod = (x -> modulus(x, params))
  convolved = boltzconvolve_closure(mod, t, dt, ϵdot)
end

function boltzconvolve_sendparams(mod, params, t, dt, ϵdot)
  mod_vector = mod(t, params)
  out = conv(mod_vector, ϵdot)
end

function objectivefunction_sendparams(params, grad, mod, t, dt, ϵdot)
  convolved = boltzconvolve_sendparams(mod, params, t, dt, ϵdot)
end

function SLS2_gmod(t, params)
  params[1] .+ params[2]*exp.(-t/params[3]) .+ params[4]*exp.(-t/params[5])
end

dt = 0.1
t = Vector{Float64}(0.0:dt:1000.0)
ϵdot = ones(length(t))
params = ones(5)
@btime objectivefunction_closure($params, [0.0], $SLS2_gmod, $t, $dt, $ϵdot);
@btime objectivefunction_sendparams($params, [0.0], $SLS2_gmod, $t, $dt, $ϵdot);

