using CUTEst

type Class_bounds
    l_i::Array{Int64,1}
    u_i::Array{Int64,1}
    l::Array{Float64,1}
    u::Array{Float64,1}

    function Class_bounds(lb_vec::Array{Float64,1}, ub_vec::Array{Float64,1})
        @assert(length(lb_vec) == length(ub_vec))
        this = new([],[],[],[]);
        for i = 1:length(lb_vec)
            if lb_vec[i] > -Inf
               push!(this.l_i, i)
               push!(this.l, lb_vec[i])
            end

            if ub_vec[i] < Inf
               push!(this.u_i, i)
               push!(this.u, ub_vec[i])
            end
        end

        return this;
    end
end

function _i_not_fixed(m::CUTEst.CUTEstModel)
    return (1:m.meta.nvar)[m.meta.lvar .!= m.meta.uvar]
end

type Class_CUTEst <: abstract_nlp
    nlp::CUTEst.CUTEstModel

    bcon::Class_bounds
    bvar::Class_bounds

    function Class_CUTEst(nlp::CUTEst.CUTEstModel)
        ind = _i_not_fixed(nlp)
        return new(nlp, Class_bounds(nlp.meta.lcon, nlp.meta.ucon), Class_bounds(nlp.meta.lvar[ind], nlp.meta.uvar[ind]))
    end
end

function suggested_starting_point(m::Class_CUTEst)
    ind = _i_not_fixed(m.nlp)
    return m.nlp.meta.x0[ind]
end


function lb(x::Array{Float64,1}, bd::Class_bounds)
    return x[bd.l_i] - bd.l
end

function ub(x::Array{Float64,1}, bd::Class_bounds)
    return bd.u - x[bd.u_i]
end

function nbounds_orginal(nlp::Class_CUTEst)
    return length(nlp.bvar.l_i) + length(nlp.bvar.u_i)
end

function ncons_orginal(nlp::Class_CUTEst)
    return length(nlp.bcon.l_i) + length(nlp.bcon.u_i)
end

function cons_indicies(nlp::Class_CUTEst)
    m = ncons_orginal(nlp)
    if m > 0
      return 1:m
    else
      return []
    end
end


function bound_indicies(nlp::Class_CUTEst)
    m = ncons_orginal(nlp)
    r = nbounds_orginal(nlp)
    if r > 0
      return (m + 1):(m + r)
    else
      return [];
    end
end

function y_l_con(y::Array{Float64,1}, m::Class_CUTEst)
    return y[1:length(m.bcon.l)]
end

function y_u_con(y::Array{Float64,1}, m::Class_CUTEst)
    n_lcon = length(m.bcon.l)
    return y[(n_lcon + 1):(n_lcon + length(m.bcon.u))]
end

function eval_f(m::Class_CUTEst, x::Array{Float64,1})
    return obj(m.nlp, _cute_x(m, x) )
end

function eval_a(m::Class_CUTEst, x::Array{Float64,1})
    a = cons(m.nlp, _cute_x(m, x) )
    return [lb(a, m.bcon); ub(a, m.bcon); lb(x, m.bvar); ub(x, m.bvar)];
end

function _cute_x(m::Class_CUTEst, x::Array{Float64,1})
    ind = _i_not_fixed(m.nlp)
    @assert(length(x) == length(ind))
    cute_x = m.nlp.meta.x0 # get correct values of fixed variables
    cute_x[ind] = x

    return cute_x
end

function eval_jac(m::Class_CUTEst, x::Array{Float64,1})
    cute_x = _cute_x(m, x)

    J = jac(m.nlp, cute_x)[:, _i_not_fixed(m.nlp)];

    my_eye = speye(length(x))
    return [J[m.bcon.l_i,:]; -J[m.bcon.u_i,:]; my_eye[m.bvar.l_i,:]; -my_eye[m.bvar.u_i,:]];
end

function eval_grad_lag(m::Class_CUTEst, x::Array{Float64,1}, y::Array{Float64,1}, w::Float64=1.0)
    #y_cons = m.nlp.meta.lcon;
    #y_vars =
    J = eval_jac(m, x)
    #@show size(J), length(x), length(y)
    g = w * grad(m.nlp, _cute_x(m, x))[_i_not_fixed(m.nlp)]
    return g - J' * y
    #+ jprod(m, x, y_cons) + y_vars
end

#=function ncon(m::Class_CUTEst)
    return length(m.bcon.l) + length(m.bcon.u)
end=#

#=function nvar(m::Class_CUTEst)
    return m.nlp.meta.nvar
end=#


function eval_lag_hess(m::Class_CUTEst, x::Array{Float64,1}, y::Array{Float64,1}, w::Float64)
    y_cons = zeros(m.nlp.meta.ncon)
    y_cons[m.bcon.l_i] -= y_l_con(y, m)
    y_cons[m.bcon.u_i] += y_u_con(y, m)

    H = hess(m.nlp, _cute_x(m, x), obj_weight=w, y=y_cons);

    ind = _i_not_fixed(m.nlp)
    return H[ind,ind]
end
