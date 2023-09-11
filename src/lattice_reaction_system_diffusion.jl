### Diffusion Reaction Structure. ###

# Implements the diffusionparameter metadata field.
struct DiffusionParameter end
Symbolics.option_to_metadata_type(::Val{:diffusionparameter}) = DiffusionParameter

isdiffusionparameter(x::Num, args...) = isdiffusionparameter(Symbolics.unwrap(x), args...)
function isdiffusionparameter(x, default = false)
    p = Symbolics.getparent(x, nothing)
    p === nothing || (x = p)
    Symbolics.getmetadata(x, DiffusionParameter, default)
end

# Abstract spatial reaction structures.
abstract type AbstractSpatialReaction end

# A diffusion reaction. These are simple to hanlde, and should cover most types of spatial reactions.
# Currently only permit constant rates.
struct DiffusionReaction <: AbstractSpatialReaction
    """The rate function (excluding mass action terms). Currently only constants supported"""
    rate::Num
    """The species that is subject to difusion."""
    species::Num
    """A symbol representation of the species that is subject to difusion."""
    species_sym::Symbol    # Required for identification in certain cases.

    # Creates a diffusion reaction.
    function DiffusionReaction(rate::Num, species::Num)
        new(rate, species, ModelingToolkit.getname(species))
    end
    function DiffusionReaction(rate::Number, species::Num)
        new(Num(rate), species, ModelingToolkit.getname(species))
    end
    function DiffusionReaction(rate::Symbol, species::Num)
        new(Symbolics.variable(rate), species, ModelingToolkit.getname(species))
    end
    function DiffusionReaction(rate::Num, species::Symbol)
        new(rate, Symbolics.variable(species), species)
    end
    function DiffusionReaction(rate::Number, species::Symbol)
        new(Num(rate), Symbolics.variable(species), species)
    end
    function DiffusionReaction(rate::Symbol, species::Symbol)
        new(Symbolics.variable(rate), Symbolics.variable(species), species)
    end
end
# Creates a vector of DiffusionReactions.
function diffusion_reactions(diffusion_reactions)
    [DiffusionReaction(dr[1], dr[2]) for dr in diffusion_reactions]
end
# Gets the parameters in a diffusion reaction.
ModelingToolkit.parameters(dr::DiffusionReaction) = Symbolics.get_variables(dr.rate)

### Lattice Reaction Network Structure ###
# Desribes a spatial reaction network over a graph.
struct LatticeReactionSystem # <: MT.AbstractTimeDependentSystem # Adding this part messes up show, disabling me from creating LRSs
    """The reaction system within each comaprtment."""
    rs::ReactionSystem
    """The spatial reactions defined between individual nodes."""
    spatial_reactions::Vector{<:AbstractSpatialReaction}
    """The graph on which the lattice is defined."""
    lattice::DiGraph

    # Derrived values.
    """The number of compartments."""
    nC::Int64
    """The number of edges."""
    nE::Int64
    """The number of species."""
    nS::Int64
    """Whenever the initial input was a di graph."""
    init_digraph::Bool

    function LatticeReactionSystem(rs::ReactionSystem,
                                   spatial_reactions::Vector{<:AbstractSpatialReaction},
                                   lattice::DiGraph; init_digraph = true)
        return new(rs, spatial_reactions, lattice, nv(lattice), ne(lattice),
                   length(species(rs)), init_digraph)
    end
    function LatticeReactionSystem(rs::ReactionSystem,
                                   spatial_reactions::Vector{<:AbstractSpatialReaction},
                                   lattice::SimpleGraph)
        return LatticeReactionSystem(rs, spatial_reactions, graph_to_digraph(lattice);
                                     init_digraph = false)
    end
    function LatticeReactionSystem(rs::ReactionSystem,
                                   spatial_reaction::AbstractSpatialReaction,
                                   lattice::Graphs.AbstractGraph)
        return LatticeReactionSystem(rs, [spatial_reaction], lattice)
    end
