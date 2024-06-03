### Reaction Complex Handling ###

# get the species indices and stoichiometry while filtering out constant species.
function filter_constspecs(specs, stoich::AbstractVector{V}, smap) where {V <: Integer}
    isempty(specs) && (return Vector{Int}(), Vector{V}())

    # If any species are constant, go through these manually and add their indices and 
    # stoichiometries to `ids` and `filtered_stoich`.
    if any(isconstant, specs)
        ids = Vector{Int}()
        filtered_stoich = Vector{V}()
        for (i, s) in enumerate(specs)
            if !isconstant(s)
                push!(ids, smap[s])
                push!(filtered_stoich, stoich[i])
            end
        end
    else
        ids = map(Base.Fix1(getindex, smap), specs)
        filtered_stoich = copy(stoich)
    end
    ids, filtered_stoich
end

"""
    reactioncomplexmap(rn::ReactionSystem)

Find each [`ReactionComplex`](@ref) within the specified system, constructing a mapping from
the complex to vectors that indicate which reactions it appears in as substrates and
products.

Notes:
- Each [`ReactionComplex`](@ref) is mapped to a vector of pairs, with each pair having the
  form `reactionidx => ± 1`, where `-1` indicates the complex appears as a substrate and
  `+1` as a product in the reaction with integer label `reactionidx`.
- Constant species are ignored as part of a complex. i.e. if species `A` is constant then
  the reaction `A + B --> C + D` is considered to consist of the complexes `B` and `C + D`.
  Likewise `A --> B` would be treated as the same as `0 --> B`.
"""
function reactioncomplexmap(rn::ReactionSystem)
    isempty(get_systems(rn)) ||
        error("reactioncomplexmap does not currently support subsystems.")

    # check if previously calculated and hence cached
    nps = get_networkproperties(rn)
    !isempty(nps.complextorxsmap) && return nps.complextorxsmap
    complextorxsmap = nps.complextorxsmap

    # Retrieves system reactions and a map from species to their index in the species vector.
    rxs = reactions(rn)
    smap = speciesmap(rn)
    numreactions(rn) > 0 ||
        error("There must be at least one reaction to find reaction complexes.")

    for (i, rx) in enumerate(rxs)
        # Create the `ReactionComplex` corresponding to the reaction's substrates. Adds it 
        # to the reaction complex dictionary (recording it as the substrates of the i'th reaction). 
        subids, substoich = filter_constspecs(rx.substrates, rx.substoich, smap)
        subrc = sort!(ReactionComplex(subids, substoich))
        if haskey(complextorxsmap, subrc)
            push!(complextorxsmap[subrc], i => -1)
        else
            complextorxsmap[subrc] = [i => -1]
        end

        # Create the `ReactionComplex` corresponding to the reaction's products. Adds it 
        # to the reaction complex dictionary (recording it as the products of the i'th reaction). 
        prodids, prodstoich = filter_constspecs(rx.products, rx.prodstoich, smap)
        prodrc = sort!(ReactionComplex(prodids, prodstoich))
        if haskey(complextorxsmap, prodrc)
            push!(complextorxsmap[prodrc], i => 1)
        else
            complextorxsmap[prodrc] = [i => 1]
        end
    end
    complextorxsmap
end

