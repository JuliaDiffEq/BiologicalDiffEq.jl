"""
Macro that inputs an expression corresponding to a reaction network and outputs
a `ReactionNetwork` that can be used as input to generation of ODE, SDE, and
Jump problems.

Most arrows accepted (both right, left, and bi-drectional arrows). Note that
while --> is a correct arrow, neither <-- nor <--> works. Using non-filled
arrows (⇐, ⟽, ⇒, ⟾, ⇔, ⟺) will disable mass kinetics and let you cutomize
reaction rates yourself. Use 0 or ∅ for degradation/creation to/from nothing.
Example systems: ### Basic Usage ### rn = @reaction_network begin           #
Creates a ReactionSystem. 2.0, X + Y --> XY                  # This will have
reaction rate corresponding to 2.0*[X][Y] 2.0, XY ← X + Y                    #
Identical to 2.0, X + Y --> XY end

    ### Manipulating Reaction Rates ###
    rn = @reaction_network begin
        2.0, X + Y ⟾ XY                   # Ignores mass kinetics. This will have reaction rate corresponding to 2.0.
        2.0X, X + Y --> XY                 # Reaction rate needs not be constant. This will have reaction rate corresponding to 2.0*[X]*[X]*[Y].
        XY+log(X)^2, X + Y --> XY          # Reaction rate accepts quite complicated expressions.
        hill(XY,2,2,2), X + Y --> XY       # Reaction inis activated by XY according to a hill function. hill(x,v,K,N).
        mm(XY,2,2), X + Y --> XY           # Reaction inis activated by XY according to a michaelis menten function. mm(x,v,K).
    end

    ### Multiple Reactions on a Single Line ###
    rn = @reaction_network begin
        (2.0,1.0), X + Y ↔ XY              # Identical to reactions (2.0, X + Y --> XY) and (1.0, XY --> X + Y).
        2.0, (X,Y) --> 0                   # This corresponds to both X and Y degrading at rate 2.0.
        (2.0, 1.0), (X,Y) --> 0            # This corresponds to X and Y degrading at rates 2.0 and 1.0, respectively.
        2.0, (X1,Y1) --> (X2,Y2)           # X1 and Y1 becomes X2 and Y2, respectively, at rate 2.0.
    end

    ### Adding Parameters ###
    kB = 2.0; kD = 1.0
    p = [kB, kD]
    p = []
    rn = @reaction_network begin
        (kB, kD), X + Y ↔ XY               # Lets you define parameters outside on network. Parameters can be changed without recalling the network.
    end kB, kD

    ### Defining New Functions ###
    my_hill_repression(x, v, k, n) = v*k^n/(k^n+x^n)  

    # may be necessary to 
    # @register my_hill_repression(x, v, k, n)
    # see https://mtk.sciml.ai/stable/tutorials/symbolic_functions/#Registering-Functions-1

    r = @reaction_network MyReactionType begin
        my_hill_repression(x, v_x, k_x, n_x), 0 --> x
    end v_x k_x n_x

    ### Simulating Reaction Networks ###
    probODE = ODEProblem(rn, args...; kwargs...)        # Using multiple dispatch the reaction network can be used as input to create ODE, SDE and Jump problems.
    probSDE = SDEProblem(rn, args...; kwargs...)
    probJump = JumpProblem(prob,aggregator::Direct,rn)
"""



# Declare various arrow types symbols used for the empty set (also 0).
empty_set = Set{Symbol}([:∅])
fwd_arrows = Set{Symbol}([:>, :→, :↣, :↦, :⇾, :⟶, :⟼, :⥟, :⥟, :⇀, :⇁, :⇒, :⟾])
bwd_arrows = Set{Symbol}([:<, :←, :↢, :↤, :⇽, :⟵, :⟻, :⥚, :⥞, :↼, :↽, :⇐, :⟽])
double_arrows = Set{Symbol}([:↔, :⟷, :⇄, :⇆, :⇌, :⇋, :⇔, :⟺])
pure_rate_arrows = Set{Symbol}([:⇐, :⟽, :⇒, :⟾, :⇔, :⟺])

# unfortunately the following doesn't seem to work on 1.5, so supporting these 
# operators seems to require us to only support 1.6 and up...
@static if VERSION >= v"1.6.0"
    push!(bwd_arrows, Symbol("<--"))
    push!(double_arrows, Symbol("<-->"))
end