end
# Covnerts a graph to a digraph (in a way where we know where the new edges are in teh edge vector).
function graph_to_digraph(g1)
    g2 = Graphs.SimpleDiGraphFromIterator(reshape(permutedims(hcat(collect(edges(g1)),
                                                       reverse.(edges(g1)))), :, 1)[:])
    add_vertices!(g2, nv(g1) - nv(g2))
    return g2
end
# Gets the species of a lattice reaction system.
species(lrs::LatticeReactionSystem) = species(lrs.rs)
function diffusion_species(lrs::LatticeReactionSystem)
    filter(s -> ModelingToolkit.getname(s) in getfield.(lrs.spatial_reactions, :species_sym),
           species(lrs.rs))
end

# Gets the parameters in a lattice reaction system.
function ModelingToolkit.parameters(lrs::LatticeReactionSystem)
    unique(vcat(parameters(lrs.rs),
                Symbolics.get_variables.(getfield.(lrs.spatial_reactions, :rate))...))
end
function compartment_parameters(lrs::LatticeReactionSystem)
    filter(p -> !is_spatial_param(p, lrs), parameters(lrs))
end
function diffusion_parameters(lrs::LatticeReactionSystem)
    filter(p -> is_spatial_param(p, lrs), parameters(lrs))
end

# Checks whenever a parameter is a spatial parameter or not. 
function is_spatial_param(p, lrs)
    hasmetadata(p, DiffusionParameter) && getmetadata(p, DiffusionParameter) &&
        (return true)    # Wanted to just depend on metadata, but seems like we cannot implement that trivially.
    return (any(isequal(p), parameters(lrs.rs)) ? false : true)
end

### Processes Input u0 & p ###

# From u0 input, extracts their values and store them in the internal format.
function lattice_process_u0(u0_in, u0_symbols, nC)
    u0 = lattice_process_input(u0_in, u0_symbols, nC)
    check_vector_lengths(u0, nC)
    expand_component_values(u0, nC)
end

# From p input, splits it into diffusion parameters and compartment parameters, and store these in the desired internal format.
function lattice_process_p(p_in, p_comp_symbols, p_diff_symbols, lrs::LatticeReactionSystem)
    pC_in, pD_in = split_parameters(p_in, p_comp_symbols, p_diff_symbols)
    pC = lattice_process_input(pC_in, p_comp_symbols, lrs.nC)
    pD = lattice_process_input(pD_in, p_diff_symbols, lrs.nE)
    lrs.init_digraph || foreach(idx -> duplicate_diff_params!(pD, idx, lrs), 1:length(pD))
    check_vector_lengths(pC, lrs.nC)
    check_vector_lengths(pD, lrs.nE)
    return pC, pD
end

# Splits parameters into those for the compartments and those for the connections.
split_parameters(ps::Tuple{<:Any, <:Any}, args...) = ps
function split_parameters(ps::Vector{<:Number}, args...)
    error("When providing parameters for a spatial system as a single vector, the paired form (e.g :D =>1.0) must be used.")
end
function split_parameters(ps::Vector{<:Pair}, p_comp_symbols::Vector,
                          p_diff_symbols::Vector)
    pC_in = [p for p in ps if Symbol(p[1]) in p_comp_symbols]
    pD_in = [p for p in ps if Symbol(p[1]) in p_diff_symbols]
    (sum(length.([pC_in, pD_in])) != length(ps)) &&
        error("These input parameters are not recongised: $(setdiff(first.(ps), vcat(first.([pC_in, pE_in]))))")
    return pC_in, pD_in
end

# If the input is given in a map form, teh vector needs sorting and the first value removed.
function lattice_process_input(input::Vector{<:Pair}, symbols::Vector{Symbol}, args...)
    (length(setdiff(Symbol.(first.(input)), symbols)) != 0) &&
        error("Some input symbols are not recognised: $(setdiff(Symbol.(first.(input)), symbols)).")
    sorted_input = sort(input;
                        by = p -> findfirst(ModelingToolkit.getname(p[1]) .== symbols))
    return lattice_process_input(last.(sorted_input), symbols, args...)
