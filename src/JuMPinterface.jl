using MathProgBase
#using SparseArrays

########################################################
## this code is based on ModelReader in NLPModels
## and KNITRO.jl
########################################################

export OnePhaseSolver #, OnePhaseMathProgModel, NonlinearModel

mutable struct OnePhaseSolver <: MathProgBase.AbstractMathProgSolver
    options
end
OnePhaseSolver(;kwargs...) = OnePhaseSolver(kwargs)


mutable struct OnePhaseProblem
    status::Symbol  # Final status

    # For MathProgBase
    x::Vector{Float64}  # Starting and final solution
    lambda::Vector{Float64}
    g::Vector{Float64}  # Final constraint values
    obj_val::Float64  # (length 1) Final objective
    solve_time::Float64

    # Custom attributes of the OnePhaseSolver
    iter::Class_iterate
    hist::Array{alg_history2,1}
    pars::Class_parameters

    function OnePhaseProblem()
        return new()
    end
end

########################################################
## BEGIN ModelReader CODE (with minor edits)
########################################################

mutable struct OnePhaseMathProgModel <: MathProgBase.AbstractMathProgModel
  options
  inner::OnePhaseProblem

  eval :: Union{MathProgBase.AbstractNLPEvaluator, Nothing}
  numVar :: Int
  numConstr :: Int
  x :: Vector{Float64}
  y :: Vector{Float64}
  lvar :: Vector{Float64}
  uvar :: Vector{Float64}
  lcon :: Vector{Float64}
  ucon :: Vector{Float64}
  sense :: Symbol
  status :: Symbol
end



MathProgBase.NonlinearModel(solver :: OnePhaseSolver) = OnePhaseMathProgModel(solver.options,OnePhaseProblem(),nothing,
                                                                   0,
                                                                   0,
                                                                   Float64[],
                                                                   Float64[],
                                                                   Float64[],
                                                                   Float64[],
                                                                   Float64[],
                                                                   Float64[],
                                                                   :Min,
                                                                   :Uninitialized)

function MathProgBase.loadproblem!(m :: OnePhaseMathProgModel,
                                   numVar, numConstr,
                                   l, u, lb, ub,
                                   sense,
                                   eval :: MathProgBase.AbstractNLPEvaluator)

  # TODO: :JacVec is not yet available.
  # [:Grad, :Jac, :JacVec, :Hess, :HessVec, :ExprGraph]
  MathProgBase.initialize(eval, [:Grad, :Jac, :Hess, :HessVec, :ExprGraph])
  m.numVar = numVar
  m.numConstr = numConstr
  m.x = zeros(numVar)
  m.y = zeros(numConstr)
  m.eval = eval
  m.lvar = l
  m.uvar = u
  m.lcon = lb
  m.ucon = ub
  m.sense = sense
end

MathProgBase.setwarmstart!(m :: OnePhaseMathProgModel, x) = (m.x = x)
MathProgBase.status(m :: OnePhaseMathProgModel) = m.inner.status
MathProgBase.getsolution(m :: OnePhaseMathProgModel) = m.inner.x
MathProgBase.getobjval(m :: OnePhaseMathProgModel) = m.inner.iter.cache.fval
#MathProgBase.eval_f(m.eval, m.x)

mutable struct MathProgNLPModel <: AbstractNLPModel
  meta :: NLPModelMeta
  mpmodel :: OnePhaseMathProgModel
  counters :: Counters      # Evaluation counters.

  jrows :: Vector{Int}      # Jacobian sparsity pattern.
  jcols :: Vector{Int}
  jvals :: Vector{Float64}  # Room for the constraints Jacobian.

  hrows :: Vector{Int}      # Hessian sparsity pattern.
  hcols :: Vector{Int}
  hvals :: Vector{Float64}  # Room for the Lagrangian Hessian.
end

