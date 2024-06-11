pages = Any[
    "Home" => "index.md",
    "Introduction to Catalyst" => Any[
        "introduction_to_catalyst/catalyst_for_new_julia_users.md",
        "introduction_to_catalyst/introduction_to_catalyst.md"
    ],
    "Model Creation and Properties" => Any[
        "model_creation/dsl_basics.md",
        "model_creation/dsl_advanced.md",
        "model_creation/programmatic_CRN_construction.md",
        "model_creation/compositional_modeling.md",
        "model_creation/constraint_equations.md",
        "model_creation/parametric_stoichiometry.md",
        "model_creation/model_file_loading_and_export.md",
        "model_creation/model_visualisation.md",
        "model_creation/network_analysis.md",
        "model_creation/chemistry_related_functionality.md",
        "Model creation examples" => Any[
            "model_creation/examples/basic_CRN_library.md",
            "model_creation/examples/programmatic_generative_linear_pathway.md",
            "model_creation/examples/hodgkin_huxley_equation.md",
            "model_creation/examples/smoluchowski_coagulation_equation.md"
        ]
    ],
    "Model simulation" => Any[
        "model_simulation/simulation_introduction.md",
        "model_simulation/simulation_plotting.md",
        "model_simulation/simulation_structure_interfacing.md",
        "model_simulation/ensemble_simulations.md",
        "model_simulation/ode_simulation_performance.md"
    ],
    "Steady state analysis" => Any[
        "steady_state_functionality/homotopy_continuation.md",
        "steady_state_functionality/nonlinear_solve.md",
        "steady_state_functionality/steady_state_stability_computation.md",
        "steady_state_functionality/bifurcation_diagrams.md",
        "steady_state_functionality/dynamical_systems.md"
    ],
    "Inverse Problems" => Any[
        "inverse_problems/optimization_ode_param_fitting.md",
        # "inverse_problems/petab_ode_param_fitting.md",
        "inverse_problems/behaviour_optimisation.md",
        "inverse_problems/structural_identifiability.md",
        "inverse_problems/global_sensitivity_analysis.md",
        "Inverse problem examples" => Any[
            "inverse_problems/examples/ode_fitting_oscillation.md"
        ]
    ],
    "FAQs" => "faqs.md",
    "API" => "api.md"
]
