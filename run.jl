using BenchmarkTools
include("dpll.jl")

println("cnf loading...")

cnf = load_cnf("unsat.cnf")

DPLL_NODES[] = 0
DPLL_DECISIONS[] = 0

println("running SAT solver for time")

@btime dpll($cnf, zeros(Int8, $cnf.nvars))

println("running SAT solver for tree depth")

DPLL_NODES[] = 0
DPLL_DECISIONS[] = 0

sat, sol = dpll(cnf, zeros(Int8, cnf.nvars))


println("sat=$sat nodes=$(DPLL_NODES[]) decisions=$(DPLL_DECISIONS[])")