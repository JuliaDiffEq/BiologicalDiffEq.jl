### Prepares Tests ###

# Fetch packages.
using Catalyst, LinearAlgebra, Test, StableRNGs

rng = StableRNG(514)

### Basic Tests ###

# Tests network analysis functions on MAPK network (by comparing to manually computed outputs).
let
    MAPK = @reaction_network MAPK begin
        (k₁, k₂),KKK + E1 <--> KKKE1
        k₃, KKKE1 --> KKK_ + E1
        (k₄, k₅), KKK_ + E2 <--> KKKE2
        k₆, KKKE2 --> KKK + E2
        (k₇, k₈), KK + KKK_ <--> KK_KKK_
        k₉, KK_KKK_ --> KKP + KKK_
        (k₁₀, k₁₁), KKP + KKK_ <--> KKPKKK_
        k₁₂, KKPKKK_ --> KKPP + KKK_
        (k₁₃, k₁₄), KKP + KKPase <--> KKPKKPase
        k₁₅, KKPPKKPase --> KKP + KKPase
        k₁₆,KKPKKPase --> KK + KKPase
        (k₁₇, k₁₈), KKPP + KKPase <--> KKPPKKPase
        (k₁₉, k₂₀), KKPP + K <--> KKPPK
        k₂₁, KKPPK --> KKPP + KP
        (k₂₂, k₂₃), KKPP + KP <--> KPKKPP
        k₂₄, KPKKPP --> KPP + KKPP
        (k₂₅, k₂₆), KP + KPase <--> KPKPase
        k₂₇, KKPPKPase --> KP + KPase
        k₂₈, KPKPase --> K + KPase
        (k₂₉, k₃₀), KPP + KPase <--> KKPPKPase
    end
    rcs, B = reactioncomplexes(MAPK)
    @test length(rcs) == 26
    num_lcs = length(linkageclasses(MAPK))
    @test num_lcs == 6
    δ = deficiency(MAPK)
    @test δ == 5
    @test all(==(0), linkagedeficiencies(MAPK))
    @test isreversible(MAPK) == false
    @test isweaklyreversible(MAPK, subnetworks(MAPK)) == false
    cls = conservationlaws(MAPK)
    @test Catalyst.get_networkproperties(MAPK).rank == 15

    k = rand(rng, numparams(MAPK))
    rates = Dict(zip(parameters(MAPK), k))
    @test Catalyst.iscomplexbalanced(MAPK, rates) == false
    # i=0;
    # for lcs in linkageclasses(MAPK)
    #     i=i+1
    #     println("Linkage no ",i)
    #     for comps in rcs[lcs]
    #         if comps.speciesids ≠ Int64[]
    #             println(sum(species(rn2)[comps.speciesids]))
    #         else
    #             println("0")
    #         end
    #     end
    #     println("-----------")
    # end
end

# Tests network analysis functions on a second network (by comparing to manually computed outputs).
let
    rn2 = @reaction_network begin
        (k₁, k₂), E + S1 <--> ES1
        (k₃, k₄), E + S2 <--> ES2
        (k₅, k₆),  S2 + ES1 <--> ES1S2
        (k₆, k₇), ES1S2 --> S1 + ES2
        k₈, ES1S2 --> E+P
        (k₉, k₁₀), S1 <--> 0
        (k₁₀, k₁₁), 0 <--> S2
        k₁₂, P --> 0
    end

    rcs, B = reactioncomplexes(rn2)
    @test length(rcs) == 12
    @test length(linkageclasses(rn2)) == 4
    @test deficiency(rn2) == 2
    @test all(==(0), linkagedeficiencies(rn2))
    @test isreversible(rn2) == false
    @test isweaklyreversible(rn2, subnetworks(rn2)) == false
    cls = conservationlaws(rn2)
    @test Catalyst.get_networkproperties(rn2).rank == 6

    k = rand(rng, numparams(rn2))
    rates = Dict(zip(parameters(rn2), k))
    @test Catalyst.iscomplexbalanced(rn2, rates) == false
    # i=0;
    # for lcs in linkageclasses(rn2)
    #     i=i+1
    #     println("Linkage no ",i)
    #     for comps in rcs[lcs]
    #         if comps.speciesids ≠ Int64[]
    #             println(sum(species(rn2)[comps.speciesids]))
    #         else
    #             println("0")
    #         end
    #     end
    #     println("-----------")
    # end
