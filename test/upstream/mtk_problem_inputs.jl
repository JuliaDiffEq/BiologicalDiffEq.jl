#! format: off

### Prepares Tests ###

# Fetch packages
using Catalyst, JumpProcesses, NonlinearSolve, OrdinaryDiffEq, SteadyStateDiffEq, StochasticDiffEq, Test

# Sets rnd number.
using StableRNGs
rng = StableRNG(12345)
seed = rand(rng, 1:100)


### Basic Tests ###

# Prepares a models and initial conditions/parameters (of different forms) to be used as problem inputs.
begin 
    model = @reaction_network begin
        @species Z(t) = Z0
        @parameters k2=0.5 Z0
        (kp,kd), 0 <--> X
        (k1,k2), X <--> Y
        (k1,k2), Y <--> Z
    end
    @unpack X, Y, Z, kp, kd, k1, k2, Z0 = model

    u0_alts = [
        # Vectors not providing default values.
        [X => 4, Y => 5],
        [model.X => 4, model.Y => 5],
        [:X => 4, :Y => 5],
        # Vectors providing default values.
        [X => 4, Y => 5, Z => 10],
        [model.X => 4, model.Y => 5, model.Z => 10],
        [:X => 4, :Y => 5, :Z => 10],
        # Dicts not providing default values.
        Dict([X => 4, Y => 5]),
        Dict([model.X => 4, model.Y => 5]),
        Dict([:X => 4, :Y => 5]),
        # Dicts providing default values.
        Dict([X => 4, Y => 5, Z => 10]),
        Dict([model.X => 4, model.Y => 5, model.Z => 10]),
        Dict([:X => 4, :Y => 5, :Z => 10]),
        # Tuples not providing default values.
        (X => 4, Y => 5),
        (model.X => 4, model.Y => 5),
        (:X => 4, :Y => 5),
        # Tuples providing default values.
        (X => 4, Y => 5, Z => 10),
        (model.X => 4, model.Y => 5, model.Z => 10),
        (:X => 4, :Y => 5, :Z => 10)
    ]
    tspan = (0.0, 10.0)
    p_alts = [
        # Vectors not providing default values.
        [kp => 1.0, kd => 0.1, k1 => 0.25, Z0 => 10],
        [model.kp => 1.0, model.kd => 0.1, model.k1 => 0.25, model.Z0 => 10],
        [:kp => 1.0, :kd => 0.1, :k1 => 0.25, :Z0 => 10],
        # Vectors providing default values.
        [kp => 1.0, kd => 0.1, k1 => 0.25, k2 => 0.5, Z0 => 10],
        [model.kp => 1.0, model.kd => 0.1, model.k1 => 0.25, model.k2 => 0.5, model.Z0 => 10],
        [:kp => 1.0, :kd => 0.1, :k1 => 0.25, :k2 => 0.5, :Z0 => 10],
        # Dicts not providing default values.
        Dict([kp => 1.0, kd => 0.1, k1 => 0.25, Z0 => 10]),
        Dict([model.kp => 1.0, model.kd => 0.1, model.k1 => 0.25, model.Z0 => 10]),
        Dict([:kp => 1.0, :kd => 0.1, :k1 => 0.25, :Z0 => 10]),
        # Dicts providing default values.
        Dict([kp => 1.0, kd => 0.1, k1 => 0.25, k2 => 0.5, Z0 => 10]),
        Dict([model.kp => 1.0, model.kd => 0.1, model.k1 => 0.25, model.k2 => 0.5, model.Z0 => 10]),
        Dict([:kp => 1.0, :kd => 0.1, :k1 => 0.25, :k2 => 0.5, :Z0 => 10]),
        # Tuples not providing default values.
        (kp => 1.0, kd => 0.1, k1 => 0.25, Z0 => 10),
        (model.kp => 1.0, model.kd => 0.1, model.k1 => 0.25, model.Z0 => 10),
        (:kp => 1.0, :kd => 0.1, :k1 => 0.25, :Z0 => 10),
        # Tuples providing default values.
        (kp => 1.0, kd => 0.1, k1 => 0.25, k2 => 0.5, Z0 => 10),
        (model.kp => 1.0, model.kd => 0.1, model.k1 => 0.25, model.k2 => 0.5, model.Z0 => 10),
        (:kp => 1.0, :kd => 0.1, :k1 => 0.25, :k2 => 0.5, :Z0 => 10),
    ]
