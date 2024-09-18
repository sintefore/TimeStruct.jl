"""
    struct StratNodeOperationalScenario{T,OP<:TimeStructure{T}}  <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a strategic node supporting
iteration over its time periods. It is created through iterating through
[`StratNodeOpScens`](@ref).

It is equivalent to a [`StratOperationalScenario`](@ref) of a [`TwoLevel`](@ref) time
structure when utilizing a [`TwoLevelTree`](@ref).
"""
struct StratNodeOperationalScenario{T,OP<:TimeStructure{T}} <:
       AbstractOperationalScenario{T}
    sp::Int
    branch::Int
    scen::Int
    mult_sp::Float64
    mult_scen::Float64
    prob_branch::Float64
    prob_scen::Float64
    operational::OP
end

_strat_per(osc::StratNodeOperationalScenario) = osc.sp
_branch(osc::StratNodeOperationalScenario) = osc.branch
_opscen(osc::StratNodeOperationalScenario) = osc.scen

mult_strat(osc::StratNodeOperationalScenario) = osc.mult_sp
mult_scen(osc::StratNodeOperationalScenario) = osc.mult_scen
probability(osc::StratNodeOperationalScenario) = osc.prob_branch * prob_scen
probability_branch(osc::StratNodeOperationalScenario) = osc.prob_branch

_oper_struct(osc::StratNodeOperationalScenario) = osc.operational

# Provide a constructor to simplify the design
function TreePeriod(
    osc::StratNodeOperationalScenario,
    per::P,
) where {P<:Union{TimePeriod,AbstractOperationalScenario}}
    mult = mult_strat(osc) * multiple(per)
    return TreePeriod(_strat_per(osc), _branch(osc), probability_branch(osc), mult, per)
end

function StrategicTreeIndexable(::Type{<:StratNodeOperationalScenario})
    return HasStratTreeIndex()
end
StrategicIndexable(::Type{<:StratNodeOperationalScenario}) = HasStratIndex()

# Adding methods to existing Julia functions
function Base.show(io::IO, osc::StratNodeOperationalScenario)
    return print(io, "sp$(_strat_per(osc))-br$(_branch(osc))-sc$(_opscen(osc))")
end
Base.eltype(_::StratNodeOperationalScenario{T,OP}) where {T,OP} = TreePeriod{eltype(op)}

"""
    struct StratNodeOpScens <: AbstractTreeStructure

Type for iterating through the individual operational scenarios of a [`StratNode`](@ref).
It is automatically created through the function [`opscenarios`](@ref).
"""
struct StratNodeOpScens <: AbstractTreeStructure
    sp::Int
    branch::Int
    mult_sp::Float64
    prob_branch::Float64
    opscens::Any
end

_strat_per(oscs::StratNodeOpScens) = oscs.sp
_branch(oscs::StratNodeOpScens) = oscs.branch

mult_strat(oscs::StratNodeOpScens) = oscs.mult_sp
probability_branch(oscs::StratNodeOpScens) = oscs.prob_branch

_oper_struct(oscs::StratNodeOpScens) = oscs.opscens

