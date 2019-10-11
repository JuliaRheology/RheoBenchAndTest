using Test; using PyPlot; using Revise; using BenchmarkTools; using AbstractFFTs;

#= test function without discontinuity in derivative at t=0 =#
function funk1(x)
  return (1/2)*x^2 + (1/3)*x^3 - (1/4)*x^4 
end

function funk1dot(x)
  return x + x^2 + -x^3
end

function funk2(x)
  return x + (1/2)*x^2 - (1/3)*x^3
end

function funk2dot(x)
  return 1 + x - x^2
end

even(x) = x%2==0

function spectralmultiplier(x)
  N = length(x)
  out = similar(x, Complex{Float64})
  for k in 0:(N-1)
    if k<(N/2)
      out[k+1] = x[k+1]*2*π*im*k
    
    elseif k>(N/2)
      out[k+1] = x[k+1]*2*π*im*(k-N)

    end
  end
  if even(N); out[N÷2]=0.0; end
  
  return out
end

# get signal
dt = 0.1
t = Vector{Float64}(0.0:dt:10.0)

y = funk1.(t)
