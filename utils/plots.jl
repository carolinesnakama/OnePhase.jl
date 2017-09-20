function plot_iteration_ratios(its, best, ratios)
    min_y = 1.0

    y_vals = collect(1:length(best)) / length(best)
    for (method_name, val) in its
      semilogx(sort(ratios[method_name]), y_vals, label=method_name, basex=2)
      min_y = min(min_y,sum(ratios[method_name] .== 1.0) / length(best))
    end
    ax = gca()
    ax[:set_xlim]([1.0,2^6.0])
    ax[:set_ylim]([min_y,1.0])

    #ax[:xaxis][:ticker] = 0.5
    #title("Comparsion on 119 CUTEst problems")
    #title("Comparsion on 45 CUTEst problems")
    xlabel("iteration ratio to best solver")
    ylabel("proportion of problems")
    grid("on")

    legend()
end
function plot_iterations(its, best, ratios)
    min_y = 1.0

    y_vals = collect(1:length(best)) / length(best)
    for (method_name, val) in its
      semilogx(sort(its[method_name]), y_vals, label=method_name, basex=10)
      min_y = min(min_y,sum(its[method_name] .== 1.0) / length(best))
    end
    ax = gca()
    ax[:set_xlim]([1.0,my_par.max_it])
    ax[:set_ylim]([min_y,1.0])

    #ax[:xaxis][:ticker] = 0.5
    #title("CUTEst problems with 50 < nvar, ncons < 10000")
    #title("Comparsion on 45 CUTEst problems")
    xlabel("iterations")
    ylabel("proportion of problems")
    grid("on")

    legend()
end
