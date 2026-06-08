# x1 is the LSB of the first variable, bit counting is from the right (LSB)

_scheme_tokens(order::AbstractString) = split(replace(strip(order), "(" => " ", ")" => " "))

function ind_to_multi(index_array, R::Int, order::String)
    # 1) map variable name -> index value (0-based)
    vars = Dict(
        Char('x' + i - 1) => index_array[i] - 1
        for i in eachindex(index_array)
    )

    # 2) build bit tables (MSB..LSB in the string)
    bits = Dict{Char, Vector{Char}}()
    for (v, val) in vars
        bits[v] = collect(lpad(string(val, base=2), R, '0'))  # MSB..LSB
    end

    tokens = _scheme_tokens(order)

    out = Vector{Int}(undef, length(tokens))
    for (i, tok) in enumerate(tokens)
        v = tok[1]
        k = parse(Int, tok[2:end])  # k=1 means LSB now

        w = length(bits[v])
        k <= w || throw(ArgumentError("Token $tok asks for bit $k but $v only has $w bits"))

        pos = w - k + 1             # map LSB-indexed k -> MSB-indexed position
        out[i] = (bits[v][pos] - '0') + 1
    end

    return out
end


function ind_to_multi(index_array, R::AbstractVector{<:Integer}, order::String)
    n = length(index_array)
    length(R) == n || throw(ArgumentError("R must have same length as index_array"))

    varnames = [Char('x' + i - 1) for i in 1:n]

    vals   = Dict(varnames[i] => index_array[i] - 1 for i in 1:n)
    widths = Dict(varnames[i] => R[i] for i in 1:n)

    bits = Dict{Char, Vector{Char}}()
    for v in varnames
        w = widths[v]
        bits[v] = collect(lpad(string(vals[v], base=2), w, '0'))  # MSB..LSB
    end

    tokens = _scheme_tokens(order)

    out = Vector{Int}(undef, length(tokens))
    for (i, tok) in enumerate(tokens)
        v = tok[1]
        k = parse(Int, tok[2:end])  # k=1 means LSB now

        w = length(bits[v])
        k <= w || throw(ArgumentError("Token $tok asks for bit $k but $v only has $w bits"))

        pos = w - k + 1
        out[i] = (bits[v][pos] - '0') + 1
    end

    return out
end


function multi_to_ind(multi_array, R::Int, order::String)
    tokens = _scheme_tokens(order)
    length(multi_array) == length(tokens) || throw(ArgumentError("multi_array must have same length as split(order)"))

    vars_in_order = unique(tok[1] for tok in tokens)
    isempty(vars_in_order) && return Int[]

    n = maximum(Int(v) - Int('x') + 1 for v in vars_in_order)
    n > 0 || throw(ArgumentError("Could not infer number of variables from order"))
    varnames = [Char('x' + i - 1) for i in 1:n]

    bits = Dict(v => fill('0', R) for v in varnames)  # MSB..LSB

    for (i, tok) in enumerate(tokens)
        v = tok[1]
        k = parse(Int, tok[2:end])  # k=1 means LSB

        v in varnames || throw(ArgumentError("Token $tok refers to unknown variable $v"))
        1 <= k <= R || throw(ArgumentError("Token $tok asks for bit $k but $v only has $R bits"))

        b = multi_array[i]
        (b == 1 || b == 2) || throw(ArgumentError("multi_array entries must be 1 or 2"))

        pos = R - k + 1
        bits[v][pos] = Char('0' + (b - 1))
    end

    out = Vector{Int}(undef, n)
    for i in 1:n
        v = varnames[i]
        out[i] = parse(Int, String(bits[v]), base=2) + 1
    end

    return out
end


function multi_to_ind(multi_array, R::AbstractVector{<:Integer}, order::String)
    tokens = _scheme_tokens(order)
    length(multi_array) == length(tokens) || throw(ArgumentError("multi_array must have same length as split(order)"))

    n = length(R)
    varnames = [Char('x' + i - 1) for i in 1:n]
    widths = Dict(varnames[i] => R[i] for i in 1:n)

    bits = Dict(v => fill('0', widths[v]) for v in varnames)  # MSB..LSB

    for (i, tok) in enumerate(tokens)
        v = tok[1]
        k = parse(Int, tok[2:end])  # k=1 means LSB

        v in varnames || throw(ArgumentError("Token $tok refers to unknown variable $v"))
        w = widths[v]
        1 <= k <= w || throw(ArgumentError("Token $tok asks for bit $k but $v only has $w bits"))

        b = multi_array[i]
        (b == 1 || b == 2) || throw(ArgumentError("multi_array entries must be 1 or 2"))

        pos = w - k + 1
        bits[v][pos] = Char('0' + (b - 1))
    end

    out = Vector{Int}(undef, n)
    for i in 1:n
        v = varnames[i]
        out[i] = parse(Int, String(bits[v]), base=2) + 1
    end

    return out
end
