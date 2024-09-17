"""
    ReprOperationalScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}

A type representing a single operational scenarios supporting iteration over its
time periods. It is created when iterating through [`RepOpScens`](@ref).
"""
struct ReprOperationalScenario{T,OP<:TimeStructure{T}} <:
    AbstractOperationalScenario{T}
 rp::Int
 scen::Int
 probability::Float64
 multiple_repr::Float64
 multiple_scen::Float64
 operational::OP
end

_opscen(osc::ReprOperationalScenario) = osc.scen
_rper(osc::ReprOperationalScenario) = osc.rp

probability(osc::ReprOperationalScenario) = osc.probability
mult_scen(osc::ReprOperationalScenario) = osc.multiple_scen
mult_repr(osc::ReprOperationalScenario) = osc.multiple_repr

RepresentativeIndexable(::Type{<:ReprOperationalScenario}) = HasReprIndex()

# Provide a constructor to simplify the design
function ReprPeriod(osc::ReprOperationalScenario, per)
    mult_scp = mult_scen(osc) * multiple(per)
    mult_rp = mult_repr(osc) * mult_scp
    scp = ScenarioPeriod(_opscen(osc), probability(osc), mult_scp, per)
    return ReprPeriod(_rper(osc), scp, mult_rp)
end

function Base.show(io::IO, osc::ReprOperationalScenario)
    return print(io, "rp$(osc.rp)-sc$(osc.scen)")
end

# Add basic functions of iterators
Base.length(osc::ReprOperationalScenario) = length(osc.operational)
function Base.eltype(osc::ReprOperationalScenario{T,OP}) where {T,OP}
    return ReprPeriod{ScenarioPeriod{eltype(OP)}}
end
function Base.iterate(osc::ReprOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(osc.operational) :
        iterate(osc.operational, state)
    next === nothing && return nothing

    return ReprPeriod(osc, next[1]), next[2]
end
function Base.getindex(osc::ReprOperationalScenario, index::Int)
    per = osc.operational[index]
    return ReprPeriod(osc, per)
end
function Base.eachindex(osc::ReprOperationalScenario)
    return eachindex(osc.operational)
end
function Base.last(osc::ReprOperationalScenario)
    per = last(osc.operational)
    return ReprPeriod(osc, per)
end

"""
    RepOpScens{OP}

Type for iterating through the individual operational scenarios of a
[`RepresentativePeriod`](@ref) time structure. It is automatically created through the
function [`opscenarios`](@ref).
"""
struct RepOpScens{OP}
    rp::Int
    mult::Float64
    opscens::OP
end

_rper(oscs::RepOpScens) = oscs.rp

"""
When the `TimeStructure` is a [`RepresentativePeriod`](@ref) with [`OperationalScenarios`](@ref),
`opscenarios` returns the iterator [`RepOpScens`](@ref).
"""
function opscenarios(
    rep::RepresentativePeriod{T,OperationalScenarios{T,OP}},
) where {T,OP}
    return RepOpScens(_rper(rep), mult_repr(rep), rep.operational)
end

# Provide a constructor to simplify the design
function ReprOperationalScenario(oscs::RepOpScens, state::Int)
    return ReprOperationalScenario(
        _rper(oscs),
        state,
        oscs.opscens.probability[state],
        oscs.mult,
        _multiple_adj(oscs.opscens, state),
        oscs.opscens.scenarios[state]
    )
end

Base.length(oscs::RepOpScens) = length(oscs.opscens.scenarios)
function Base.eltype(_::RepOpScens{SC}) where {T,OP,SC<:OperationalScenarios{T,OP}}
    return ReprOperationalScenario{T,OP}
end
function Base.iterate(oscs::RepOpScens, state = nothing)
    scen = isnothing(state) ? 1 : state + 1
    scen > length(oscs) && return nothing

    return ReprOperationalScenario(oscs, scen), scen
end

"""
When the `TimeStructure` is a [`SingleReprPeriod`](@ref), `opscenarios` returns the
correct behavior based on the substructure.
"""
opscenarios(ts::SingleReprPeriod) = opscenarios(ts.ts)
"""
When the `TimeStructure` is a [`RepresentativePeriods`](@ref), `opscenarios` returns an
`Array` of all [`ReprOperationalScenario`](@ref)s.
"""
function opscenarios(ts::RepresentativePeriods)
    return collect(
        Iterators.flatten(opscenarios(rp) for rp in repr_periods(ts)),
    )
end
