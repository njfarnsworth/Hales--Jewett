module DIMACS

export Clause, CNF, load_cnf


struct Clause
    lits::Vector{Int}
end

struct CNF
    nvars::Int
    nclauses::Int
    clauses::Vector{Clause}
end

function tokenize_dimacs(s::AbstractString)::Vector{String}
    tokens = String[]
    for rawline in eachline(IOBuffer(s))
        line = lstrip(rawline)

        if !isempty(line) && first(line) == 'c'
            continue
        end

        for tok in split(line)
            push!(tokens, tok)
        end
    end
    return tokens
end

function parse_header(tokens::Vector{String})::Tuple{Int, Int, Int}
    i = 1

    if i > length(tokens) || tokens[i] != "p"
        error("Error: Expected 'p' for header line")
    end
    i += 1

    if i > length(tokens) || tokens[i] != "cnf"
        error("Error: Malformed header line, missing 'cnf'")
    end

    i += 1

    if i > length(tokens)
        error("Error: Missing nvars in header")
    end

    nvars = parse(Int, tokens[i])
    i += 1

    if i > length(tokens)
        error("Error: Missing nclauses in header")
    end

    nclauses = parse(Int, tokens[i])
    i += 1

    return nvars, nclauses, i
end

function parse_clause(tokens::Vector{String}, i::Int)::Tuple{Clause, Int}
    lits = Int[]
    while true
        if i > length(tokens)
            error("Unexpected end of file while reading clause")
        end
        lit = parse(Int, tokens[i])
        i += 1
        if lit == 0
            break
        end
        push!(lits, lit)
    end
    return Clause(lits), i
end

function parse_cnf_from_string(s::AbstractString)::CNF
    tokens = tokenize_dimacs(s)
    nvars, nclauses, i = parse_header(tokens)
    clauses = Vector{Clause}(undef, nclauses)

    for k in 1:nclauses
        c, i = parse_clause(tokens, i)
        for lit in c.lits
            v = abs(lit)
            if v < 1 || v > nvars
                error("Error: Invalid literal value")
            end
        end

        clauses[k] = c
    end

    return CNF(nvars, nclauses, clauses)
end

function load_cnf(path::AbstractString)::CNF
    s = read(path, String)
    return parse_cnf_from_string(s)
end


end 