@doc raw"""
    reactioncomplexes(network::ReactionSystem; sparse=false)

Calculate the reaction complexes and complex incidence matrix for the given
[`ReactionSystem`](@ref).

Notes:
- returns a pair of a vector of [`ReactionComplex`](@ref)s and the complex incidence matrix.
- An empty [`ReactionComplex`](@ref) denotes the null (∅) state (from reactions like ∅ -> A
  or A -> ∅).
- Constant species are ignored in generating a reaction complex. i.e. if A is constant then
  A --> B consists of the complexes ∅ and B.
- The complex incidence matrix, ``B``, is number of complexes by number of reactions with
```math
B_{i j} = \begin{cases}
-1, &\text{if the i'th complex is the substrate of the j'th reaction},\\
1, &\text{if the i'th complex is the product of the j'th reaction},\\
0, &\text{otherwise.}
\end{cases}
```
- Set sparse=true for a sparse matrix representation of the incidence matrix
"""
function reactioncomplexes(rn::ReactionSystem; sparse = false)
    isempty(get_systems(rn)) ||
        error("reactioncomplexes does not currently support subsystems.")
    nps = get_networkproperties(rn)

    # If the complexes have not been cached, or the cached complexes uses a different sparsity.
    if isempty(nps.complexes) || (sparse != issparse(nps.complexes))
        # Computes the reaction complex dictionary. Use it to create a sparse/dense matrix.
        complextorxsmap = reactioncomplexmap(rn)
        nps.complexes, nps.incidencemat = if sparse
            reactioncomplexes(SparseMatrixCSC{Int, Int}, rn, complextorxsmap)
        else
            reactioncomplexes(Matrix{Int}, rn, complextorxsmap)
        end
    end
    nps.complexes, nps.incidencemat
end

# Creates a *sparse* reaction complex matrix.
function reactioncomplexes(::Type{SparseMatrixCSC{Int, Int}}, rn::ReactionSystem,
                           complextorxsmap)
    # Computes the I, J, and V vectors used for the sparse matrix (read about sparse matrix 
    # representation for more information).
    complexes = collect(keys(complextorxsmap))
    Is = Int[]
    Js = Int[]
    Vs = Int[]
    for (i, c) in enumerate(complexes)
        for (j, σ) in complextorxsmap[c]
            push!(Is, i)
            push!(Js, j)
            push!(Vs, σ)
        end
    end
    B = sparse(Is, Js, Vs, length(complexes), numreactions(rn))
    complexes, B
end

# Creates a *dense* reaction complex matrix.
function reactioncomplexes(::Type{Matrix{Int}}, rn::ReactionSystem, complextorxsmap)
    complexes = collect(keys(complextorxsmap))
    B = zeros(Int, length(complexes), numreactions(rn))
    for (i, c) in enumerate(complexes)
        for (j, σ) in complextorxsmap[c]
            B[i, j] = σ
        end
    end
    complexes, B
end

"""
    incidencemat(rn::ReactionSystem; sparse=false)

Calculate the incidence matrix of `rn`, see [`reactioncomplexes`](@ref).

Notes:
- Is cached in `rn` so that future calls, assuming the same sparsity, will also be fast.
"""
incidencemat(rn::ReactionSystem; sparse = false) = reactioncomplexes(rn; sparse)[2]

"""
    complexstoichmat(network::ReactionSystem; sparse=false)

Given a [`ReactionSystem`](@ref) and vector of reaction complexes, return a
matrix with positive entries of size number of species by number of complexes,
where the non-zero positive entries in the kth column denote stoichiometric
coefficients of the species participating in the kth reaction complex.

Notes:
- Set sparse=true for a sparse matrix representation
"""
function complexstoichmat(rn::ReactionSystem; sparse = false)
    isempty(get_systems(rn)) ||
        error("complexstoichmat does not currently support subsystems.")
    nps = get_networkproperties(rn)

    # If the complexes stoichiometry matrix has not been cached, or the cached one uses a
    # different sparsity, computes (and caches) it.
    if isempty(nps.complexstoichmat) || (sparse != issparse(nps.complexstoichmat))
        nps.complexstoichmat = if sparse
            complexstoichmat(SparseMatrixCSC{Int, Int}, rn, keys(reactioncomplexmap(rn)))
        else
            complexstoichmat(Matrix{Int}, rn, keys(reactioncomplexmap(rn)))
        end
    end
    nps.complexstoichmat
end

# Creates a *sparse* reaction complex stoichiometry matrix.
function complexstoichmat(::Type{SparseMatrixCSC{Int, Int}}, rn::ReactionSystem, rcs)
    # Computes the I, J, and V vectors used for the sparse matrix (read about sparse matrix 
    # representation for more information).
    Is = Int[]
    Js = Int[]
    Vs = Int[]
    for (i, rc) in enumerate(rcs)
        for rcel in rc
            push!(Is, rcel.speciesid)
            push!(Js, i)
            push!(Vs, rcel.speciesstoich)
        end
    end
    Z = sparse(Is, Js, Vs, numspecies(rn), length(rcs))
