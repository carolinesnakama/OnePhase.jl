type Class_line_search_parameters
  # fill in
end

type Class_IPM_parameters
  # fill in
end

type Class_termination_parameters

end

type Class_parameters
    output_level::Int64

    # init
    start_satisfying_bounds::Bool
    mu_primal_ratio::Float64
    init_style::Symbol

    # Class_termination_parameters
    max_it::Int64
    MAX_TIME::Float64
    tol::Float64
    tol_dual_abs::Float64
    tol_infeas::Float64

    # line search
    kkt_reduction_factor::Float64
    predict_reduction_factor::Float64
    predict_reduction_factor_MAX::Float64
    predict_reduction_eigenvector_threshold::Float64
    fraction_to_boundary::Float64
    ls_backtracking_factor::Float64
    ls_num_backtracks::Int64
    ls_mode_stable::Symbol
    ls_mode_agg::Symbol
    agg_protect_factor::Float64
    move_primal_seperate_to_dual::Bool
    max_step_primal_dual::Bool
    s_update::Symbol
    stb_before_agg::Bool
    mu_update::Symbol

    # IPM GENERAL
    inertia_test::Bool
    aggressive_dual_threshold::Float64
    max_it_corrections::Int64
    dual_scale_threshold::Float64
    dual_scale_mode::Symbol
    comp_feas::Float64
    comp_feas_agg::Float64
    min_step_size_stable::Float64
    min_step_size_correction::Float64
    ls_mode_stable_trust::Symbol
    ls_mode_stable_delta_zero::Symbol
    ls_mode_stable_correction::Symbol
    use_delta_s::Bool
    adaptive_mu::Symbol
    eigen_search::Bool


    # SADDLE PROBLEM
    ItRefine_BigFloat::Bool
    ItRefine_Num::Int64
    saddle_err_tol::Float64
    kkt_solver_type::Symbol
    linear_solver_type::Symbol
    linear_solver_safe_mode::Bool
    move_type::Symbol

    function Class_parameters()
        this = new()

        # init
        #this.start_satisfying_bounds = true #true #true
        this.start_satisfying_bounds = true
        this.mu_primal_ratio = 1.0 #10.0 #1.0 #1e-3
        this.init_style = :mehotra
        #this.init_style = :old_style # SOMETHING WRONG WITH THIS


        this.aggressive_dual_threshold = 1e3 #1.0 #1.0
        this.dual_scale_threshold = 1.0;
        this.dual_scale_mode = :sqrt
        this.inertia_test = true # true
        this.max_it_corrections = 2
        this.comp_feas = 1/100.0
        this.comp_feas_agg = 1/100.0 #1/50.0
        this.min_step_size_stable = 1e-4
        this.min_step_size_correction = 1e-1
        this.use_delta_s = false
        this.adaptive_mu = :none
        #this.adaptive_mu = :test1
        this.stb_before_agg = true
        this.eigen_search = false

        this.output_level = 3

        this.tol = 1e-6
        this.tol_dual_abs = 1e-6
        this.tol_infeas = 1e-12 # ????
        this.max_it = 3000;
        #this.MAX_TIME = 30.0
        this.MAX_TIME = 60.0 * 60 # 60 minutes max time

        # LINE SEARCH
        this.kkt_reduction_factor = 0.5
        this.predict_reduction_factor = 0.1 #1e-1
        this.predict_reduction_factor_MAX = 0.3
        this.predict_reduction_eigenvector_threshold = 1e-1
        this.fraction_to_boundary = 0.05
        this.ls_backtracking_factor = 0.5
        this.ls_num_backtracks = 60;
        this.ls_mode_stable_trust = :accept_stable #:accept_aggressive #:accept_filter #:accept_aggressive #:accept_filter
        this.ls_mode_stable_delta_zero = :accept_filter #:accept_filter
        this.ls_mode_stable_correction = :accept_filter
        this.ls_mode_agg = :accept_aggressive
        this.agg_protect_factor = 1e4

        this.move_type = :primal_dual
        this.move_primal_seperate_to_dual = true
        this.max_step_primal_dual = false #false
        this.s_update = :careful # :careful :loose, use careful except for experimentation
        this.mu_update = :static #:dynamic #:static #:static #:static #:dynamic :dynamic_agg


        this.saddle_err_tol = Inf
        this.ItRefine_Num = 2
        this.ItRefine_BigFloat = false

        if true
          this.kkt_solver_type = :schur
          this.linear_solver_type = :julia
        else
          this.kkt_solver_type = :symmetric
          this.linear_solver_type = :mumps
        end
        this.linear_solver_safe_mode = true

        return this
    end
end
