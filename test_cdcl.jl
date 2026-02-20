include("cdcl.jl")

using .DIMACS

# --- Load CNF from file ---
filename = "cnfs/cdcl_test.cnf"
cnf = DIMACS.load_cnf(filename)

println("Loaded CNF:")
println("  Variables: ", cnf.nvars)
println("  Clauses:   ", length(cnf.clauses))

# --- Initialize solver ---
S = Solver(cnf)

println("\nInitial model:")
println(S.model)

# --- Enqueue all unit clauses at level 0 ---
for (cid, clause) in enumerate(cnf.clauses)
    if length(clause.lits) == 1
        lit = clause.lits[1]
        println("Enqueueing unit literal ", lit, " from clause ", cid)
        enqueue!(S, lit, cid)
    end
end

println("\nTrail before propagation:")
println(S.trail)

# --- Run propagation ---
conflict = propagate!(S)

println("\nPropagation finished.")
println("Conflict clause id: ", conflict)

println("\nFinal trail:")
println(S.trail)

println("\nModel:")
println(S.model)

println("\nAntecedents:")
println(S.antecedent)

println("\nDecision levels:")
println(S.level)