end

# Creates a *dense* reaction complex stoichiometry matrix.
function complexstoichmat(::Type{Matrix{Int}}, rn::ReactionSystem, rcs)
    Z = zeros(Int, numspecies(rn), length(rcs))
    for (i, rc) in enumerate(rcs)
        for rcel in rc
            Z[rcel.speciesid, i] = rcel.speciesstoich
        end
    end
    Z
end

@doc raw"""
    complexoutgoingmat(network::ReactionSystem; sparse=false)

Given a [`ReactionSystem`](@ref) and complex incidence matrix, ``B``, return a
matrix of size num of complexes by num of reactions that identifies substrate
complexes.

Notes:
- The complex outgoing matrix, ``\Delta``, is defined by
```math
\Delta_{i j} = \begin{cases}
    = 0,    &\text{if } B_{i j} = 1, \\
    = B_{i j}, &\text{otherwise.}
\end{cases}
```
- Set sparse=true for a sparse matrix representation
"""
function complexoutgoingmat(rn::ReactionSystem; sparse = false)
    isempty(get_systems(rn)) ||
        error("complexoutgoingmat does not currently support subsystems.")
    nps = get_networkproperties(rn)

    # If the outgoing complexes matrix has not been cached, or the cached one uses a
    # different sparsity, computes (and caches) it.
    if isempty(nps.complexoutgoingmat) || (sparse != issparse(nps.complexoutgoingmat))
        B = reactioncomplexes(rn, sparse = sparse)[2]
        nps.complexoutgoingmat = if sparse
            complexoutgoingmat(SparseMatrixCSC{Int, Int}, rn, B)
        else
            complexoutgoingmat(Matrix{Int}, rn, B)
        end
    end
    nps.complexoutgoingmat
end

# Creates a *sparse* outgoing reaction complex stoichiometry matrix.
function complexoutgoingmat(::Type{SparseMatrixCSC{Int, Int}}, rn::ReactionSystem, B)
    # Computes the I, J, and V vectors used for the sparse matrix (read about sparse matrix 
    # representation for more information).
    n = size(B, 2)
    rows = rowvals(B)
    vals = nonzeros(B)
    Is = Int[]
    Js = Int[]
    Vs = Int[]

    # Allocates space to the vectors (so that it is not done incrementally in the loop). 
    sizehint!(Is, div(length(vals), 2))
    sizehint!(Js, div(length(vals), 2))
    sizehint!(Vs, div(length(vals), 2))

    for j in 1:n
        for i in nzrange(B, j)
            if vals[i] != one(eltype(vals))
                push!(Is, rows[i])
                push!(Js, j)
                push!(Vs, vals[i])
            end
        end
    end
    sparse(Is, Js, Vs, size(B, 1), size(B, 2))
end

# Creates a *dense* outgoing reaction complex stoichiometry matrix.
function complexoutgoingmat(::Type{Matrix{Int}}, rn::ReactionSystem, B)
    Δ = copy(B)
    for (I, b) in pairs(Δ)
        (b == 1) && (Δ[I] = 0)
    end
    Δ
end

"""
    incidencematgraph(rn::ReactionSystem)

Construct a directed simple graph where nodes correspond to reaction complexes and directed
edges to reactions converting between two complexes.

Notes:
- Requires the `incidencemat` to already be cached in `rn` by a previous call to
  `reactioncomplexes`.

For example,
```julia
sir = @reaction_network SIR begin
    β, S + I --> 2I
    ν, I --> R
end
complexes,incidencemat = reactioncomplexes(sir)
incidencematgraph(sir)
```
"""
function incidencematgraph(rn::ReactionSystem)
    nps = get_networkproperties(rn)
    if Graphs.nv(nps.incidencegraph) == 0
        isempty(nps.incidencemat) &&
            error("Please call reactioncomplexes(rn) first to construct the incidence matrix.")
        nps.incidencegraph = incidencematgraph(nps.incidencemat)
    end
    nps.incidencegraph