end
# Processes the input and gvies it in a form where it is a vector of vectors (some of which may have a single value).
function lattice_process_input(input::Matrix{<:Number}, args...)
    lattice_process_input([vec(input[i, :]) for i in 1:size(input, 1)], args...)
end
function lattice_process_input(input::Array{<:Number, 3}, args...)
    error("3 dimensional array parameter inpur currently not supported.")
end
function lattice_process_input(input::Vector{<:Any}, args...)
    isempty(input) ? Vector{Vector{Float64}}() :
    lattice_process_input([(val isa Vector{<:Number}) ? val : [val] for val in input],
                          args...)
end
lattice_process_input(input::Vector{<:Vector}, symbols::Vector{Symbol}, n::Int64) = input
function check_vector_lengths(input::Vector{<:Vector}, n)
    isempty(setdiff(unique(length.(input)), [1, n])) ||
        error("Some inputs where given values of inappropriate length.")
end

# For diffusion parameters, if the graph was given as an undirected graph of length n, and the paraemter have n values, exapnd so that the same value are given for both values on the edge.
function duplicate_diff_params!(pD::Vector{Vector{Float64}}, idx::Int64,
                                lrs::LatticeReactionSystem)
    (2length(pD[idx]) == lrs.nE) && (pD[idx] = [p_val for p_val in pD[idx] for _ in 1:2])
end

# For a set of input values on the given forms, and their symbolics, convert into a dictionary.
vals_to_dict(syms::Vector, vals::Vector{<:Vector}) = Dict(zip(syms, vals))
# Produces a dictionary with all parameter values.
function param_dict(pC, pD, lrs)
    merge(vals_to_dict(compartment_parameters(lrs), pC),
          vals_to_dict(diffusion_parameters(lrs), pD))
end

# Computes the diffusion rates and stores them in a format (Dictionary of species index to rates across all edges).
function compute_all_diffusion_rates(pC::Vector{Vector{Float64}},
                                     pD::Vector{Vector{Float64}},
                                     lrs::LatticeReactionSystem)
    param_value_dict = param_dict(pC, pD, lrs)
    return [s => Symbolics.value.(compute_diffusion_rates(get_diffusion_rate_law(s, lrs),
                                                          param_value_dict, lrs.nE))
            for s in diffusion_species(lrs)]
end
function get_diffusion_rate_law(s::Symbolics.BasicSymbolic, lrs::LatticeReactionSystem)
    rates = filter(sr -> isequal(ModelingToolkit.getname(s), sr.species_sym),
                   lrs.spatial_reactions)
    (length(rates) > 1) && error("Species $s have more than one diffusion reaction.")    # We could allows several and simply sum them though, easy change.
    return rates[1].rate
end
function compute_diffusion_rates(rate_law::Num,
                                 param_value_dict::Dict{Any, Vector{Float64}}, nE::Int64)
    relevant_parameters = Symbolics.get_variables(rate_law)
    if all(length(param_value_dict[P]) == 1 for P in relevant_parameters)
        return [
            substitute(rate_law,
                       Dict(p => param_value_dict[p][1] for p in relevant_parameters)),
        ]
    end
    return [substitute(rate_law,
                       Dict(p => get_component_value(param_value_dict[p], idxE)
                            for p in relevant_parameters)) for idxE in 1:nE]
end

### Spatial ODE Functor Structures ###

# Functor structure containg the information for the forcing function of a spatial ODE with diffusion on a lattice.
struct LatticeDiffusionODEf{R,S,T}
    ofunc::R
    nC::Int64
    nS::Int64
    pC::Vector{Vector{Float64}}
    work_pC::Vector{Float64}    
    enumerated_pC_idx_types::Base.Iterators.Enumerate{BitVector}
    diffusion_rates::Vector{S}
    leaving_rates::Matrix{Float64}
    enumerated_edges::T
    
    function LatticeDiffusionODEf(ofunc::R, pC, diffusion_rates::Vector{S}, lrs::LatticeReactionSystem) where {R, S, T}
        leaving_rates = zeros(length(diffusion_rates), lrs.nC)
        for (s_idx, rates) in enumerate(last.(diffusion_rates)),
            (e_idx, e) in enumerate(edges(lrs.lattice))
    
            leaving_rates[s_idx, e.src] += get_component_value(rates, e_idx)
        end
        work_pC = zeros(lrs.nC)
        enumerated_pC_idx_types = enumerate(length.(pC) .== 1)
        enumerated_edges = deepcopy(enumerate(edges(lrs.lattice)))
        new{R,S,typeof(enumerated_edges)}(ofunc, lrs.nC, lrs.nS, pC, work_pC, enumerated_pC_idx_types, diffusion_rates, leaving_rates, enumerated_edges)
    end
