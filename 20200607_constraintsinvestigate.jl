# (a<1) & (a>0)
# (β<1) & (β>0)
# -a+β < 0

using NLopt
using Revise

function func(x, p)
    # simple linear func
    x*p[1] + p[2]
end

function cost(p, xvec, actual)
    # predicted
    pred = func.(xvec, (p,))

    # cost
    sum((pred .- actual).^2)
end

function constraint1(p)
    p[1] - p[2]
end

function main()
    xvec = Float64.(0.0:0.1:10)
    actualp = [6.0, 5.0]
    actualresponse = func.(xvec, (actualp,))

    opt = Opt(:LN_COBYLA, 2)
    opt.lower_bounds = [-Inf, -Inf]
    opt.upper_bounds = [Inf, Inf]
    opt.xtol_rel = 1e-8

    opt.min_objective = (params, grad) -> cost(params, xvec, actualresponse)

    inequality_constraint!(opt, (p, g) -> constraint1(p))

    (minf,minx,ret) = optimize(opt, [1.234, 3.678])
    numevals = opt.numevals # the number of function evaluations
    println("got $minf at $minx after $numevals iterations (returned $ret)")
end

main()