end

# Computes the incidence graph from an *dense* incidence matrix.
function incidencematgraph(incidencemat::Matrix{Int})
    @assert all(∈([-1, 0, 1]), incidencemat)
    n = size(incidencemat, 1)  # no. of nodes/complexes
    graph = Graphs.DiGraph(n)

    # Walks through each column (corresponds to reactions). For each, find the input and output
    # complex and add an edge representing these to the incidence graph.
    for col in eachcol(incidencemat)
        src = 0
        dst = 0
        for i in eachindex(col)
            (col[i] == -1) && (src = i)
            (col[i] == 1) && (dst = i)
            (src != 0) && (dst != 0) && break
        end
        Graphs.add_edge!(graph, src, dst)
    end
    return graph
end

# Computes the incidence graph from an *sparse* incidence matrix.
function incidencematgraph(incidencemat::SparseMatrixCSC{Int, Int})
    @assert all(∈([-1, 0, 1]), incidencemat)
    m, n = size(incidencemat)
    graph = Graphs.DiGraph(m)
    rows = rowvals(incidencemat)
    vals = nonzeros(incidencemat)

    # Loops through the (n) columns. For each column, directly find the index of the input
    # and output complex and add an edge representing these to the incidence graph.
    for j in 1:n
        inds = nzrange(incidencemat, j)
        row = rows[inds]
        val = vals[inds]
        if val[1] == -1
            Graphs.add_edge!(graph, row[1], row[2])
        else
            Graphs.add_edge!(graph, row[2], row[1])
        end
    end
    return graph
end


### Linkage, Deficiency, Reversibility ###

"""
    linkageclasses(rn::ReactionSystem)

Given the incidence graph of a reaction network, return a vector of the
connected components of the graph (i.e. sub-groups of reaction complexes that
are connected in the incidence graph).

Notes:
- Requires the `incidencemat` to already be cached in `rn` by a previous call to
  `reactioncomplexes`.

For example,
```julia
sir = @reaction_network SIR begin
    β, S + I --> 2I
    ν, I --> R
end
complexes,incidencemat = reactioncomplexes(sir)
linkageclasses(sir)
```
gives
```julia
2-element Vector{Vector{Int64}}:
 [1, 2]
 [3, 4]
```
"""
function linkageclasses(rn::ReactionSystem)
    nps = get_networkproperties(rn)
    if isempty(nps.linkageclasses)
        nps.linkageclasses = linkageclasses(incidencematgraph(rn))
    end
    nps.linkageclasses
end

linkageclasses(incidencegraph) = Graphs.connected_components(incidencegraph)

@doc raw"""
    deficiency(rn::ReactionSystem)

Calculate the deficiency of a reaction network.

Here the deficiency, ``\delta``, of a network with ``n`` reaction complexes,
``\ell`` linkage classes and a rank ``s`` stoichiometric matrix is

```math
\delta = n - \ell - s
```

Notes:
- Requires the `incidencemat` to already be cached in `rn` by a previous call to
  `reactioncomplexes`.

For example,
```julia
sir = @reaction_network SIR begin
    β, S + I --> 2I
    ν, I --> R
end
rcs,incidencemat = reactioncomplexes(sir)
δ = deficiency(sir)
```
"""
function deficiency(rn::ReactionSystem)
    # Precomputes required information. `conservationlaws` caches the conservation laws in `rn`.
    nps = get_networkproperties(rn)
    conservationlaws(rn)
    r = nps.rank
    ig = incidencematgraph(rn)
    lc = linkageclasses(rn)

    # Computes deficiency using its formula. Caches and returns it as output.
    nps.deficiency = Graphs.nv(ig) - length(lc) - r
    nps.deficiency
end