end

# Functor structure containg the information for the forcing function of a spatial ODE with diffusion on a lattice.
struct LatticeDiffusionODEjac{S,T}
    ofunc::S
    nC::Int64
    nS::Int64
    pC::Vector{Vector{Float64}}
    work_pC::Vector{Float64}    
    enumerated_pC_idx_types::Base.Iterators.Enumerate{BitVector}
    sparse::Bool
    jac_values::T

    function LatticeDiffusionODEjac(ofunc::S, pC, lrs::LatticeReactionSystem, jac_prototype::Union{Nothing, SparseMatrixCSC{Float64, Int64}}, sparse::Bool) where {S, T}
        work_pC = zeros(lrs.nC)
        enumerated_pC_idx_types = enumerate(length.(pC) .== 1)
        jac_values = sparse ? jac_prototype.nzval : Matrix(jac_prototype)
        new{S,typeof(jac_values)}(ofunc, lrs.nC, lrs.nS, pC, work_pC, enumerated_pC_idx_types, sparse, jac_values)
    end
end

### ODEProblem ###

# Creates an ODEProblem from a LatticeReactionSystem.
function DiffEqBase.ODEProblem(lrs::LatticeReactionSystem, u0_in, tspan,
                               p_in = DiffEqBase.NullParameters(), args...;
                               jac = true, sparse = jac, kwargs...)
    u0 = lattice_process_u0(u0_in, ModelingToolkit.getname.(species(lrs)), lrs.nC)
    pC, pD = lattice_process_p(p_in, Symbol.(compartment_parameters(lrs)),
                               Symbol.(diffusion_parameters(lrs)), lrs)
    ofun = build_odefunction(lrs, pC, pD, jac, sparse)
    return ODEProblem(ofun, u0, tspan, pC, args...; kwargs...)
end

# Builds an ODEFunction for a spatial ODEProblem.
function build_odefunction(lrs::LatticeReactionSystem, pC::Vector{Vector{Float64}},
                           pD::Vector{Vector{Float64}}, use_jac::Bool, sparse::Bool)
    # Prepeares (non-spatial) ODE functions and list of diffusing species and their rates.
    ofunc = ODEFunction(convert(ODESystem, lrs.rs); jac = use_jac, sparse = false)
    ofunc_sparse = ODEFunction(convert(ODESystem, lrs.rs); jac = use_jac, sparse = true)
    diffusion_rates_speciesmap = compute_all_diffusion_rates(pC, pD, lrs)
    diffusion_rates = [findfirst(isequal(diff_rates[1]), states(lrs.rs)) => diff_rates[2]
                       for diff_rates in diffusion_rates_speciesmap]

    f = LatticeDiffusionODEf(ofunc, pC, diffusion_rates, lrs)
    jac_prototype = (use_jac || sparse) ?
                    build_jac_prototype(ofunc_sparse.jac_prototype, diffusion_rates,
                                        lrs; set_nonzero = use_jac) : nothing
    jac = use_jac ? LatticeDiffusionODEjac(ofunc, pC, lrs, jac_prototype, sparse) : nothing
    return ODEFunction(f; jac = jac, jac_prototype = (sparse ? jac_prototype : nothing))
end