"Construct a `MathProgNLPModel` from a `OnePhaseMathProgModel`."
function MathProgNLPModel(mpmodel :: OnePhaseMathProgModel; name :: String="Generic")

  nvar = mpmodel.numVar
  lvar = mpmodel.lvar
  uvar = mpmodel.uvar

  nlin = length(mpmodel.eval.m.linconstr)         # Number of linear constraints.
  nquad = length(mpmodel.eval.m.quadconstr)       # Number of quadratic constraints.
  nnln = length(mpmodel.eval.m.nlpdata.nlconstr)  # Number of nonlinear constraints.
  ncon = mpmodel.numConstr                        # Total number of constraints.
  lcon = mpmodel.lcon
  ucon = mpmodel.ucon

  jrows, jcols = MathProgBase.jac_structure(mpmodel.eval)
  hrows, hcols = MathProgBase.hesslag_structure(mpmodel.eval)
  nnzj = length(jrows)
  nnzh = length(hrows)

  meta = NLPModelMeta(nvar,
                      x0=mpmodel.x,
                      lvar=lvar,
                      uvar=uvar,
                      ncon=ncon,
                      y0=zeros(ncon),
                      lcon=lcon,
                      ucon=ucon,
                      nnzj=nnzj,
                      nnzh=nnzh,
                      lin=collect(1:nlin),  # linear constraints appear first in MPB
                      nln=collect(nlin+1:ncon),
                      minimize=(mpmodel.sense == :Min),
                      islp=MathProgBase.isobjlinear(mpmodel.eval) & (nlin == ncon),
                      name=name,
                      )

  return MathProgNLPModel(meta,
                      mpmodel,
                      Counters(),
                      jrows,
                      jcols,
                      zeros(nnzj),  # jvals
                      hrows,
                      hcols,
                      zeros(nnzh),  # hvals
                      )
end

##
import Base.show
show(nlp :: MathProgNLPModel) = show(nlp.mpmodel)

function obj(nlp :: MathProgNLPModel, x :: Array{Float64})
  NLPModels.increment!(nlp, :neval_obj)
  return MathProgBase.eval_f(nlp.mpmodel.eval, x)
end

function grad(nlp :: MathProgNLPModel, x :: Array{Float64})
  g = zeros(nlp.meta.nvar)
  return grad!(nlp, x, g)
end

function grad!(nlp :: MathProgNLPModel, x :: Array{Float64}, g :: Array{Float64})
  NLPModels.increment!(nlp, :neval_grad)
  MathProgBase.eval_grad_f(nlp.mpmodel.eval, g, x)
  return g
end

function cons(nlp :: MathProgNLPModel, x :: Array{Float64})
  c = zeros(nlp.meta.ncon)
  return cons!(nlp, x, c)
end

function cons!(nlp :: MathProgNLPModel, x :: Array{Float64}, c :: Array{Float64})
  NLPModels.increment!(nlp, :neval_cons)
  MathProgBase.eval_g(nlp.mpmodel.eval, c, x)
  return c
end

function jac_coord(nlp :: MathProgNLPModel, x :: Array{Float64})
  NLPModels.increment!(nlp, :neval_jac)
  MathProgBase.eval_jac_g(nlp.mpmodel.eval, nlp.jvals, x)
  return (nlp.jrows, nlp.jcols, nlp.jvals)
end

function jac(nlp :: MathProgNLPModel, x :: Array{Float64})
  return SparseArrays.sparse(jac_coord(nlp, x)..., nlp.meta.ncon, nlp.meta.nvar)
end

function jprod(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64})
  Jv = zeros(nlp.meta.ncon)
  return jprod!(nlp, x, v, Jv)
end

function jprod!(nlp :: MathProgNLPModel,
                x :: Array{Float64},
                v :: Array{Float64},
                Jv :: Array{Float64})
  nlp.counters.neval_jac -= 1
  NLPModels.increment!(nlp, :neval_jprod)
  Jv[:] = jac(nlp, x) * v
  return Jv
end

function jtprod(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64})
  Jtv = zeros(nlp.meta.nvar)
  return jtprod!(nlp, x, v, Jtv)
end

function jtprod!(nlp :: MathProgNLPModel,
                x :: Array{Float64},
                v :: Array{Float64},
                Jtv :: Array{Float64})
  nlp.counters.neval_jac -= 1
  NLPModels.increment!(nlp, :neval_jtprod)
  Jtv[1:nlp.meta.nvar] = jac(nlp, x)' * v
  return Jtv
end

# Uncomment if/when :JacVec becomes available in MPB.
# "Evaluate the Jacobian-vector product at `x`."
# function jprod(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64})
#   jv = zeros(nlp.meta.ncon)
#   return jprod!(nlp, x, v, jv)
# end
#
# "Evaluate the Jacobian-vector product at `x` in place."
# function jprod!(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64}, jv :: Array{Float64})
#   NLPModels.increment!(nlp, :neval_jprod)
#   MathProgBase.eval_jac_prod(nlp.mpmodel.eval, jv, x, v)
#   return jv
# end
#
# "Evaluate the transposed-Jacobian-vector product at `x`."
# function jtprod(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64})
#   jtv = zeros(nlp.meta.nvar)
#   return jtprod!(nlp, x, v, jtv)
# end
#
# "Evaluate the transposed-Jacobian-vector product at `x` in place."
# function jtprod!(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64}, jtv :: Array{Float64})
#   NLPModels.increment!(nlp, :neval_jtprod)
#   MathProgBase.eval_jac_prod_t(nlp.mpmodel.eval, jtv, x, v)
#   return jtv
# end