end

# Tests network analysis functions on third network (by comparing to manually computed outputs).
let
    rn3 = @reaction_network begin
        (k₁, k₂), A11 <--> 0
        (k₃, k₄), A11 <--> A13
        (k₅, k₆),  0 <--> A12
        (k₆, k₇), 0 <--> A2
        k₈, A10 --> 0
        (k₉, k₁₀), A12 <--> A6
        (k₁₁, k₁₂), A6<--> A4
        (k₁₃, k₁₄), A4 <--> A3
        k₁₅, A8 --> A9
        (k₁₆,k₁₇), A8 <--> A3 + A11
        k₁₈, A9 --> A3 + A10
        k₁₉, A2+A4 --> A2 + A6
    end
    rcs, B = reactioncomplexes(rn3)
    @test length(rcs) == 15
    @test length(linkageclasses(rn3)) == 3
    @test deficiency(rn3) == 2
    @test all(==(0), linkagedeficiencies(rn3))
    @test isreversible(rn3) == false
    @test isweaklyreversible(rn3, subnetworks(rn3)) == false
    cls = conservationlaws(rn3)
    @test Catalyst.get_networkproperties(rn3).rank == 10

    k = rand(rng, numparams(rn3))
    rates = Dict(zip(parameters(rn3), k))
    @test Catalyst.iscomplexbalanced(rn3, rates) == false
    # i=0;
    # for lcs in linkageclasses(rn3)
    #     i=i+1
    #     println("Linkage no ",i)
    #     for comps in rcs[lcs]
    #         if comps.speciesids ≠ Int64[]
    #             println(sum(species(rn3)[comps.speciesids]))
    #         else
    #             println("0")
    #         end
    #     end
    #     println("-----------")
    # end
end

let
    rn4 = @reaction_network begin
        (k1, k2), C1 <--> C2
        (k3, k4), C2 <--> C3
        (k5, k6), C3 <--> C1
    end

    k = rand(rng, numparams(rn4))
    rates = Dict(zip(parameters(rn4), k))
    @test Catalyst.iscomplexbalanced(rn4, rates) == true
end
    
### Tests Reversibility ###

# Test function.
function testreversibility(rn, B, rev, weak_rev)
    @test isreversible(rn) == rev
    subrn = subnetworks(rn)
    @test isweaklyreversible(rn, subrn) == weak_rev
end

# Tests reversibility for networks with known reversibility.
let
    rn = @reaction_network begin
        (k2, k1), A1 <--> A2 + A3
        k3, A2 + A3 --> A4
        k4, A4 --> A5
        (k6, k5), A5 <--> 2A6
        k7, 2A6 --> A4
        k8, A4 + A5 --> A7
    end
    rev = false
    weak_rev = false
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == false 
end

let
    rn = @reaction_network begin
        (k2, k1), A1 <--> A2 + A3
        k3, A2 + A3 --> A4
        k4, A4 --> A5
        (k6, k5), A5 <--> 2A6
        k7, A4 --> 2A6
        (k9, k8), A4 + A5 <--> A7
    end
    rev = false
    weak_rev = false
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == false 
end
let
    rn = @reaction_network begin
        k1, A --> B
        k2, A --> C
    end
    rev = false
    weak_rev = false
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)
    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == false 
end
let
    rn = @reaction_network begin
        k1, A --> B
        k2, A --> C
        k3, B + C --> 2A
    end
    rev = false
    weak_rev = false
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == false 
end
let
    rn = @reaction_network begin
        (k2, k1), A <--> 2B
        (k4, k3), A + C <--> D
        k5, D --> B + E
        k6, B + E --> A + C
    end
    rev = false
    weak_rev = true
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == true 
end
let
    rn = @reaction_network begin
        (k2, k1), A + E <--> AE
        k3, AE --> B + E
    end
    rev = false
    weak_rev = false
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == false 
end
let
    rn = @reaction_network begin
        (k2, k1), A + E <--> AE
        (k4, k3), AE <--> B + E
    end
    rev = true
    weak_rev = true
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == true  
end
let
    rn = @reaction_network begin (k2, k1), A + B <--> 2A end
    rev = true
    weak_rev = true
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == true 
end
let
    rn = @reaction_network begin
        k1, A + B --> 3A
        k2, 3A --> 2A + C
        k3, 2A + C --> 2B
        k4, 2B --> A + B
    end
    rev = false
    weak_rev = true
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == true 
end