"""
When the `TimeStructure` is a [`StratNode`](@ref), `opscenarios` returns the iterator
[`StratNodeOpScens`](@ref).
"""
function opscenarios(n::StratNode{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StratNodeOpScens(
        _strat_per(n),
        _branch(n),
        mult_strat(n),
        probability_branch(n),
        opscenarios(n.operational),
    )
end

function strat_node_period(oscs::StratNodeOpScens, next, state)
    return StratNodeOperationalScenario(
        _strat_per(oscs),
        _branch(oscs),
        state,
        mult_strat(oscs),
        mult_scen(next),
        probability_branch(oscs),
        probability(next),
        next,
    )
end

Base.eltype(_::StratNodeOpScens) = StratNodeOperationalScenario

"""
    struct StratNodeReprOpScenario{T} <: AbstractOperationalScenario{T}

A structure representing a single operational scenario for a representative period in A
[`TwoLevelTree`](@ref) structure supporting iteration over its time periods.
"""
struct StratNodeReprOpScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    sp::Int
    branch::Int
    rp::Int
    scen::Int
    mult_sp::Float64
    mult_rp::Float64
    mult_scen::Float64
    prob_branch::Float64
    prob_scen::Float64
    operational::OP
end

_strat_per(osc::StratNodeReprOpScenario) = osc.sp
_branch(osc::StratNodeReprOpScenario) = osc.branch
_rper(osc::StratNodeReprOpScenario) = osc.rp
_opscen(osc::StratNodeReprOpScenario) = osc.scen

mult_strat(osc::StratNodeReprOpScenario) = osc.mult_sp
mult_repr(osc::StratNodeReprOpScenario) = osc.mult_rp
mult_scen(osc::StratNodeReprOpScenario) = osc.mult_scen
probability_branch(osc::StratNodeReprOpScenario) = osc.prob_branch
probability(osc::StratNodeReprOpScenario) = osc.prob_branch * osc.prob_scen

_oper_struct(osc::StratNodeReprOpScenario) = osc.operational

StrategicTreeIndexable(::Type{<:StratNodeReprOpScenario}) = HasStratTreeIndex()
StrategicIndexable(::Type{<:StratNodeReprOpScenario}) = HasStratIndex()
function RepresentativeIndexable(::Type{<:StratNodeReprOpScenario})
    return HasReprIndex()
end
ScenarioIndexable(::Type{<:StratNodeReprOpScenario}) = HasScenarioIndex()

# Provide a constructor to simplify the design
function TreePeriod(
    osc::StratNodeReprOpScenario,
    per::P,
) where {P<:Union{TimePeriod,AbstractOperationalScenario}}
    rper = ReprPeriod(_rper(osc), per, mult_repr(osc) * multiple(per))
    mult = mult_strat(osc) * mult_repr(osc) * multiple(per)
    return TreePeriod(_strat_per(osc), _branch(osc), probability_branch(osc), mult, rper)
end

# Adding methods to existing Julia functions
function Base.show(io::IO, osc::StratNodeReprOpScenario)
    return print(
        io,
        "sp$(_strat_per(osc))-br$(_branch(osc))-rp$(_rper(osc))-sc$(_opscen(osc))",
    )
end
Base.eltype(_::StratNodeReprOpScenario{T,OP}) where {T,OP} = TreePeriod{eltype(op)}

"""
    struct StratNodeReprOpScens <: AbstractTreeStructure

Type for iterating through the individual operational scenarios of a
[`StratNodeReprPeriod`](@ref). It is automatically created through the function
[`opscenarios`](@ref).
"""
struct StratNodeReprOpScens <: AbstractTreeStructure
    sp::Int
    branch::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    prob_branch::Float64
    opscens::Any
end

_strat_per(oscs::StratNodeReprOpScens) = oscs.sp
_branch(oscs::StratNodeReprOpScens) = oscs.branch
_rper(oscs::StratNodeReprOpScens) = oscs.rp

mult_strat(oscs::StratNodeReprOpScens) = oscs.mult_sp
mult_repr(oscs::StratNodeReprOpScens) = oscs.mult_rp
probability_branch(oscs::StratNodeReprOpScens) = oscs.prob_branch

_oper_struct(oscs::StratNodeReprOpScens) = oscs.opscens

"""
When the `TimeStructure` is a [`StratNodeReprPeriod`](@ref) with a [`RepresentativePeriod`](@ref),
`opscenarios` returns the iterator [`StratNodeReprOpScens`](@ref).
"""
function opscenarios(rp::StratNodeReprPeriod{T,RepresentativePeriod{T,OP}}) where {T,OP}
    return StratNodeReprOpScens(
        _strat_per(rp),
        _branch(rp),
        _rper(rp),
        mult_strat(rp),
        mult_repr(rp),
        probability_branch(rp),
        opscenarios(rp.operational.operational),
    )
end

"""
When the `TimeStructure` is a [`StratNodeReprPeriod`](@ref) with a [`SingleReprPeriod`](@ref),
`opscenarios` returns the iterator [`StratNodeOpScens`](@ref) as the overall time structure
does not include representative periods.
"""
function opscenarios(rp::StratNodeReprPeriod{T,SingleReprPeriod{T,OP}}) where {T,OP}
    return StratNodeOpScens(
        _strat_per(rp),
        _branch(rp),
        mult_strat(rp),
        probability_branch(rp),
        opscenarios(rp.operational.ts),
    )
end

function strat_node_period(oscs::StratNodeReprOpScens, next, state)
    return StratNodeReprOpScenario(
        _strat_per(oscs),
        _branch(oscs),
        _rper(oscs),
        state,
        mult_strat(oscs),
        mult_repr(oscs),
        mult_scen(next),
        probability_branch(oscs),
        probability(next),
        next,
    )
end

Base.eltype(_::StratNodeReprOpScens) = StratNodeReprOpScenario

"""
When the `TimeStructure` is a [`StratNode`](@ref) with [`RepresentativePeriods`](@ref),
`opscenarios` returns an `Array` of all [`StratNodeReprOpScenario`](@ref)s.
"""
function opscenarios(n::StratNode{S,T,OP}) where {S,T,OP<:RepresentativePeriods}
    return collect(Iterators.flatten(opscenarios(rp) for rp in repr_periods(n)))
end

"""
When the `TimeStructure` is a [`TwoLevelTree`](@ref), `opscenarios` returns an `Array` of
all [`StratNodeOperationalScenario`](@ref)s or [`StratNodeReprOpScenario`](@ref)s types,
dependening on whether the [`TwoLevelTree`](@ref) includes [`RepresentativePeriods`](@ref)
or not.

These are equivalent to a [`StratOperationalScenario`](@ref) and [`StratReprOpscenario`](@ref)
of a [`TwoLevel`](@ref) time structure.
"""
function opscenarios(ts::TwoLevelTree)
    return collect(Iterators.flatten(opscenarios(sp) for sp in strat_periods(ts)))
end
function opscenarios(
    ts::TwoLevelTree{T,StratNode{S,T,OP}},
) where {S,T,OP<:RepresentativePeriods}
    return collect(
        Iterators.flatten(
            opscenarios(rp) for sp in strat_periods(ts) for rp in repr_periods(sp)
        ),
    )
end