# Declares symbols which may neither be used as parameters not varriables.
forbidden_symbols = [:t, :π, :pi, :ℯ, :im, :nothing, :∅]


### The main macro, takes reaction network notation and returns a ReactionSystem. ###
"""
    @reaction_network

Generates a [`ReactionSystem`](@ref) that encodes a chemical reaction
network.

See the [The Reaction DSL](@ref) documentation for details on
parameters to the macro.

Examples:
```julia
# a basic SIR model, with name SIR
sir_model = @reaction_network SIR begin
    c1, s + i --> 2i
    c2, i --> r
end c1 c2

# a basic SIR model, with random generated name
sir_model = @reaction_network begin
    c1, s + i --> 2i
    c2, i --> r
end c1 c2

# an empty network with name empty
emptyrn = @reaction_network empty

# an empty network with random generated name
emptyrn = @reaction_network 
```
"""
macro reaction_network(name::Symbol, ex::Expr, parameters...)
    make_reaction_system(MacroTools.striplines(ex), parameters; name=name)
end

macro reaction_network(ex::Expr, parameters...)
    make_reaction_system(MacroTools.striplines(ex), parameters)
end

#Returns a empty network (with, or without, a declared name)
macro reaction_network(name::Symbol=gensym(:ReactionSystem))
    return Expr(:block,:(@parameters t),
                :(ReactionSystem(Reaction[],
                                 t,
                                 [],
                                 [];                                 
                                 name=$(QuoteNode(name)))))
end

### Macros used for manipulating, and successively builing up, reaction systems. ###

"""
    @add_reactions

Adds the reactions declared to a preexisting [`ReactionSystem`](@ref). All
parameters used in the added reactions need to be declared after the
reactions.

See the [Catalyst.jl for Reaction Models](@ref) documentation for details on
parameters to the macro.
"""
macro add_reactions(rn::Symbol, ex::Expr, parameters...)
    :(merge!($(esc(rn)),$(make_reaction_system(MacroTools.striplines(ex), parameters))))
end



### Sturctures containing information about a reactant, and a reaction, respectively.

#Structure containing information about one reactant in one reaction.
struct ReactantStruct
    reactant::Symbol
    stoichiometry::Number
end
#Structure containing information about one Reaction. Contain all its substrates and products as well as its rate. Contains a specialized constructor.
struct ReactionStruct
    substrates::Vector{ReactantStruct}
    products::Vector{ReactantStruct}
    rate::ExprValues
    only_use_rate::Bool

    function ReactionStruct(sub_line::ExprValues, prod_line::ExprValues, rate::ExprValues, only_use_rate::Bool)
        sub = recursive_find_reactants!(sub_line,1,Vector{ReactantStruct}(undef,0))
        prod = recursive_find_reactants!(prod_line,1,Vector{ReactantStruct}(undef,0))
        new(sub, prod, rate, only_use_rate)
    end
end


### Functions that process the input and rephrase it as a reaction system ###

# Takes the reactions, and rephrases it as a "ReactionSystem" call, as designated by the ModelingToolkit IR.
function make_reaction_system(ex::Expr, parameters; name=gensym(:ReactionSystem))
    reactions = get_reactions(ex)
    reactants = get_reactants(reactions)
    !isempty(intersect(forbidden_symbols,union(reactants,parameters))) && error("The following symbol(s) are used as reactants or parameters: "*((map(s -> "'"*string(s)*"', ",intersect(forbidden_symbols,union(reactants,parameters)))...))*"this is not permited.")    
    network_code = Expr(:block,:(@parameters t),:(@variables), :(ReactionSystem([],t,[],[]; name=$(QuoteNode(name)))))
    foreach(parameter-> push!(network_code.args[1].args, parameter), parameters)
    foreach(reactant -> push!(network_code.args[2].args, Expr(:call,reactant,:t)), reactants)
    foreach(parameter-> push!(network_code.args[3].args[6].args, parameter), parameters)
    foreach(reactant -> push!(network_code.args[3].args[5].args, reactant), reactants)
    for reaction in reactions
        subs_init = isempty(reaction.substrates) ? nothing : :([]); subs_stoich_init = deepcopy(subs_init)
        prod_init = isempty(reaction.products) ? nothing : :([]); prod_stoich_init = deepcopy(prod_init)
        reaction_func = :(Reaction($(recursive_expand_functions!(reaction.rate)), $subs_init, $prod_init, $subs_stoich_init, $prod_stoich_init, only_use_rate=$(reaction.only_use_rate)))
        for sub in reaction.substrates
            push!(reaction_func.args[3].args, sub.reactant)
            push!(reaction_func.args[5].args, sub.stoichiometry)
        end
        for prod in reaction.products
            push!(reaction_func.args[4].args, prod.reactant)
            push!(reaction_func.args[6].args, prod.stoichiometry)
        end
        push!(network_code.args[3].args[3].args,reaction_func)
    end
    return network_code