end

# Perform ODE simulations (singular and ensemble).
let 
    # Creates normal and ensemble problems.
    base_oprob = ODEProblem(model, u0_alts[1], tspan, p_alts[1])
    base_sol = solve(base_oprob, Tsit5(); saveat = 1.0)
    base_eprob = EnsembleProblem(base_oprob)
    base_esol = solve(base_eprob, Tsit5(); trajectories = 2, saveat = 1.0)

    # Simulates problems for all input types, checking that identical solutions are found.
    for u0 in u0_alts, p in p_alts
        oprob = remake(base_oprob; u0, p)
        @test base_sol == solve(oprob, Tsit5(); saveat = 1.0)
        eprob = remake(base_eprob; u0, p)
        @test base_esol == solve(eprob, Tsit5(); trajectories = 2, saveat = 1.0)
    end
end

# Perform SDE simulations (singular and ensemble).
let 
    # Creates normal and ensemble problems.
    base_sprob = SDEProblem(model, u0_alts[1], tspan, p_alts[1])
    base_sol = solve(base_sprob, ImplicitEM(); seed, saveat = 1.0)
    base_eprob = EnsembleProblem(base_sprob)
    base_esol = solve(base_eprob, ImplicitEM(); seed, trajectories = 2, saveat = 1.0)

    # Simulates problems for all input types, checking that identical solutions are found.
    for u0 in u0_alts, p in p_alts
        sprob = remake(base_sprob; u0, p)
        @test base_sol == solve(sprob, ImplicitEM(); seed, saveat = 1.0)
        eprob = remake(base_eprob; u0, p)
        @test base_esol == solve(eprob, ImplicitEM(); seed, trajectories = 2, saveat = 1.0)
    end
end

# Perform jump simulations (singular and ensemble).
let 
    # Creates normal and ensemble problems.
    base_dprob = DiscreteProblem(model, u0_alts[1], tspan, p_alts[1])
    base_jprob = JumpProblem(model, base_dprob, Direct(); rng)
    base_sol = solve(base_jprob, SSAStepper(); seed, saveat = 1.0)
    base_eprob = EnsembleProblem(base_jprob)
    base_esol = solve(base_eprob, SSAStepper(); seed, trajectories = 2, saveat = 1.0)

    # Simulates problems for all input types, checking that identical solutions are found.
    for u0 in u0_alts, p in p_alts
        jprob = remake(base_jprob; u0, p)
        @test base_sol == solve(base_jprob, SSAStepper(); seed, saveat = 1.0)
        eprob = remake(base_eprob; u0, p)
        @test base_esol == solve(eprob, SSAStepper(); seed, trajectories = 2, saveat = 1.0)
    end
end

# Solves a nonlinear problem (EnsembleProblems are not possible for these).
let
    base_nlprob = NonlinearProblem(model, u0_alts[1], p_alts[1])
    base_sol = solve(base_nlprob, NewtonRaphson())
    for u0 in u0_alts, p in p_alts
        nlprob = remake(base_nlprob; u0, p)
        @test base_sol == solve(nlprob, NewtonRaphson())
    end
end

# Perform steady state simulations (singular and ensemble).
let 
    # Creates normal and ensemble problems.
    base_ssprob = SteadyStateProblem(model, u0_alts[1], p_alts[1])
    base_sol = solve(base_ssprob, DynamicSS(Tsit5()))
    base_eprob = EnsembleProblem(base_ssprob)
    base_esol = solve(base_eprob, DynamicSS(Tsit5()); trajectories = 2)

    # Simulates problems for all input types, checking that identical solutions are found.
    for u0 in u0_alts, p in p_alts
        ssprob = remake(base_ssprob; u0, p)
        @test base_sol == solve(ssprob, DynamicSS(Tsit5()))
        eprob = remake(base_eprob; u0, p)
        @test base_esol == solve(eprob, DynamicSS(Tsit5()); trajectories = 2)
    end
