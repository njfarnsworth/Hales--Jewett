module VSIDS
# ADD EXPORTS AT THE END

mutable struct VSIDSState
    activity::Vector{Float64}
    var_inc::Float64
    decay::Float64
    max_tresh::Float64
end

function init_vsids(nvars::Int, decay::Float64 = 0.95, max_tresh::Float64 = 1e100)
    # initializes vsids for a solver with nvar variables 
    activity = zeros(Float64, nvars)
    return VSIDSState(activity, 1.0, decay, max_tresh)
end

@inline function bump_var!(V::VSIDSState, v::Int)
    # increase variable v by var_inc
    V.activity[v] += V.var_inc
end

@inline function decay!(V:VSIDSState)
    # apply decay after conflict to increase var_inc 
    V.var_inc /= V.decay
end

function maybe_rescale!(V::VSIDSState)
    # rescale activity & var_inc if numbers are becoming too big 
    if V.var_inc > V.max_tresh
        scale = 1e-100
        @inbounds for i in eachindex(V.activity)
            V.activity[i] *= scale
        end
        V.var_inc *= scale
    end
    return 
end

function bump_clause!(V::VSIDSState, clause::Vector{Int})
    # bump all lits in a learned clause and apply decay to increase
    @inbounds for lit in clause
        v = abs(lit)
        bump_var!(V, v)
    end
    decay!(V)
    maybe_rescale!(V)
    return nothing
end

function pick_branch_var(V::VSIDSState, model::Vector{Int8})::Int
    # picks the unassigned var with the max activity
    best_v = 0
    best_a = -Inf

    @inbounds for v in 1:length(model)
        if model[v] == Int8(0)
            a = V.activity[v]
            if a > best_a
                best_a = a
                best_v = v
            end
        end
    end
    return best_v
end

end