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
    trail::Vector{Int} 
    trail_lim::Vector{Int}
    qhead::Int 
end

@inline function want_value(lit::Int)::Int8
    # what assignment value makes this literal true
    return lit > 0 ? Int8(1) : Int8(-1)
end

@inline function value_lit(lit::Int, model::Vector{Int8})::Int8
    # what value is the variable assigned 
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
    cls = Vector{Vector{Int}}(undef, length(cnf.nclauses))

    for (i,c) in enumerate(cnf.clauses)
        cls[i] = copy(c.lits)
    end

    model = fill(Int8(0),n)
    level = fill(0,n)
    antecedent = fill(0,n)

    trail = Int[]
    trail_lim = Int[]
    qhead = 1

    return Solver(n,cls,model,level,antecedent,trail,trail_lim,qhead)

end