# Builds a jacobian prototype. If requested, populate it with the Jacobian's (constant) values as well.
function build_jac_prototype(ns_jac_prototype::SparseMatrixCSC{Float64, Int64},
                             diffusion_rates, lrs::LatticeReactionSystem;
                             set_nonzero = false)
    diff_species = first.(diffusion_rates)
    # Gets list of indexes for species that diffuse, but are invovled in no other reaction.
    only_diff = [(s in diff_species) && !Base.isstored(ns_jac_prototype, s, s)
                 for s in 1:(lrs.nS)]

    # Declares sparse array content.
    J_colptr = fill(1, lrs.nC * lrs.nS + 1)
    J_nzval = fill(0.0,
                   lrs.nC * (nnz(ns_jac_prototype) + count(only_diff)) +
                   length(edges(lrs.lattice)) * length(diffusion_rates))
    J_rowval = fill(0, length(J_nzval))

    # Finds filled elements.
    for comp in 1:(lrs.nC), s in 1:(lrs.nS)
        col_idx = get_index(comp, s, lrs.nS)

        # Column values.
        local_elements = in(s, diff_species) *
                         (length(lrs.lattice.fadjlist[comp]) + only_diff[s])
        diffusion_elements = -(ns_jac_prototype.colptr[(s + 1):-1:s]...)
        J_colptr[col_idx + 1] = J_colptr[col_idx] + local_elements + diffusion_elements

        # Row values.
        rows = ns_jac_prototype.rowval[ns_jac_prototype.colptr[s]:(ns_jac_prototype.colptr[s + 1] - 1)] .+
               (comp - 1) * lrs.nS
        if in(s, diff_species)
            # Finds the location of the diffusion elements, and inserts the elements from the non-spatial part into this.
            diffusion_rows = (lrs.lattice.fadjlist[comp] .- 1) .* lrs.nS .+ s
            split_idx = isempty(rows) ? 1 : findfirst(diffusion_rows .> rows[1])
            isnothing(split_idx) && (split_idx = length(diffusion_rows) + 1)
            rows = vcat(diffusion_rows[1:(split_idx - 1)], rows,
                        diffusion_rows[split_idx:end])
            if only_diff[s]
                split_idx = findfirst(rows .> get_index(comp, s, lrs.nS))
                isnothing(split_idx) && (split_idx = length(rows) + 1)
                insert!(rows, split_idx, get_index(comp, s, lrs.nS))
            end
        end
        J_rowval[J_colptr[col_idx]:(J_colptr[col_idx + 1] - 1)] = rows
    end

    # Set element values.
    if !set_nonzero
        J_nzval .= 1.0
    else
        for (s_idx, (s, rates)) in enumerate(diffusion_rates),
            (e_idx, edge) in enumerate(edges(lrs.lattice))

            col_start = J_colptr[get_index(edge.src, s, lrs.nS)]
            col_end = J_colptr[get_index(edge.src, s, lrs.nS) + 1] - 1
            column_view = @view J_rowval[col_start:col_end]

            # Updates the source value.
            val_idx_src = col_start +
                          findfirst(column_view .== get_index(edge.src, s, lrs.nS)) - 1
            J_nzval[val_idx_src] -= get_component_value(rates, e_idx)

            # Updates the destination value.
            val_idx_dst = col_start +
                          findfirst(column_view .== get_index(edge.dst, s, lrs.nS)) - 1
            J_nzval[val_idx_dst] += get_component_value(rates, e_idx)
        end
    end

    return SparseMatrixCSC(lrs.nS * lrs.nC, lrs.nS * lrs.nC, J_colptr, J_rowval, J_nzval)
end

# Defines the forcing functors effect on the (spatial) ODE system.
function (f_func::LatticeDiffusionODEf)(du, u, p, t)
    # Updates for non-spatial reactions.
    for comp_i::Int64 in 1:(f_func.nC)
        f_func.ofunc((@view du[get_indexes(comp_i, f_func.nS)]),
              (@view u[get_indexes(comp_i, f_func.nS)]),
              view_pC_vector!(f_func.work_pC, p, comp_i, f_func.enumerated_pC_idx_types), t)
    end

    # Updates for spatial diffusion reactions.
    for (s_idx, (s, rates)) in enumerate(f_func.diffusion_rates)
        for comp_i::Int64 in 1:(f_func.nC)
            du[get_index(comp_i, s, f_func.nS)] -= f_func.leaving_rates[s_idx, comp_i] *
                                                u[get_index(comp_i, s,
                                                f_func.nS)]
        end
        for (e_idx::Int64, edge::Graphs.SimpleGraphs.SimpleEdge{Int64}) in f_func.enumerated_edges
            du[get_index(edge.dst, s, f_func.nS)] += get_component_value(rates, e_idx) *
                                                  u[get_index(edge.src, s,
                                                  f_func.nS)]
        end
    end
