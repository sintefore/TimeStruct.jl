"""
    abstract type AbstractOperationalScenario{T} <: TimeStructurePeriod{T}

Abstract type used for time structures that represent an operational scenario.
These periods are obtained when iterating through the operational scenarios of a time
structure declared by the function [`opscenarios`](@ref).
"""
abstract type AbstractOperationalScenario{T} <: TimeStructurePeriod{T} end

function _opscen(scen::AbstractOperationalScenario)
    return error("_opscen() not implemented for type $(typeof(scen))")
end
function probability(scen::AbstractOperationalScenario)
    return error("probabilty not implemented for type $(typeof(scen))")
end

"""
    probability_scen(scen)

The probability of a single scenario in a set of operational scenarios.
"""
probability_scen(scen::AbstractOperationalScenario) = probability(scen)

"""
    mult_scen(scen)

Returns the multiplication factor to be used for this scenario when
comparing with the overall set of operational scenarios.

If all scenarios in a set of operational scenarios are of equal duration
(preferred usage), this factor is equal to one. Otherwise this factor
would be equal to the ratio of the scenario with longest duration to
the duration of the given scenario.
"""
mult_scen(scen::AbstractOperationalScenario) = 1.0

abstract type ScenarioIndexable end

struct HasScenarioIndex <: ScenarioIndexable end
struct NoScenarioIndex <: ScenarioIndexable end

ScenarioIndexable(::Type) = NoScenarioIndex()
ScenarioIndexable(::Type{<:AbstractOperationalScenario}) = HasScenarioIndex()
ScenarioIndexable(::Type{<:TimePeriod}) = HasScenarioIndex()

