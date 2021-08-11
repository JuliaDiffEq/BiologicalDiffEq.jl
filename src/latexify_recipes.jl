# Implements handling of registered functions.
mm_names = ([:mm])
mmr_names = ([:mmr])
hill_names = ([:hill])
hillr_names = ([:hillr])
hillar_names = ([:hillar])

make_mm_exp(expr::Expr) = :($(expr.args[3])*$(expr.args[2])/($(expr.args[4])+$(expr.args[2])))
make_mmr_exp(expr::Expr) = :($(expr.args[3])*$(expr.args[4])/($(expr.args[4])+$(expr.args[2])))
make_hill_exp(expr::Expr) = :($(expr.args[3])*($(expr.args[2])^$(expr.args[5]))/($(expr.args[4])^$(expr.args[5])+$(expr.args[2])^$(expr.args[5])))
make_hillr_exp(expr::Expr) = :($(expr.args[3])*($(expr.args[4])^$(expr.args[5]))/($(expr.args[4])^$(expr.args[5])+$(expr.args[2])^$(expr.args[5])))
make_hillar_exp(expr::Expr) = :($(expr.args[4])*($(expr.args[2])^$(expr.args[6]))/($(expr.args[5])^$(expr.args[6])+$(expr.args[2])^$(expr.args[6])+$(expr.args[3])^$(expr.args[6])))


#Recursively traverses an expression and removes things like X^1, 1*X. Will not actually have any effect on the expression when used as a function, but will make it much easier to look at it for debugging, as well as if it is transformed to LaTeX code.
function recursive_clean!(expr)
    (expr isa Symbol) && (expr == :no___noise___scaling) && (return 1)
    (typeof(expr)!=Expr) && (return expr)
    for i = 1:length(expr.args)
        expr.args[i] = recursive_clean!(expr.args[i])
    end
    (expr.args[1] == :^) && (expr.args[3] == 1) && (return expr.args[2])
    if expr.args[1] == :*
        in(0,expr.args) && (return 0)
        i = 1
        while (i = i + 1) <= length(expr.args)
             if (typeof(expr.args[i]) == Expr) && (expr.args[i].head == :call) && (expr.args[i].args[1] == :*)
                 for arg in expr.args[i].args
                     (arg != :*) && push!(expr.args, arg)
                 end
             end
        end
        for i = length(expr.args):-1:2
            (typeof(expr.args[i]) == Expr) && (expr.args[i].head == :call) && (expr.args[i].args[1] == :*) && deleteat!(expr.args,i)
            (expr.args[i] == 1) && deleteat!(expr.args,i)
        end
        (length(expr.args) == 2) && (return expr.args[2])                   # We have a multiplication of only one thing, return only that thing.
        (length(expr.args) == 1) && (return 1)                              # We have only * and no real arguments.
        (length(expr.args) == 3) && (expr.args[2] == -1) && return :(-$(expr.args[3]))
        (length(expr.args) == 3) && (expr.args[3] == -1) && return :(-$(expr.args[2]))
    end
    if expr.head == :call
        (expr.args[1] == :/) && (expr.args[3] == 1) && (return expr.args[2])
        in(expr.args[1],mm_names) && return make_mm_exp(expr)
        in(expr.args[1],mmr_names) && return make_mmr_exp(expr)
        in(expr.args[1],hill_names) && return make_hill_exp(expr)
        in(expr.args[1],hillr_names) && return make_hillr_exp(expr)
        in(expr.args[1],hillar_names) && return make_hillar_exp(expr)
        (expr.args[1] == :binomial) && (expr.args[3] == 1) && return expr.args[2]
        #@isdefined($(expr.args[1])) || error("Function $(expr.args[1]) not defined.")
    end
    return expr
end


function chemical_arrows(rn::ReactionSystem;
    expand = true, double_linebreak=false, mathjax=true, starred=false, kwargs...)
    str = starred ? "\\begin{align*}\n" : "\\begin{align}\n"
    eol = double_linebreak ? "\\\\\\\\\n" : "\\\\\n"

    mathjax && (str *= "\\require{mhchem}\n")
    backwards_reaction = false
    rxs = equations(rn)
    @variables t

    # this should replace A(t) with A in equations however, currently substituter rewrites
    # things like x/y as inv(y)*x^1, which looks worse... for now we leave a stub that can
    # be updated when substitution preserves expressions better.
    # subber = ModelingToolkit.substituter([s(t) => s() for s in states(rn)])
    subber = x -> x

    for (i, r) in enumerate(rxs)
        if backwards_reaction
            backwards_reaction = false
            continue
        end
        str *= "\\ce{ "

        ### Expand functions to maths expressions
        rate =  ModelingToolkit.prettify_expr(toexpr(r.rate))
        #rate = r.rate isa Symbolic ? Expr(subber(r.rate)) : r.rate
        expand && (rate = recursive_clean!(rate))
        expand && (rate = recursive_clean!(rate))

        ### Generate formatted string of substrates
        substrates = [latexraw("$(substrate[2]== 1 ? "" : "$(substrate[2]) * ") $(substrate[1].f.name)"; kwargs...) for substrate in zip(r.substrates,r.substoich)]
        isempty(substrates) && (substrates = ["\\varnothing"])

        str *= join(substrates, " + ")

        ### Generate reaction arrows
        prestr  = mathjax ? "[" : "[\$"
        poststr = mathjax ? "]" : "\$]"
        if i + 1 <= length(rxs) && issetequal(r.products,rxs[i+1].substrates) && issetequal(r.substrates,rxs[i+1].products)
            ### Bi-directional arrows
            rate_backwards = ModelingToolkit.prettify_expr(toexpr(rxs[i+1].rate))
            #rate_backwards = rxs[i+1].rate isa Symbolic ? Expr(subber(rxs[i+1].rate)) : rxs[i+1].rate
            expand && (rate_backwards = recursive_clean!(rate_backwards))
            expand && (rate_backwards = recursive_clean!(rate_backwards))
            str *= " &<=>"
            str *= prestr * latexraw(rate; kwargs...) * poststr
            str *= prestr * latexraw(rate_backwards; kwargs...) * poststr * " "
            backwards_reaction = true
        else
            ### Uni-directional arrows
            str *= " &->"
            str *= prestr * latexraw(rate; kwargs...) * poststr * " "
        end

        ### Generate formatted string of products
        products = [latexraw("$(product[2]== 1 ? "" : "$(product[2]) * ") $(product[1].f.name)"; kwargs...) for product in zip(r.products,r.prodstoich) ]
        isempty(products) && (products = ["\\varnothing"])
        str *= join(products, " + ")
        str *= "}$eol"
    end
    str = str[1:end-length(eol)] * "\n"

    str *= starred ? "\\end{align*}\n" : "\\end{align}\n"

    latexstr = Latexify.LaTeXString(str)
    Latexify.COPY_TO_CLIPBOARD && clipboard(latexstr)
    return latexstr
end


@latexrecipe function f(sys::ReactionSystem)
    # Set default option values.
    env --> :chem
    cdot --> false

    return sys
end


function Latexify.infer_output(env, rs::ReactionSystem, args...)
    env in [:arrows, :chem, :chemical, :arrow] && return chemical_arrows

    error("The environment $env is not defined.")
    latex_function = Latexify.get_latex_function(rs, args...)

    return latex_function
end