# For a linkage class (set of reaction complexes that form an isolated sub-graph), and some
# additional information of the full network, find the reactions, species, and parameters 
# that constitute the corresponding sub-reaction network.
function subnetworkmapping(linkageclass, allrxs, complextorxsmap, p)
    # Finds the reactions that are part of teh sub-reaction network.
    rxinds = sort!(collect(Set(rxidx for rcidx in linkageclass
                               for rxidx in complextorxsmap[rcidx])))
    newrxs = allrxs[rxinds]

    # Find the species that are part of the sub-reaction network.
    specset = Set(s for rx in newrxs for s in rx.substrates if !isconstant(s))
    for rx in newrxs
        for product in rx.products
            !isconstant(product) && push!(specset, product)
        end
    end
    newspecs = collect(specset)

    # Find the parameters that are part of the sub-reaction network.
    newps = Vector{eltype(p)}()
    for rx in newrxs
        Symbolics.get_variables!(newps, rx.rate, p)
    end

    newrxs, newspecs, newps
end

"""
    subnetworks(rn::ReactionSystem)

Find subnetworks corresponding to each linkage class of the reaction network.

Notes:
- Requires the `incidencemat` to already be cached in `rn` by a previous call to
  `reactioncomplexes`.

For example,
```julia
sir = @reaction_network SIR begin
    β, S + I --> 2I
    ν, I --> R
end
complexes,incidencemat = reactioncomplexes(sir)
subnetworks(sir)
```
"""
function subnetworks(rs::ReactionSystem)
    isempty(get_systems(rs)) || error("subnetworks does not currently support subsystems.")

    # Retrieves required components. `linkageclasses` caches linkage classes in `rs`.
    lcs = linkageclasses(rs)
    rxs = reactions(rs)
    p = parameters(rs)
    t = get_iv(rs)
    spatial_ivs = get_sivs(rs)
    complextorxsmap = [map(first, rcmap) for rcmap in values(reactioncomplexmap(rs))]
    subnetworks = Vector{ReactionSystem}()

    # Loops through each sub-graph of connected reaction complexes. For each, create a 
    # new `ReactionSystem` model and pushes it to the subnetworks vector.
    for i in 1:length(lcs)
        newrxs, newspecs, newps = subnetworkmapping(lcs[i], rxs, complextorxsmap, p)
        newname = Symbol(nameof(rs), "_", i)
        push!(subnetworks,
              ReactionSystem(newrxs, t, newspecs, newps; name = newname, spatial_ivs))
    end
    subnetworks
end

"""
    linkagedeficiencies(network::ReactionSystem)

Calculates the deficiency of each sub-reaction network within `network`.

Notes:
- Requires the `incidencemat` to already be cached in `rn` by a previous call to
  `reactioncomplexes`.

For example,
```julia
sir = @reaction_network SIR begin
    β, S + I --> 2I
    ν, I --> R
end
rcs,incidencemat = reactioncomplexes(sir)
linkage_deficiencies = linkagedeficiencies(sir)
```
"""
function linkagedeficiencies(rs::ReactionSystem)
    lcs = linkageclasses(rs)
    subnets = subnetworks(rs)
    δ = zeros(Int, length(lcs))

    # For each sub-reaction network of the reaction network, compute its deficiency. Returns
    # the full vector of deficiencies for each sub-reaction network.
    for (i, subnet) in enumerate(subnets)
        conservationlaws(subnet)
        nps = get_networkproperties(subnet)
        δ[i] = length(lcs[i]) - 1 - nps.rank
    end
    δ
end

"""
    isreversible(rn::ReactionSystem)

Given a reaction network, returns if the network is reversible or not.

Notes:
- Requires the `incidencemat` to already be cached in `rn` by a previous call to
  `reactioncomplexes`.

For example,
```julia
sir = @reaction_network SIR begin
    β, S + I --> 2I
    ν, I --> R
end
rcs,incidencemat = reactioncomplexes(sir)
isreversible(sir)
```
"""
function isreversible(rn::ReactionSystem)
    ig = incidencematgraph(rn)
    Graphs.reverse(ig) == ig
end