"""
    struct SingleScenario{T,SC<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A type representing a single operational scenario supporting iteration over its
time periods. It is created when iterating through [`SingleScenarioWrapper`](@ref).
"""
struct SingleScenario{T,SC<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    ts::SC
end

_opscen(osc::SingleScenario) = 1
_repr_per(osc::SingleScenario) = 1
_strat_per(osc::SingleScenario) = 1

probability(osc::SingleScenario) = 1.0

StrategicIndexable(::Type{<:SingleScenario}) = HasStratIndex()
RepresentativeIndexable(::Type{<:SingleScenario}) = HasRepresentativeIndex()

# Add basic functions of iterators
Base.length(osc::SingleScenario) = length(osc.ts)
Base.eltype(::Type{SingleScenario{T,SC}}) where {T,SC} = eltype(SC)
function Base.iterate(osc::SingleScenario, state = nothing)
    if isnothing(state)
        return iterate(osc.ts)
    end
    return iterate(osc.ts, state)
end
function Base.getindex(osc::SingleScenario, index)
    return osc.ts[index]
end
function Base.eachindex(osc::SingleScenario)
    return eachindex(osc.ts)
end
Base.last(osc::SingleScenario) = last(osc.ts)
function Base.last( # TODO: Considering removing the function as the the structure is opposite
    osc::SingleScenario{T,RepresentativePeriod{T,OP}},
) where {T,OP}
    period = last(osc.ts.operational)
    return ReprPeriod(_rper(osc.ts), period, mult_repr(osc.ts) * multiple(period))
end

"""
    struct SingleScenarioWrapper{T,OP<:TimeStructure{T}} <: TimeStructInnerIter{T}

Type for iterating through the individual operational scenarios of a time structure
without [`OperationalScenarios`](@ref). It is automatically created through the function
[`opscenarios`](@ref).
"""
struct SingleScenarioWrapper{T,SC<:TimeStructure{T}} <: TimeStructInnerIter{T}
    ts::SC
end

_oper_struct(oscs::SingleScenarioWrapper) = oscs.ts

"""
    opscenarios(ts::TimeStructure)

This function returns a type for iterating through the individual operational scenarios
of a `TimeStructure`. The type of the iterator is dependent on the type of the input
`TimeStructure`.

When the `TimeStructure` is a `TimeStructure`, `opscenarios` returns a
[`SingleScenarioWrapper`](@ref). This corresponds to the default behavior.
"""
opscenarios(ts::TimeStructure) = SingleScenarioWrapper(ts)

# Add basic functions of iterators
Base.length(oscs::SingleScenarioWrapper) = 1
function Base.eltype(::Type{SingleScenarioWrapper{T,SC}}) where {T,SC}
    return SingleScenario{T,SC}
end
function Base.iterate(oscs::SingleScenarioWrapper, state = nothing)
    !isnothing(state) && return nothing
    return SingleScenario(_oper_struct(oscs)), 1
end

"""
    struct OperationalScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}

A type representing a single operational scenario supporting iteration over its
time periods. It is created when iterating through [`OpScens`](@ref).
"""
struct OperationalScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    scen::Int
    mult_scen::Float64
    probability::Float64
    operational::OP
end

_opscen(osc::OperationalScenario) = osc.scen

probability(osc::OperationalScenario) = osc.probability
mult_scen(osc::OperationalScenario) = osc.mult_scen

Base.show(io::IO, osc::OperationalScenario) = print(io, "sc-$(osc.scen)")

# Provide a constructor to simplify the design
function ScenarioPeriod(osc::OperationalScenario, per::TimePeriod)
    mult = mult_scen(osc) * multiple(per)
    return ScenarioPeriod(_opscen(osc), per, mult, probability(osc))
end

# Add basic functions of iterators
Base.length(osc::OperationalScenario) = length(osc.operational)
function Base.eltype(_::Type{OperationalScenario{T,OP}}) where {T,OP}
    return ScenarioPeriod{eltype(OP)}
end
function Base.iterate(osc::OperationalScenario, state = nothing)
    next = isnothing(state) ? iterate(osc.operational) : iterate(osc.operational, state)
    next === nothing && return nothing
    return ScenarioPeriod(osc, next[1]), next[2]
end
function Base.last(osc::OperationalScenario)
    return ScenarioPeriod(osc, last(osc.operational))
end
function Base.getindex(osc::OperationalScenario, index)
    per = osc.operational[index]
    return ScenarioPeriod(osc, per)
end
function Base.eachindex(osc::OperationalScenario)
    return eachindex(osc.operational)
end

"""
    struct OpScens{T,OP} <: TimeStructInnerIter{T}

Type for iterating through the individual operational scenarios of a
[`OperationalScenarios`](@ref) time structure. It is automatically created through the
function [`opscenarios`](@ref).
"""
struct OpScens{T,OP} <: TimeStructInnerIter{T}
    ts::OperationalScenarios{T,OP}
end

_oper_struct(oscs::OpScens) = oscs.ts

"""
When the `TimeStructure` is an [`OperationalScenarios`](@ref), `opscenarios` returns the
iterator [`OpScens`](@ref).
"""
opscenarios(oscs::OperationalScenarios) = OpScens(oscs)

# Provide a constructor to simplify the design
function OperationalScenario(oscs::OpScens, per::Int)
    return OperationalScenario(
        per,
        _multiple_adj(_oper_struct(oscs), per),
        _oper_struct(oscs).probability[per],
        _oper_struct(oscs).scenarios[per],
    )
end

# Add basic functions of iterators
Base.length(oscs::OpScens) = _oper_struct(oscs).len
function Base.eltype(_::Type{OpScens{T,OP}}) where {T,OP<:TimeStructure{T}}
    return OperationalScenario{T,OP}
end
function Base.iterate(oscs::OpScens, state = nothing)
    per = isnothing(state) ? 1 : state + 1
    per > length(oscs) && return nothing

    return OperationalScenario(oscs, per), per
end
function Base.getindex(oscs::OpScens, index::Int)
    return OperationalScenario(oscs, index)
end
function Base.eachindex(oscs::OpScens)
    return eachindex(_oper_struct(oscs).scenarios)
end
Base.last(oscs::OpScens) = OperationalScenario(oscs, length(oscs))
