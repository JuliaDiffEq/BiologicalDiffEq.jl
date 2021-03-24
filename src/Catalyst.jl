"""
$(DocStringExtensions.README)
"""
module Catalyst

using DocStringExtensions
using Reexport, ModelingToolkit
using ModelingToolkit: Symbolic, value, istree
@reexport using ModelingToolkit
import MacroTools
import Base: (==), merge!, merge
using Latexify, Requires

# as used in Catlab
const USE_GV_JLL = Ref(false)
function __init__()
    @require Graphviz_jll="3c863552-8265-54e4-a6dc-903eb78fde85" begin
      USE_GV_JLL[] = true
      let cfg = joinpath(Graphviz_jll.artifact_dir, "lib", "graphviz", "config6")
        if !isfile(cfg)
          Graphviz_jll.dot(path -> run(`$path -c`))
        end
      end
    end
  end

const ExprValues = Union{Expr,Symbol,Float64,Int}

include("expression_utils.jl")
include("reaction_network.jl")

# reaction network macro
export @reaction_network, @add_reactions

include("spatial_network.jl")
export @spatial_reaction_network
export graph_iterator

# functions to query network properties
include("networkapi.jl")
export species, params, reactions, speciesmap, paramsmap, numspecies, numreactions, numparams
export make_empty_network, addspecies!, addparam!, addreaction!
export dependants, dependents, substoichmat, prodstoichmat

# for Latex printing of ReactionSystems
include("latexify_recipes.jl")

# for making and saving graphs
import Base.Iterators: flatten
import DataStructures: OrderedDict
import Parameters: @with_kw_noshow
include("graphs.jl")
export Graph, savegraph

end # module
