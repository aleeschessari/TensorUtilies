using ITensors

function assemble_sites(order::AbstractString, pools;
    rename=Dict{String,String}(),
)
    order = strip(order)

    function pool_get(var::String)
        if haskey(pools, var)
            return pools[var]
        elseif haskey(pools, Symbol(var))
            return pools[Symbol(var)]
        else
            error("No pool provided for variable '$var'")
        end
    end

    function parse_token(tok::AbstractString)
        m = match(r"^([A-Za-zωΩ]+)(\d+)$", tok)
        m === nothing && error("Invalid token '$tok' (expected like x3, y10, ω7, ...)")

        var = m.captures[1]
        n   = parse(Int, m.captures[2])

        var2 = get(rename, var, var)

        vpool = pool_get(var2)
        (1 <= n <= length(vpool)) || error("Index $n out of range for variable '$var2'")

        return vpool[n]
    end

    function tokenize_order(s::AbstractString)
        s = replace(s, "(" => " ( ", ")" => " ) ")
        return split(s)
    end

    function parse_block(toks::AbstractVector{<:AbstractString}, pos::Int)
        items = Index[]

        while pos <= length(toks)
            tok = toks[pos]

            if tok == ")"
                return Tuple(items), pos + 1
            elseif tok == "("
                subitems, pos = parse_block(toks, pos + 1)
                append!(items, subitems)
            else
                push!(items, parse_token(tok))
                pos += 1
            end
        end

        error("Unmatched '(' in order string")
    end

    toks = tokenize_order(order)
    isempty(toks) && return Index[]

    if !occursin(r"[()]", order)
        sites = Vector{Index}(undef, length(toks))

        for (i, tok) in enumerate(toks)
            sites[i] = parse_token(tok)
        end

        return sites
    end

    sites = Tuple[]
    pos = 1

    while pos <= length(toks)
        tok = toks[pos]

        if tok == "("
            grp, pos = parse_block(toks, pos + 1)
            push!(sites, grp)
        elseif tok == ")"
            error("Unmatched ')' in order string")
        else
            push!(sites, (parse_token(tok),))
            pos += 1
        end
    end

    return sites
end

function diagonal_mpo_from_mps_copy(y::MPS)
  N = length(y)
  Y = MPO(N)

  for n in 1:N
    Yn = y[n]

    # y[n] has a site index s; we create a primed "bra/ket" pair (s, s')
    s = siteind(y, n)
    sp = prime(s)

    # Replace y's site index by a new auxiliary index ω (same dim as s)
    ω = Index(dim(s), "ω,n=$n")
    Ynω = replaceinds(Yn, (s => ω))

    # Local COPY tensor δ(s, s', ω): 1 if s == s' == ω else 0
    # delta(i,j,k) in ITensors enforces equality of all three indices.
    copy = delta(s, sp, ω)

    # The MPO tensor has indices (links...) plus s and s'
    # Contract the COPY into Ynω to produce the diagonal MPO tensor
    Y[n] = copy * Ynω
  end

  return Y
end
