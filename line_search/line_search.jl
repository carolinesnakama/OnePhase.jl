abstract abstract_ls_info;

include("filter_ls.jl")
include("agg_ls.jl")
include("stable_ls.jl")
include("kkt_ls.jl")

function scale_direction(dir::Class_point, step_size::Float64)
    new_dir = deepcopy(dir)
    new_dir.x *= step_size
    new_dir.y *= step_size
    new_dir.s *= step_size
    new_dir.mu *= step_size
    new_dir.primal_scale *= step_size

    return new_dir
end

function max_step_primal_dual(iter::Class_iterate, dir::Class_point, threshold::Float64)
    return simple_max_step([iter.point.s; iter.point.y], [dir.s; dir.y], threshold)
end

function max_step_primal(iter::Class_iterate, dir::Class_point, threshold::Float64)
    return simple_max_step(iter.point.s, dir.s, threshold)
end

function simple_max_step(val::Array{Float64,1}, dir::Array{Float64,1}, threshold::Float64)
    q = 1.0 / (1.0 - threshold)
    ratio = maximum( [1.0; -q * dir ./ val ] ) #; -q * dir.y ./ iter.point.y] );
    return 1.0 / ratio
end

function Blank_ls_info()
    this = Class_stable_ls(0.0,0.0, 0, 0.0, 0.0)
    return this
end

#=function ls_feasible_solution(iter::Class_iterate, orginal_dir::Class_point, accept_type::Symbol, filter::Array{Class_filter,1},  pars::Class_parameters, min_step_size::Float64, timer::class_advanced_timer)

end=#

function simple_ls(iter::Class_iterate, orginal_dir::Class_point, accept_type::Symbol, filter::Array{Class_filter,1},  pars::Class_parameters, min_step_size::Float64, timer::class_advanced_timer)
    start_advanced_timer(timer, "SIMPLE_LS")

    if pars.max_step_primal_dual == true
      step_size_P = max_step_primal_dual(iter, orginal_dir, pars.fraction_to_boundary)
    elseif pars.max_step_primal_dual == false
      step_size_P = max_step_primal(iter, orginal_dir, pars.fraction_to_boundary)
    else
      error("SIMPLE_LS")
    end

    if accept_type == :accept_stable
      accept_obj = Class_stable_ls(iter, orginal_dir, pars)
    elseif accept_type == :accept_aggressive
      accept_obj = Class_agg_ls(iter, orginal_dir, pars)
    elseif accept_type == :accept_filter
      accept_obj = Class_filter_ls(iter, orginal_dir, pars)
    elseif accept_type == :accept_kkt
      accept_obj = Class_kkt_ls(iter, orginal_dir, pars)
    elseif accept_type == :accept_comp
      accept_obj = Class_comp_ls(iter, orginal_dir, pars)
    else
      error("acceptance function not defined")
    end

    if accept_obj.predict_red >= 0.0
        my_warn("predicted reduction non-negative")
        #accept_obj.num_steps = 0
        #return :predict_red_non_negative, iter, accept_obj
    end

    if pars.output_level >= 5
      println(pd("α_P"), pd("α_D"), pd("is_feas"), pd("status"))
    end

    for i = 1:pars.ls_num_backtracks
      status = :none

      if step_size_P >= min_step_size
        start_advanced_timer(timer,"SIMPLE_LS/move")
        candidate, is_feas, step_size_D = move(iter, orginal_dir, step_size_P, pars, timer)
        pause_advanced_timer(timer,"SIMPLE_LS/move")

        #start_advanced_timer(timer,"SIMPLE_LS/move/dual")
        #candidate, step_size_D = move_dual(candidate, orginal_dir, pars, timer)
        #start_advanced_timer(timer,"SIMPLE_LS/move/dual")

        accept_obj.step_size_P = step_size_P
        accept_obj.step_size_D = step_size_D
        accept_obj.num_steps = i


        if is_feas
            start_advanced_timer(timer,"SIMPLE_LS/accept?")
            update_grad!(candidate, timer)
            update_obj!(candidate, timer)
            update_J!(candidate, timer)

            status = accept_func!(accept_obj, iter, candidate, orginal_dir, step_size_P, filter, pars, timer)
            pause_advanced_timer(timer,"SIMPLE_LS/accept?")
        end

        if pars.output_level >= 5
          println(rd(step_size_P), rd(step_size_D), pd(is_feas), pd(status))
        end

        #if is_feas
        #  pause_advanced_timer(timer,"SIMPLE_LS/feas")
        #end

        if is_feas && status == :success
          pause_advanced_timer(timer,"SIMPLE_LS")
          return :success, candidate, accept_obj
        elseif is_feas && status == :predict_red_non_negative
          pause_advanced_timer(timer, "SIMPLE_LS")
          return status, iter, accept_obj
        end



        step_size_P *= pars.ls_backtracking_factor
      else
        if pars.output_level >= 5
          println(rd(step_size_P), pd("N/A"), pd("N/A"), pd(:min_α))
        end

        pause_advanced_timer(timer, "SIMPLE_LS")
        return :min_α, iter, accept_obj
      end
    end

    pause_advanced_timer(timer, "SIMPLE_LS")
    return :max_ls_it, iter, accept_obj
end



function eigenvector_ls(iter::Class_iterate, orginal_dir::Class_point, pars::Class_parameters)
    step_size_P = 1.0

    best_candidate = iter;
    intial_val = eval_merit_function(iter, pars)
    best_val = intial_val

    max_it = 10;

    i = 1;
    for i = 1:max_it
      candidate_pos, is_feas, step_size_D = move(iter, orginal_dir, step_size_P, pars, timer)
      candidate_neg, is_feas, step_size_D = move(iter, orginal_dir, -step_size_P, pars, timer)

      better = false

      new_val = eval_merit_function(candidate_pos, pars)
      if new_val < best_val
        best_candidate = candidate_pos
        best_val = new_val
        better = true
      end

      new_val = eval_merit_function(candidate_neg, pars)
      if new_val < best_val
        best_candidate = candidate_neg
        best_val = new_val
        better = true
      end

      if !better
        break
      end

      step_size_P *= 6.0
    end

    @show step_size_P, norm(orginal_dir.x), best_val - intial_val

    if i == max_it
      my_warn("max it reached for eig search")
    end

    return :success, best_candidate
end
