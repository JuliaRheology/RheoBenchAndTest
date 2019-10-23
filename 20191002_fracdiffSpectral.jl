using AbstractFFTs; using FFTW; using PyPlot; using SpecialFunctions; using Revise

#= test modulus =#
function mod2test(t, params)
    return exp.(-t)
end

#= convolution convenience function =#
function boltzconvolve(modulus, time_series, dt, prescribed_dot)
    Modulus = modulus(time_series)
    β = conv(Modulus, prescribed_dot)
    β = β[1:length(time_series)]*dt
end

#= to test =#
function noIndex_objective(params, modulus, time_series, dt, prescribed_dot, measured)
    mod = (t->modulus(t,params))
    convolved = boltzconvolve(mod, time_series, dt, prescribed_dot)
    cost = sum((measured - convolved).^2)
    return cost
end

function Index_objective(params, modulus, time_series, dt, prescribed_dot, measured, indices)
    mod = (t->modulus(t,params))
    convolved = boltzconvolve(mod, time_series, dt, prescribed_dot)
    cost = sum((measured - convolved[indices]).^2)
    return cost
end

# get signal
dt = 0.01
t = Vector{Float64}(0.0:dt:1000.0)
loading_derivative = -2*(t .- 50)
exact_response = 102 .- 102*exp.(-t) .- 2t
params = ones(5)

# to bench whether function needs to be specialised, use full range of indices
indicestouse = collect(1:length(t))

# in real code, can pass selected indices only
exact_response_indices_only = exact_response[indicestouse]

@btime noIndex_objective($params, $mod2test, $t, $dt, $loading_derivative, $exact_response)
@btime Index_objective($params, $mod2test, $t, $dt, $loading_derivative, $exact_response_indices_only, $indicestouse)