"""
    isweaklyreversible(rn::ReactionSystem, subnetworks)

Determine if the reaction network with the given subnetworks is weakly reversible or not.

Notes:
- Requires the `incidencemat` to already be cached in `rn` by a previous call to
  `reactioncomplexes`.

For example,
```julia
sir = @reaction_network SIR begin
    β, S + I --> 2I
    ν, I --> R
end
rcs,incidencemat = reactioncomplexes(sir)
subnets = subnetworks(rn)
isweaklyreversible(rn, subnets)
```
"""
function isweaklyreversible(rn::ReactionSystem, subnets)
    im = get_networkproperties(rn).incidencemat
    isempty(im) &&
        error("Error, please call reactioncomplexes(rn::ReactionSystem) to ensure the incidence matrix has been cached.")

    # For each sub-reaction network, caches its reaction complexes.
    sparseig = issparse(im)
    for subnet in subnets
        nps = get_networkproperties(subnet)
        isempty(nps.incidencemat) && reactioncomplexes(subnet; sparse = sparseig)
    end

    # the network is weakly reversible if each sub-network's incidenc graph is strongl 
    # connec (i.e. each node is reachable from each node).
    all(Graphs.is_strongly_connected ∘ incidencematgraph, subnets)
end


### Conservation Laws ###

# Implements the `conserved` parameter metadata.
struct ConservedParameter end
Symbolics.option_to_metadata_type(::Val{:conserved}) = ConservedParameter

"""
isconserved(p)

Checks if the input parameter (`p`) is a conserved quantity (i.e. have the `conserved`)
metadata.
"""
isconserved(x::Num, args...) = isconserved(Symbolics.unwrap(x), args...)
function isconserved(x, default = false)
    p = Symbolics.getparent(x, nothing)
    p === nothing || (x = p)
    Symbolics.getmetadata(x, ConservedParameter, default)
end

"""
    conservedequations(rn::ReactionSystem)

Calculate symbolic equations from conservation laws, writing dependent variables as
functions of independent variables and the conservation law constants.

Notes:
- Caches the resulting equations in `rn`, so will be fast on subsequent calls.

Examples:
```@repl
rn = @reaction_network begin
    k, A + B --> C
    k2, C --> A + B
    end
conservedequations(rn)
```
gives
```
2-element Vector{Equation}:
 B(t) ~ A(t) + Γ[1]
 C(t) ~ Γ[2] - A(t)
```
"""
function conservedequations(rn::ReactionSystem)
    conservationlaws(rn)
    nps = get_networkproperties(rn)
    nps.conservedeqs
end

"""
    conservationlaw_constants(rn::ReactionSystem)

Calculate symbolic equations from conservation laws, writing the conservation law constants
in terms of the dependent and independent variables.

Notes:
- Caches the resulting equations in `rn`, so will be fast on subsequent calls.

Examples:
```@julia
rn = @reaction_network begin
    k, A + B --> C
    k2, C --> A + B
    end
conservationlaw_constants(rn)
```
gives
```
2-element Vector{Equation}:
 Γ[1] ~ B(t) - A(t)
 Γ[2] ~ A(t) + C(t)
```
"""
function conservationlaw_constants(rn::ReactionSystem)
    conservationlaws(rn)
    nps = get_networkproperties(rn)
    nps.constantdefs
end