end


### Checks Errors On Faulty Inputs ###

# Checks various erroneous problem inputs, ensuring that these throw errors.
let
    # Declares the model.
    rn = @reaction_network begin
        (k1,k2), X1 <--> X2
    end
    @unpack k1, k2, X1, X2 = rn
    t = default_t()
    @species X3(t)
    @parameters k3

    # Creates systems (so these are not recreated in each problem call).
    osys = convert(ODESystem, rn)
    ssys = convert(SDESystem, rn)
    nsys = convert(NonlinearSystem, rn)

    # Declares valid initial conditions and parameter values
    u0_valid = [X1 => 1, X2 => 2]
    ps_valid = [k1 => 0.5, k2 => 0.1]

    # Declares invalid initial conditions and parameters. This includes both cases where values are
    # missing, or additional ones are given. Includes vector/Tuple/Dict forms.
    u0s_invalid = [
        # Missing a value.
        [X1 => 1],
        [rn.X1 => 1],
        [:X1 => 1],
        Dict([X1 => 1]),
        Dict([rn.X1 => 1]),
        Dict([:X1 => 1]),
        (X1 => 1),
        (rn.X1 => 1),
        (:X1 => 1),
        # Contain an additional value.
        [X1 => 1, X2 => 2, X3 => 3],
        [:X1 => 1, :X2 => 2, :X3 => 3],
        Dict([X1 => 1, X2 => 2, X3 => 3]),
        Dict([:X1 => 1, :X2 => 2, :X3 => 3]),
        (X1 => 1, X2 => 2, X3 => 3),
        (:X1 => 1, :X2 => 2, :X3 => 3)
    ]
    ps_invalid = [
        # Missing a value.
        [k1 => 1.0],
        [rn.k1 => 1.0],
        [:k1 => 1.0],
        Dict([k1 => 1.0]),
        Dict([rn.k1 => 1.0]),
        Dict([:k1 => 1.0]),
        (k1 => 1.0),
        (rn.k1 => 1.0),
        (:k1 => 1.0),
        # Contain an additional value.
        [k1 => 1.0, k2 => 2.0, k3 => 3.0],
        [:k1 => 1.0, :k2 => 2.0, :k3 => 3.0],
        Dict([k1 => 1.0, k2 => 2.0, k3 => 3.0]),
        Dict([:k1 => 1.0, :k2 => 2.0, :k3 => 3.0]),
        (k1 => 1.0, k2 => 2.0, k3 => 3.0),
        (:k1 => 1.0, :k2 => 2.0, :k3 => 3.0)
    ]

    # Loops through all potential parameter sets, checking their inputs yield errors.
    # Broken tests are due to this issue: https://github.com/SciML/ModelingToolkit.jl/issues/2779
    for ps in [ps_valid; ps_invalid], u0 in [u0_valid; u0s_invalid]
        # Handles problems with/without tspan separately. Special check ensuring that valid inputs passes.
        for (xsys, XProblem) in zip([osys, ssys, rn], [ODEProblem, SDEProblem, DiscreteProblem])
            if (ps == ps_valid) && (u0 == u0_valid)
                XProblem(xsys, u0, (0.0, 1.0), ps); @test true;
            else
                @test_broken false
                continue
                @test_throws Exception XProblem(xsys, u0, (0.0, 1.0), ps)
            end
        end
        for (xsys, XProblem) in zip([nsys, osys], [NonlinearProblem, SteadyStateProblem])
            if (ps == ps_valid) && (u0 == u0_valid)
                XProblem(xsys, u0, ps); @test true;
            else
                @test_broken false
                continue
                @test_throws Exception XProblem(xsys, u0, ps)
            end
        end
    end
end