let
    rn = @reaction_network begin
        (k2, k1), A + E <--> AE
        (k4, k3), AE <--> B + E
        k5, B --> 0
        k6, 0 --> A
    end
    rev = false
    weak_rev = false
    testreversibility(rn, reactioncomplexes(rn)[2], rev, weak_rev)

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == false 
end

let
    rn = @reaction_network begin
        k1, 3A + 2B --> 3C 
        k2, B + 4D --> 2E
        k3, 2E --> 3C
        (k4, k5), B + 4D <--> 3A + 2B
        k6, F --> B + 4D
        k7, 3C --> F
    end

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test Catalyst.iscomplexbalanced(rn, rates) == true 
    @test Catalyst.isdetailedbalanced(rn, rates) == false
end

### STRONG LINKAGE CLASS TESTS

let
    rn = @reaction_network begin
        (k1, k2), A <--> B + C
        k3, B + C --> D
        k4, D --> E
        (k5, k6), E <--> 2F
        k7, 2F --> D
        (k8, k9), D + E <--> G
    end

    rcs, D = reactioncomplexes(rn)
    slcs = stronglinkageclasses(rn)
    tslcs = terminallinkageclasses(rn)
    @test length(slcs) == 3
    @test length(tslcs) == 2
    @test issubset([[1,2], [3,4,5], [6,7]], slcs)
    @test issubset([[3,4,5], [6,7]], tslcs) 
end

let
    rn = @reaction_network begin
        (k1, k2), A <--> B + C
        k3, B + C --> D
        k4, D --> E
        (k5, k6), E <--> 2F
        k7, 2F --> D
        (k8, k9), D + E --> G
    end

    rcs, D = reactioncomplexes(rn)
    slcs = stronglinkageclasses(rn)
    tslcs = terminallinkageclasses(rn)
    @test length(slcs) == 4
    @test length(tslcs) == 2
    @test issubset([[1,2], [3,4,5], [6], [7]], slcs)
    @test issubset([[3,4,5], [7]], tslcs) 
end

let
    rn = @reaction_network begin
        (k1, k2), A <--> B + C
        (k3, k4), B + C <--> D
        k5, D --> E
        (k6, k7), E <--> 2F
        k8, 2F --> D
        (k9, k10), D + E <--> G
    end

    rcs, D = reactioncomplexes(rn)
    slcs = stronglinkageclasses(rn)
    tslcs = terminallinkageclasses(rn)
    @test length(slcs) == 2
    @test length(tslcs) == 2
    @test issubset([[1,2,3,4,5], [6,7]], slcs)
    @test issubset([[1,2,3,4,5], [6,7]], tslcs) 
end

let
    rn = @reaction_network begin
        (k1, k2), A <--> 2B 
        k3, A --> C + D
        (k4, k5), C + D <--> E
        k6, 2B --> F
        (k7, k8), F <--> 2G
        (k9, k10), 2G <--> H
        k11, H --> F
    end

    rcs, D = reactioncomplexes(rn)
    slcs = stronglinkageclasses(rn)
    tslcs = terminallinkageclasses(rn)
    @test length(slcs) == 3
    @test length(tslcs) == 2
    @test issubset([[1,2], [3,4], [5,6,7]], slcs)
    @test issubset([[3,4], [5,6,7]], tslcs) 
end

### CONCENTRATION ROBUSTNESS TESTS

let
    IDHKP_IDH = @reaction_network begin
        (k1, k2), EIp + I <--> EIpI
        k3, EIpI --> EIp + Ip
        (k4, k5), E + Ip <--> EIp
        k6, EIp --> E + I
    end

    @test Catalyst.robustspecies(IDHKP_IDH) == [2]
