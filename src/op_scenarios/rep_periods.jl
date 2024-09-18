"""
    struct ReprOpScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}

A type representing a single operational scenarios supporting iteration over its
time periods. It is created when iterating through [`RepOpScens`](@ref).
"""
struct ReprOpScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    rp::Int
    scen::Int
    mult_rp::Float64
    mult_scen::Float64
    probability::Float64
    operational::OP
end

_opscen(osc::ReprOpScenario) = osc.scen
_rper(osc::ReprOpScenario) = osc.rp

probability(osc::ReprOpScenario) = osc.probability
mult_scen(osc::ReprOpScenario) = osc.mult_scen
mult_repr(osc::ReprOpScenario) = osc.mult_rp

RepresentativeIndexable(::Type{<:ReprOpScenario}) = HasReprIndex()

# Provide a constructor to simplify the design
function ReprPeriod(osc::ReprOpScenario, per)
    mult = mult_repr(osc) * multiple(per)
    return ReprPeriod(_rper(osc), per, mult)
end

function Base.show(io::IO, osc::ReprOpScenario)
    return print(io, "rp$(_rper(osc))-sc$(_opscen(osc))")
end

# Add basic functions of iterators
Base.length(osc::ReprOpScenario) = length(osc.operational)
function Base.eltype(_::ReprOpScenario{T,OP}) where {T,OP}
    return ReprPeriod{eltype(OP)}
end
function Base.iterate(osc::ReprOpScenario, state = nothing)
    next = isnothing(state) ? iterate(osc.operational) : iterate(osc.operational, state)
    next === nothing && return nothing

    return ReprPeriod(osc, next[1]), next[2]
end
function Base.getindex(osc::ReprOpScenario, index::Int)
    per = osc.operational[index]
    return ReprPeriod(osc, per)
end
function Base.eachindex(osc::ReprOpScenario)
    return eachindex(osc.operational)
end
function Base.last(osc::ReprOpScenario)
    per = last(osc.operational)
    return ReprPeriod(osc, per)
end

"""
    struct RepOpScens{T,OP<:TimeStructInnerIter{T}} <: TimeStructOuterIter{T}

Type for iterating through the individual operational scenarios of a
[`RepresentativePeriod`](@ref) time structure. It is automatically created through the
function [`opscenarios`](@ref).
"""
struct RepOpScens{T,OP<:TimeStructInnerIter{T}} <: TimeStructOuterIter{T}
    rp::Int
    mult_rp::Float64
    opscens::OP
end

_rper(oscs::RepOpScens) = oscs.rp

mult_repr(oscs::RepOpScens) = oscs.mult_rp

_oper_struct(oscs::RepOpScens) = oscs.opscens

"""
When the `TimeStructure` is a [`RepresentativePeriod`](@ref) with [`OperationalScenarios`](@ref),
`opscenarios` returns the iterator [`RepOpScens`](@ref).
"""
function opscenarios(rep::RepresentativePeriod{T,OperationalScenarios{T,OP}}) where {T,OP}
    return RepOpScens(_rper(rep), mult_repr(rep), opscenarios(rep.operational))
end

# Provide a constructor to simplify the design
function ReprOpScenario(oscs::RepOpScens, scen::Int, per)
    return ReprOpScenario(
        _rper(oscs),
        scen,
        mult_repr(oscs),
        _multiple_adj(_oper_struct(_oper_struct(oscs)), scen),
        probability(per),
        per,
    )
end

# Add basic functions of iterators
Base.length(oscs::RepOpScens) = length(_oper_struct(_oper_struct(oscs)).scenarios)
function Base.eltype(_::Type{RepOpScens{SC}}) where {T,OP,SC<:OpScens{T,OP}}
    return ReprOpScenario{T,eltype(SC)}
end
function Base.iterate(oscs::RepOpScens, state = (nothing, 1))
    next = isnothing(state[1]) ? iterate(_oper_struct(oscs)) : iterate(_oper_struct(oscs), state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return ReprOpScenario(oscs, _opscen(next[1]), next[1]), (next[2], scen + 1)
end
function Base.getindex(oscs::RepOpScens, index::Int)
    per = _oper_struct(oscs)[index]
    return ReprOpScenario(oscs, _opscen(per), per)
end
function Base.eachindex(oscs::RepOpScens)
    return eachindex(_oper_struct(oscs))
end
function Base.last(oscs::RepOpScens)
    per = last(_oper_struct(oscs))
    return ReprOpScenario(oscs, _opscen(per), per)
end

"""
When the `TimeStructure` is a [`SingleReprPeriod`](@ref), `opscenarios` returns the
correct behavior based on the substructure.
"""
opscenarios(ts::SingleReprPeriod) = opscenarios(ts.ts)
"""
When the `TimeStructure` is a [`RepresentativePeriods`](@ref), `opscenarios` returns an
`Array` of all [`ReprOpScenario`](@ref)s.
"""
function opscenarios(ts::RepresentativePeriods)
    return collect(Iterators.flatten(opscenarios(rp) for rp in repr_periods(ts)))
end