end

# Defines the jacobian functors effect on the (spatial) ODE system.
function (jac_func::LatticeDiffusionODEjac)(J, u, p, t)
    # Because of weird stuff where the Jacobian is not reset that I don't understand properly.
    reset_J_vals!(J)

    # Updates for non-spatial reactions.
    for comp_i::Int64 in 1:(jac_func.nC)
        jac_func.ofunc.jac((@view J[get_indexes(comp_i, jac_func.nS),
                           get_indexes(comp_i, jac_func.nS)]),
                  (@view u[get_indexes(comp_i, jac_func.nS)]),
                  view_pC_vector!(jac_func.work_pC, p, comp_i, jac_func.enumerated_pC_idx_types), t)
    end

    # Updates for the spatial reactions.
    add_diff_J_vals!(J, jac_func)
end
# Resets the jacobian matrix within a jac call.
reset_J_vals!(J::Matrix) = (J .= 0.0)
reset_J_vals!(J::SparseMatrixCSC) = (J.nzval .= 0.0)
# Updates the jacobian matrix with the difussion values.
add_diff_J_vals!(J::SparseMatrixCSC, jac_func::LatticeDiffusionODEjac) = (J.nzval .+= jac_func.jac_values)
add_diff_J_vals!(J::Matrix, jac_func::LatticeDiffusionODEjac) = (J .+= jac_func.jac_values)

### Accessing State & Parameter Array Values ###

# Gets the index in the u array of species s in compartment comp (when their are nS species).
get_index(comp::Int64, s::Int64, nS::Int64) = (comp - 1) * nS + s
# Gets the indexes in the u array of all species in comaprtment comp (when their are nS species).
get_indexes(comp::Int64, nS::Int64) = ((comp - 1) * nS + 1):(comp * nS)

# We have many vectors of length 1 or n, for which we want to get value idx (or the one value, if length is 1), this function gets that.
function get_component_value(values::Vector{<:Vector}, component_idx::Int64,
                             location_idx::Int64)
    get_component_value(values[component_idx], location_idx)
end
function get_component_value(values::Vector{<:Vector}, component_idx::Int64,
                             location_idx::Int64, location_types::Vector{Bool})
    get_component_value(values[component_idx], location_idx, location_types[component_idx])
end
function get_component_value(values::Vector{<:Number}, location_idx::Int64)
    get_component_value(values, location_idx, length(values) == 1)
end
function get_component_value(values::Vector{<:Number}, location_idx::Int64,
                             location_type::Bool)
    location_type ? values[1] : values[location_idx]
end
# Converts a vector of vectors to a long vector.
function expand_component_values(values::Vector{<:Vector}, n)
    vcat([get_component_value.(values, comp) for comp in 1:n]...)
end
function expand_component_values(values::Vector{<:Vector}, n, location_types::Vector{Bool})
    vcat([get_component_value.(values, comp, location_types) for comp in 1:n]...)
end
# Creates a view of the pC vector at a given comaprtment.
function view_pC_vector!(work_pC, pC, comp, enumerated_pC_idx_types)
    for (idx,loc_type) in enumerated_pC_idx_types
        work_pC[idx] = (loc_type ? pC[idx][1] : pC[idx][comp])
    end
    return work_pC
end
# Expands a u0/p information stored in Vector{Vector{}} for to Matrix form (currently used in Spatial Jump systems).
function matrix_expand_component_values(values::Vector{<:Vector}, n)
    reshape(expand_component_values(values, n), length(values), n)
end