end

let
    EnvZ_OmpR = @reaction_network begin
        (k1, k2), X <--> XT
        k3, XT --> Xp
        (k4, k5), Xp + Y <--> XpY
        k6, XpY --> X + Yp
        (k7, k8), XT + Yp <--> XTYp
        k9, XTYp --> XT + Y
    end

    @test Catalyst.robustspecies(EnvZ_OmpR) == [6]
end


### Complex and detailed balance tests

# The following network is conditionally complex balanced - it only 


# Reversible, forest-like deficiency zero network - should be detailed balance for any choice of rate constants. 
let
    rn = @reaction_network begin
        (k1, k2), A <--> B + C
        (k3, k4), A <--> D
        (k5, k6), A + D <--> E
        (k7, k8), A + D <--> G
        (k9, k10), G <--> 2F
        (k11, k12), A + E <--> H
    end

    k1 = rand(rng, numparams(rn))
    rates1 = Dict(zip(parameters(rn), k1))
    k2 = rand(StableRNG(232), numparams(rn))
    rates2 = Dict(zip(parameters(rn), k2))

    @test isdetailedbalanced(rn, rates1) == true
    @test isdetailedbalanced(rn, rates2) == true
end


# Simple connected reversible network
let
    rn = @reaction_network begin
        (k1, k2), A <--> B
        (k3, k4), B <--> C
        (k5, k6), C <--> A
    end

    rates1 = [k1=>1.0, k2=>1.0, k3=>1.0, k4=>1.0, k5=>1.0, k6=>1.0]
    @test isdetailedbalanced(rn, rates1) == true
    rates2 = [k1=>2.0, k2=>1.0, k3=>1.0, k4=>1.0, k5=>1.0, k6=>1.0]
    @test isdetailedbalanced(rn, rates2) == false 
end

# Independent cycle tests: the following reaction entwork has 3 out-of-forest reactions. 
let
    rn = @reaction_network begin
        (k1, k2), A <--> B + C
        (k3, k4), A <--> D
        (k5, k6), B + C <--> D
        (k7, k8), A + D <--> E
        (k9, k10), G <--> 2F
        (k11, k12), A + D <--> G
        (k13, k14), G <--> E
        (k15, k16), 2F <--> E
        (k17, k18), A + E <--> H
    end

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test isdetailedbalanced(rn, rates) == false

    rates[k6] = rates[k1]*rates[k4]*rates[k5] / (rates[k2]*rates[k3]) 
    rates[k14] = rates[k13]*rates[k11]*rates[k8] / (rates[k12]*rates[k7])
    rates[k12] = rates[k8]*rates[k15]*rates[k9]*rates[k11] / (rates[k7]*rates[k16]*rates[k10])
    @test isdetailedbalanced(rn, rates) == true
end

# Deficiency two network: the following reaction network must satisfy both the independent cycle conditions and the spanning forest conditions 
let
    rn = @reaction_network begin
        (k1, k2), 3A <--> A + 2B
        (k3, k4), A + 2B <--> 3B
        (k5, k6), 3B <--> 2A + B
        (k7, k8), 2A + B <--> 3A
        (k9, k10), 3A <--> 3B
    end

    k = rand(rng, numparams(rn))
    rates = Dict(zip(parameters(rn), k))
    @test isdetailedbalanced(rn, rates) == false

    rates[k8] = rates[k7]*rates[k5]*rates[k9] / (rates[k6]*rates[k10])
    rates[k3] = rates[k2]*rates[k4]*rates[k9] / (rates[k1]*rates[k10])
    @test isdetailedbalanced(rn, rates) == false

    cons = rates[k6] / rates[k5]
    rates[k1] = rates[k2] * cons
    rates[k9] = rates[k10] * cons^(3/2)
    rates[k8] = rates[k7]*rates[k5]*rates[k9] / (rates[k6]*rates[k10])
    rates[k3] = rates[k2]*rates[k4]*rates[k9] / (rates[k1]*rates[k10])
    @test isdeatiledbalanced(rn, rates) == true
    @test isdetailedbalanced(rn, rates) == false
end
