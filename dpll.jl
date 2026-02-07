include("parser.jl")
using Random
using .DIMACS

cnf = load_cnf("exdimacs.cnf")

model = fill(Int8(0), cnf.nvars) # empty model

@inline lit_var(lit::Int) = abs(lit) # abs of a literal

@inline function lit_is_true(lit::Int, model::Vector{Int8})::Bool
    # determines whether a lit is true
    v = abs(lit)
    val = model[v]
    return (lit > 0 && val == 1 || lit < 0 && val == -1)
end

@inline function lit_is_false(lit::Int, model::Vector{Int8})::Bool
    # determines whether a lit is false
    v = abs(lit)
    val = model[v]
    return (lit > 0 && val == -1 || lit < 0 && val == 1)
end

@inline function assign_lit!(lit::Int, model::Vector{Int8})::Bool
    # can we assign this literal to be true without contradicting its current assignment?
    v = abs(lit)
    want::Int8 = lit > 0 ? Int8(1) : Int8(-1) # the value that we need for the lit to be true
    cur = model[v] # the value assigned to the lit

    if cur == 0 # if the lit isn't assigned a value yet
        model[v] = want
        return true
    else
        return cur == want
    end


end

function clause_status(lits::Vector{Int}, model::Vector{Int8})::Symbol
 # determines whether a clause is open, satisfied, or conflicting w the model
    any_unassigned = false
    for lit in lits # look for true, false, and unassigned literals 
        if lit_is_true(lit, model)
            return :sat
        elseif !lit_is_false(lit,model)
            any_unassigned = true 
        end
    end
    return any_unassigned ? :open : :conflict 
end

function formula_status(cnf::CNF, model::Vector{Int8})::Symbol
    any_open = false
    for c in cnf.clauses
        stat = clause_status(c.lits, model)
        if stat ==:conflict
            return :conflict
        elseif stat == :open
            any_open = true
        end
    end
    return any_open ? :open : :sat
end

function find_unit_literal(cnf::CNF, model::Vector{Int8})::Int
    for c in cnf.clauses
        stat = clause_status(c.lits, model)
        if stat == :sat; continue; end

        unassigned = 0
        candidate = 0

        for lit in c.lits
            # search for unary clause
            if lit_is_true(lit, model) 
                # clause already satisfied
                unassigned = 2
                break
            elseif !lit_is_false(lit, model)
                # clause not satisfied
                unassigned += 1
                candidate = lit
                if unassigned > 1
                    break
                end
            end   
        end

        if unassigned == 1
            return candidate # we found a unary clause
        end
    end
    return 0
end

function unit_propagate!(cnf::CNF, model::Vector{Int8})::Bool
    while true
        if formula_status(cnf, model) == :conflict
            return false
        end

        u = find_unit_literal(cnf, model)
        if u == 0
            return true
        end
        
        if !assign_lit!(u, model) # unable to assign the unary clause without causing conflict
            return false
        end
    end
end

function choose_random_literal(model::Vector{Int8}, nvars::Int)::Int
    unassigned = Int[]
    for v in 1:nvars
        if model[v] == 0
            push!(unassigned, v)
        end
    end

    isempty(unassigned) && return 0

    v = rand(unassigned)
    pol = rand(Bool) ? 1 : -1 

    return v * pol
end

function dpll(cnf::CNF, model::Vector{Int8})
    # runs the main algorithm
    if !unit_propagate!(cnf, model)
        # clause assignment failed immediately
        return false, nothing
    end

    # check status
    stat = formula_status(cnf, model)
    if stat == :sat
        return true, model
    elseif stat == :conflict
        return false, nothing
    end
    
    lit = choose_random_literal(model, cnf.nvars)
    if lit == 0
        return (stat == :sat), model
    end

    m1 = copy(model)
    if assign_lit!(lit, m1)
        sat, sol = dpll(cnf, m1)
        if sat
            return true, sol
        end
    end

    m2 = copy(model)
    if assign_lit!(-lit, m2)
        return dpll(cnf, m2)
    end
    return false, nothing
end

function check_model(cnf::CNF, model::Vector{Int8})::Bool
    # checks that a model actually satisfies the CNF 
    for c in cnf.clauses
        ok = false
        for lit in c.lits
            if lit_is_true(lit, model)
                ok = true
                break
            end
        end
        if !ok; return false; end
    end
    return true 
end

function find_pure_literal(cnf::CNF, model::Vector{Int8})::Int
    n = cnf.vars
    seen_pos = falses(n)
    seen_neg = falses(n)

    for c in cnf.clauses()
        if clause_status(c.lits, model) == :sat
            continue
        end
        for lit in lits
            v = abs(lit)
            if model[v] != 0 # variable already assigned, continue
                continue
            end
        end
    end
end