end

#Generates a vector containing a number of reaction structures, each containing the information about one reaction.
function get_reactions(ex::Expr, reactions = Vector{ReactionStruct}(undef,0))
    for line in ex.args
        (line.head != :tuple) && (continue)
        (rate,r_line) = line.args
        (r_line.head  == :-->) && (r_line = Expr(:call,:→,r_line.args[1],r_line.args[2]))

        arrow = r_line.args[1]
        if in(arrow,double_arrows)
            (typeof(rate) == Expr && rate.head == :tuple) || error("Error: Must provide a tuple of reaction rates when declaring a bi-directional reaction.")
            push_reactions!(reactions, r_line.args[2], r_line.args[3], rate.args[1], in(arrow,pure_rate_arrows))
            push_reactions!(reactions, r_line.args[3], r_line.args[2], rate.args[2], in(arrow,pure_rate_arrows))
        elseif in(arrow,fwd_arrows)
            push_reactions!(reactions, r_line.args[2], r_line.args[3], rate, in(arrow,pure_rate_arrows))
        elseif in(arrow,bwd_arrows)
            push_reactions!(reactions, r_line.args[3], r_line.args[2], rate, in(arrow,pure_rate_arrows))
        else
            throw("malformed reaction")
        end
    end
    return reactions
end

#Takes a reaction line and creates reactions from it and pushes those to the reaction array. Used to create multiple reactions from, for instance, 1.0, (X,Y) --> 0.
function push_reactions!(reactions::Vector{ReactionStruct}, sub_line::ExprValues, prod_line::ExprValues, rate::ExprValues, only_use_rate::Bool)
    lengs = [tup_leng(sub_line), tup_leng(prod_line), tup_leng(rate)]
    for i = 1:maximum(lengs)
        (count(lengs.==1) + count(lengs.==maximum(lengs)) < 3) && (throw("malformed reaction"))
        push!(reactions, ReactionStruct(get_tup_arg(sub_line,i), get_tup_arg(prod_line,i), get_tup_arg(rate,i), only_use_rate))
    end
end

#Recursive function that loops through the reaction line and finds the reactants and their stoichiometry. Recursion makes it able to handle weird cases like 2(X+Y+3(Z+XY)).
function recursive_find_reactants!(ex::ExprValues, mult::Int, reactants::Vector{ReactantStruct})
    if typeof(ex)!=Expr
        (ex == 0 || in(ex,empty_set)) && (return reactants)
        if in(ex, getfield.(reactants,:reactant))
            idx = findall(x -> x==ex ,getfield.(reactants,:reactant))[1]
            reactants[idx] = ReactantStruct(ex,mult+reactants[idx].stoichiometry)
        else
            push!(reactants, ReactantStruct(ex,mult))
        end
    elseif ex.args[1] == :*
        recursive_find_reactants!(ex.args[3],mult*ex.args[2],reactants)
    elseif ex.args[1] == :+
        for i = 2:length(ex.args)
            recursive_find_reactants!(ex.args[i],mult,reactants)
        end
    else
        throw("malformed reaction")
    end
    return reactants
end

# Extract the reactants from the set of reactions.
function get_reactants(reactions::Vector{ReactionStruct})
    reactants = Vector{Symbol}()
    for reaction in reactions, reactant in union(reaction.substrates,reaction.products)
        !in(reactant.reactant,reactants) && push!(reactants,reactant.reactant)
    end
    return reactants
end


### Functionality for expanding function call to custom and specific functions ###

#Recursively traverses an expression and replaces special function call like "hill(...)" with the actual corresponding expression.
function recursive_expand_functions!(expr::ExprValues)
    (typeof(expr)!=Expr) && (return expr)
    foreach(i -> expr.args[i] = recursive_expand_functions!(expr.args[i]), 1:length(expr.args))
    if expr.head == :call
        !isdefined(Catalyst,expr.args[1]) && (expr.args[1] = esc(expr.args[1]))
    end
    return expr
end


