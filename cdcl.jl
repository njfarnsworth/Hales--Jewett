include("parser.jl")
include("dpll.jl")
using .DIMACS

mutable struct Solver 
    # problem-specific
    nvars::Int
    clauses::Vector{Vector{Int}}

    # assignment state 
    model::Vector{Int8}
    level::Vector{Int} # decision level per variable (0 if unassigned)
    antecedent::Vector{Int} # clause implying assignment (0 if unassigned)

    # trail / decision stack
    trail::Vector{Int} # the variables that have been assigned
    trail_lim::Vector{Int} 
    qhead::Int 

    # watched literals
    watchlist::Vector{Vector{Int}} # counts the clauses watching a given literal
    watch1::Vector{Int} # per clause, index of watch1
    watch2::Vector{Int}  # per clause, index of watch2

end

@inline function want_value(lit::Int)::Int8
    # what assignment value makes this literal true
    return lit > 0 ? Int8(1) : Int8(-1)
end

@inline function value_lit(lit::Int, model::Vector{Int8})::Int8
    # what value of the variable does the binary assignment output 
    v = abs(lit)
    a = model[v]

    if a == 0 # unassigned
        return Int8(0)
    else
        return a == want_value(lit) ? Int8(1) : Int8(-1)
    end
end


function Solver(cnf::CNF)
    # initializes everything from the CNF for the solver
    n = cnf.nvars
    cls = Vector{Vector{Int}}(undef, length(cnf.clauses))

    for (i,c) in enumerate(cnf.clauses)
        cls[i] = copy(c.lits)
    end

    model = fill(Int8(0),n)
    level = fill(0,n)
    antecedent = fill(0,n)

    trail = Int[]
    trail_lim = Int[]
    qhead = 1

    watchlist = [Int[] for _ in 1:2n]
    watch1 = fill(0,length(cls))
    watch2 = fill(0,length(cls))

    for cid in 1:length(cls)
        c = cls[cid]
        if length(c) == 1
            watch1[cid] = 1
            watch2[cid] = 1
            push!(watchlist[lit_index(c[1])], cid)
        else
            watch1[cid] = 1
            watch2[cid] = 2
            push!(watchlist[lit_index(c[1])], cid)
            push!(watchlist[lit_index(c[2])], cid)
        end


    end


    return Solver(n,cls,model,level,antecedent,
    trail, trail_lim, qhead, watchlist, watch1, watch2)

end

@inline decision_level(S::Solver) = length(S.trail_lim) # returns the current decision level of the solver

function new_decision_level!(S::Solver)
    # makes the next position of the trail the start of a new decision level 
    push!(S.trail_lim, length(S.trail)+1)
    return nothing
end

function enqueue!(S::Solver, lit::Int, ant_cid::Int)::Bool
    # forces a lit to be true and updates solver accordingly
    v = abs(lit)
    want = want_value(lit)
    cur = S.model[v]

    if cur == 0 # if the literal is unassigned
        S.model[v] = want
        S.level[v] = decision_level(S)
        S.antecedent[v] = ant_cid
        push!(S.trail, lit) # add the literal to the trail
        return true
    else
        return cur == want 
    end
end

function backtrack!(S::Solver, lvl::Int)
    @assert 0 <= lvl <= decision_level(S) # check that the backtrack level is valid 

    # if lvl == 0, clear everything. else, clear everything past the end of lvl 
    if lvl == 0
        target_len = 0
    elseif lvl == decision_level(S)
        target_len = length(S.trail)
    else
        target_len = S.trail_lim[lvl + 1] - 1 # one before where the next level starts 
    end

    for i in length(S.trail):-1:(target_len+1) # inclusively iterate backwards from the end of the trail to one after the target
        lit = S.trail[i] # get the literal and corresponding variable 
        v = abs(lit)
        S.model[v] = Int8(0) # reset all of the stats for that variable 
        S.level[v] = 0
        S.antecedent[v] = 0
    end

    resize!(S.trail, target_len)
    resize!(S.trail_lim, lvl)
    S.qhead = min(S.qhead, length(S.trail)+1) # resets qhead if it is now in an illegal range

    return nothing

end

@inline function lit_index(lit::Int)::Int
    v = abs(lit)
    return 2v - (lit < 0 ? 0 : 1)

end

function propagate!(S::Solver)::Int

    while S.qhead <= length(S.trail) # while there are still literals to propagate
        lit = S.trail[S.qhead]
        S.qhead += 1

        false_lit = -1*lit
        wl_index = lit_index(false_lit)

        w = S.watchlist[wl_index] # w is the list of clauses watching false_lit
        i = 1
        while i <= length(w) # iterate through those clauses
            cid = w[i]
            c = S.clauses[cid] # get the clause 

            w1pos = S.watch1[cid] # get the watched literals from that clause 
            w2pos = S.watch2[cid]
            l1 = c[w1pos]
            l2 = c[w2pos]

            # determine whether w1 or w2 is watching false_lit
            if l1 == false_lit
                false_pos = w1pos
                other_pos = w2pos
                other_lit = l2
                other_is_w1 = false
            elseif l2 == false_lit
                false_pos = w2pos
                other_pos = w1pos
                other_lit = l1
                other_is_w1 = true
            else 
                w[i] = w[end] # swap pop
                pop!(w) 
                continue
            end

            if value_lit(other_lit, S.model) == Int8(1)
                # if the other lit is true, the clause is satisfied 
                i += 1
                continue 
            end

            # otherwise, try to find a new literal in the clause to watch instead of the false one
            found_replacement = false
            for k in 1:length(c)
                if k == false_pos || k == other_pos
                    continue
                end

                lk = c[k]
                if value_lit(lk, S.model) != Int8(-1) # if k is not currently false
                    if other_is_w1
                        S.watch2[cid] = k
                    else
                        S.watch1[cid] = k
                    end

                    w[i] = w[end] # remove that clause from that literal's watch list
                    pop!(w)

                    push!(S.watchlist[lit_index(lk)], cid) # add it to lk's watch list

                    found_replacement = true
                    break
                end
            end

            # no replacement found, clause is unit or conflicting
            other_val = value_lit(other_lit, S.model)
            if other_val == Int8(0) # unit clause, 
                if !enqueue!(S, other_lit, cid)
                    return cid # cid caused a conflict
                end
                i += 1 # otherwise, we're fine 
            else 
                return cid # other lit was also false
            end

        end
    end
end