function hess_coord(nlp :: MathProgNLPModel, x :: Array{Float64};
    obj_weight :: Float64=1.0, y :: Array{Float64}=zeros(nlp.meta.ncon))
  NLPModels.increment!(nlp, :neval_hess)
  MathProgBase.eval_hesslag(nlp.mpmodel.eval, nlp.hvals, x, obj_weight, y)
  return (nlp.hrows, nlp.hcols, nlp.hvals)
end

function hess(nlp :: MathProgNLPModel, x :: Array{Float64};
    obj_weight :: Float64=1.0, y :: Array{Float64}=zeros(nlp.meta.ncon))
  return SparseArrays.sparse(hess_coord(nlp, x, y=y, obj_weight=obj_weight)..., nlp.meta.nvar, nlp.meta.nvar)
end

function hprod(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64};
    obj_weight :: Float64=1.0, y :: Array{Float64}=zeros(nlp.meta.ncon))
  hv = zeros(nlp.meta.nvar)
  return hprod!(nlp, x, v, hv, obj_weight=obj_weight, y=y)
end

function hprod!(nlp :: MathProgNLPModel, x :: Array{Float64}, v :: Array{Float64},
    hv :: Array{Float64};
    obj_weight :: Float64=1.0, y :: Array{Float64}=zeros(nlp.meta.ncon))
  NLPModels.increment!(nlp, :neval_hprod)
  MathProgBase.eval_hesslag_prod(nlp.mpmodel.eval, hv, x, v, obj_weight, y)
  return hv
end

############################
## END ModelReader CODE
############################

function status_One_Phase_To_JuMP(status::Symbol)
    # since our status are not equal to JuMPs we need to do a conversion
    if status == :Optimal
        return :Optimal
    elseif status == :primal_infeasible
        return :Infeasible
    elseif status == :dual_infeasible
        return :Unbounded
    elseif status == :MAX_IT || status === :MAX_TIME
        return :UserLimit
    else
        return :Error
    end
end

function create_pars_JuMP(options )
    pars = Class_parameters()
    for (param,value) in options
      what = split(String(param),"!") # we represent a parameter such as init.mu_scale as init!mu_scale because we cannot pass init.mu_scale as a parameter
      node = pars # root
      for i in 1:length(what)
          field = what[i]
          if i < length(what)
              node = getfield(node,Symbol(field))
          else # at the leaf
              setfield!(node,Symbol(field),value)
          end
      end
    end

    return pars
end

function MathProgBase.optimize!(m :: OnePhaseMathProgModel)
    t = time()
    nlp = MathProgNLPModel(m)

    pars = create_pars_JuMP(m.options)

    iter, status, hist, t, err, timer = one_phase_solve(nlp,pars)

    m.inner.status = status_One_Phase_To_JuMP(status)
    m.inner.x = get_original_x(iter)
    m.inner.obj_val = iter.cache.fval
    m.inner.lambda = get_y(iter)
    m.inner.solve_time = time() - t

    # custom one phase features
    m.inner.pars = pars
    m.inner.iter = iter
    m.inner.hist = hist
end

MathProgBase.getconstrsolution(m::OnePhaseMathProgModel) = m.inner.g
MathProgBase.getrawsolver(m::OnePhaseMathProgModel) = m.inner
MathProgBase.getsolvetime(m::OnePhaseMathProgModel) = m.inner.solve_time

function MathProgBase.getreducedcosts(m::OnePhaseMathProgModel)
    return get_reducedcosts(m.inner.iter)
end

function MathProgBase.getconstrduals(m::OnePhaseMathProgModel)
    return get_constrduals(m.inner.iter)
end

#setvartype!(m::OnePhaseMathProgModel, typ::Vector{Symbol}) =
#    (m.varType = map(t->rev_var_type_map[t], typ))

function MathProgBase.freemodel!(m::OnePhaseMathProgModel)
    # TO DO
end