"""
    conservationlaws(netstoichmat::AbstractMatrix)::Matrix

Given the net stoichiometry matrix of a reaction system, computes a matrix of
conservation laws, each represented as a row in the output.
"""
function conservationlaws(nsm::T; col_order = nothing) where {T <: AbstractMatrix}

    # compute the left nullspace over the integers
    N = MT.nullspace(nsm'; col_order)

    # if all coefficients for a conservation law are negative, make positive
    for Nrow in eachcol(N)
        all(r -> r <= 0, Nrow) && (Nrow .*= -1)
    end

    # check we haven't overflowed
    iszero(N' * nsm) || error("Calculation of the conservation law matrix was inaccurate, "
          * "likely due to numerical overflow. Please use a larger integer "
          * "type like Int128 or BigInt for the net stoichiometry matrix.")

    T(N')
end

# Used in the subsequent function.
function cache_conservationlaw_eqs!(rn::ReactionSystem, N::AbstractMatrix, col_order)
    # Retrieves nullity (the number of conservation laws). `r` is the rank of the netstoichmat.
    nullity = size(N, 1)
    r = numspecies(rn) - nullity

    # Creates vectors of all independent and dependent species (those that are not, and are, 
    # eliminated by the conservation laws). Get vectors both with their indexes and the actual
    # species symbolic variables.
    sps = species(rn)
    indepidxs = col_order[begin:r]
    indepspecs = sps[indepidxs]
    depidxs = col_order[(r + 1):end]
    depspecs = sps[depidxs]

    # Declares the conservation law parameters.
    constants = MT.unwrap.(MT.scalarize(only(
                @parameters $(CONSERVED_CONSTANT_SYMBOL)[1:nullity] [conserved=true])))

    # Computes the equations for (examples uses simple two-state system, `X1 <--> X2`):
    # - The species eliminated through conservation laws (`conservedeqs`). E.g. `[X2 ~ X1 - Γ[1]]`.
    # - The conserved quantity parameters (`constantdefs`). E.g. `[Γ[1] ~ X1 + X2]`.
    conservedeqs = Equation[]
    constantdefs = Equation[]

    # For each conserved quantity.
    for (i, depidx) in enumerate(depidxs)
        # Finds the coefficient (in the conservation law) of the species that is eliminated
        # by this conservation law.
        scaleby = (N[i, depidx] != 1) ? N[i, depidx] : one(eltype(N))
        (scaleby != 0) || error("Error, found a zero in the conservation law matrix where "
            * "one was not expected.")

        # Creates, for this conservation law, the sum of all independent species (weighted by
        # the ratio between the coefficient of the species and the species which is elimianted.
        coefs = @view N[i, indepidxs]
        terms = sum((coef, sp) -> coef / scaleby * sp, zip(coefs, indepspecs))

        # Computes the two equations corresponding to this conserved quantity.
        eq = depspecs[i] ~ constants[i] - terms
        push!(conservedeqs, eq)
        eq = constants[i] ~ depspecs[i] + terms
        push!(constantdefs, eq)
    end

    # cache in the system
    nps = get_networkproperties(rn)
    nps.rank = r
    nps.nullity = nullity
    nps.indepspecs = Set(indepspecs)
    nps.depspecs = Set(depspecs)
    nps.conservedeqs = conservedeqs
    nps.constantdefs = constantdefs

    nothing
end

"""
    conservationlaws(rs::ReactionSystem)

Return the conservation law matrix of the given `ReactionSystem`, calculating it if it is
not already stored within the system, or returning an alias to it.

Notes:
- The first time being called it is calculated and cached in `rn`, subsequent calls should
  be fast.
"""
function conservationlaws(rs::ReactionSystem)
    nps = get_networkproperties(rs)
    !isempty(nps.conservationmat) && (return nps.conservationmat)

    # If the conservation law matrix is not computed, do so and caches the result.
    nsm = netstoichmat(rs)
    nps.conservationmat = conservationlaws(nsm; col_order = nps.col_order)
    cache_conservationlaw_eqs!(rs, nps.conservationmat, nps.col_order)
    nps.conservationmat
end

"""
    conservedquantities(state, cons_laws)

Compute conserved quantities for a system with the given conservation laws.
"""
conservedquantities(state, cons_laws) = cons_laws * state

# If u0s are not given while conservation laws are present, throw an error.
# Used in HomotopyContinuation and BifurcationKit extensions.
# Currently only checks if any u0s are given (not whether these are enough for computing
# conserved quantities, this will yield a less informative error).
function conservationlaw_errorcheck(rs, pre_varmap)
    vars_with_vals = Set(p[1] for p in pre_varmap)
    any(sp -> sp in vars_with_vals, species(rs)) && return
    isempty(conservedequations(Catalyst.flatten(rs))) ||
        error("The system has conservation laws but initial conditions were not provided for some species.")
end
