# test_cdcl.jl
include("cdcl.jl")
using .DIMACS

function run_file(filename::String)
    # --- Load CNF from file ---
    cnf = DIMACS.load_cnf(filename)

    println("Loaded CNF:")
    println("  File:      ", filename)
    println("  Variables: ", cnf.nvars)
    println("  Clauses:   ", length(cnf.clauses))

    # --- Initialize solver ---
    S = Solver(cnf)

    println("\nInitial model:")
    println(S.model)

    # --- Root: enqueue all unit clauses at level 0 ---
    for (cid, c) in enumerate(S.clauses)   # note: S.clauses is Vector{Vector{Int}}
        if length(c) == 1
            lit = c[1]
            println("Enqueueing unit literal ", lit, " from clause ", cid)
            ok = enqueue!(S, lit, cid)
            if !ok
                println("\nContradiction while enqueueing unit clauses at level 0.")
                println("Result: UNSAT")
                return
            end
        end
    end

    println("\nTrail before propagation:")
    println(S.trail)

    # --- Root propagation ---
    conflict = propagate!(S)

    println("\nPropagation finished.")
    println("Conflict clause id: ", conflict)

    if conflict != 0
        println("\nConflict at level 0 ⇒ UNSAT")
        println("\nFinal trail:")
        println(S.trail)
        println("\nModel:")
        println(S.model)
        println("\nAntecedents:")
        println(S.antecedent)
        println("\nDecision levels:")
        println(S.level)
        return
    else
        println("\nNo conflict at level 0 ⇒ running solve_with_learning!()")
    end

    # --- Full solve (CDCL with learning) ---
    result = solve_with_learning!(S)

    println("\nResult: ", result)

    println("\nFinal trail:")
    println(S.trail)

    println("\nModel:")
    println(S.model)

    println("\nAntecedents:")
    println(S.antecedent)

    println("\nDecision levels:")
    println(S.level)

    println("\nTotal clauses after solving:")
    println(length(S.clauses))
end

run_file("cnfs/cdcl_test.cnf")