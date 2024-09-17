"""
    StratOperationalScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}

A type representing a single operational scenario supporting iteration over its
time periods. It is created when iterating through [`StratOpScens`](@ref).
"""
struct StratOperationalScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    sp::Int
    scen::Int
    mult_sp::Float64
    mult_scen::Float64
    probability::Float64
    operational::OP
end

_opscen(osc::StratOperationalScenario) = osc.scen
_strat_per(osc::StratOperationalScenario) = osc.sp

probability(osc::StratOperationalScenario) = osc.probability
mult_scen(osc::StratOperationalScenario) = osc.mult_scen
mult_strat(osc::StratOperationalScenario) = osc.mult_sp

StrategicIndexable(::Type{<:StratOperationalScenario}) = HasStratIndex()
ScenarioIndexable(::Type{<:StratOperationalScenario}) = HasScenarioIndex()

# Provide a constructor to simplify the design
function OperationalPeriod(osc::StratOperationalScenario, per)
    mult = mult_strat(osc) * multiple(per)
    return OperationalPeriod(osc.sp, per, mult)
end

function Base.show(io::IO, osc::StratOperationalScenario)
    return print(io, "sp$(osc.sp)-sc$(osc.scen)")
end

# Add basic functions of iterators
Base.length(osc::StratOperationalScenario) = length(osc.operational)
function Base.eltype(::Type{StratOperationalScenario{T,OP}}) where {T,OP}
    return OperationalPeriod
end
function Base.iterate(osc::StratOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(osc.operational) :
        iterate(osc.operational, state)
    isnothing(next) && return nothing

    return OperationalPeriod(osc, next[1]), next[2]
end
function Base.getindex(osc::StratOperationalScenario, index)
    per = osc.operational[index]
    return OperationalPeriod(osc, per)
end
function Base.eachindex(osc::StratOperationalScenario)
    return eachindex(osc.operational)
end
function Base.last(osc::StratOperationalScenario)
    per = last(osc.operational)
    return OperationalPeriod(osc, per)
end

"""
    StratOpScens{OP}

Type for iterating through the individual operational scenarios of a
[`StrategicPeriod`](@ref) time structure. It is automatically created through the function
[`opscenarios`](@ref).
"""
struct StratOpScens{OP}
    sp::Int
    mult_sp::Float64
    opscens::OP
end

_strat_per(oscs::StratOpScens) = oscs.sp

mult_strat(oscs::StratOpScens) = oscs.mult_sp

"""
When the `TimeStructure` is a [`StrategicPeriod`](@ref), `opscenarios` returns the iterator
[`StratOpScens`](@ref).
"""
function opscenarios(sp::StrategicPeriod{S,T,OP}) where {S,T,OP}
    return StratOpScens(_strat_per(sp), mult_strat(sp), opscenarios(sp.operational))
end

"""
When the `TimeStructure` is a [`TwoLevel`](@ref), `opscenarios` returns a vector of
[`StratOperationalScenario`](@ref)s.
"""
function opscenarios(ts::TwoLevel{S,T,OP}) where {S,T,OP}
    return collect(
        Iterators.flatten(opscenarios(sp) for sp in strategic_periods(ts)),
    )
end

# Provide a constructor to simplify the design
function StratOperationalScenario(oscs::StratOpScens, scen::Int, per)
    return StratOperationalScenario(
        _strat_per(oscs),
        scen,
        mult_strat(oscs),
        mult_scen(per),
        probability(per),
        per
    )
end

Base.length(oscs::StratOpScens) = length(oscs.opscens)
function Base.iterate(oscs::StratOpScens, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(oscs.opscens) :
        iterate(oscs.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratOperationalScenario(oscs, _opscen(next[1]), next[1]), (next[2], scen + 1)
end
function Base.getindex(oscs::StratOpScens, index::Int)
    per = oscs.opscens[index]
    return StratOperationalScenario(oscs, index, per)
end
function Base.eachindex(oscs::StratOpScens)
    return eachindex(oscs.opscens)
end
function Base.last(oscs::StratOpScens)
    per = last(oscs.repr)
    return StratOperationalScenario(oscs, _opscen(per), per)
end

"""
    StratReprOpscenario{T, OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A type representing a single representative period supporting iteration over its
time periods. It is created when iterating through [`StratReprPeriods`](@ref).
"""
struct StratReprOpscenario{T, OP<:TimeStructure{T}} <:
    AbstractOperationalScenario{T}
    sp::Int
    rp::Int
    opscen::Int
    mult_sp::Float64
    mult_rp::Float64
    probability::Float64
    operational::OP
end

_opscen(osc::StratReprOpscenario) = osc.opscen
_rper(osc::StratReprOpscenario) = osc.rp
_strat_per(osc::StratReprOpscenario) = osc.sp

probability(osc::StratReprOpscenario) = osc.probability
mult_scen(osc::StratReprOpscenario) = osc.multiple_scen
mult_repr(osc::StratReprOpscenario) = osc.mult_rp
mult_strat(osc::StratReprOpscenario) = osc.mult_sp

StrategicIndexable(::Type{<:StratReprOpscenario}) = HasStratIndex()
function RepresentativeIndexable(::Type{<:StratReprOpscenario})
    return HasReprIndex()
end
ScenarioIndexable(::Type{<:StratReprOpscenario}) = HasScenarioIndex()

# Provide a constructor to simplify the design
function OperationalPeriod(osc::StratReprOpscenario, per)
    rper = ReprPeriod(_rper(osc), per, mult_repr(osc) * multiple(per))
    mult = mult_strat(osc) * mult_repr(osc) * multiple(per)
    return OperationalPeriod(_strat_per(osc), rper, mult)
end

function Base.show(io::IO, osc::StratReprOpscenario)
    return print(io, "sp$(osc.sp)-rp$(_rper(osc))-sc$(osc.opscen)")
end

# Add basic functions of iterators
Base.length(osc::StratReprOpscenario) = length(osc.operational)
function Base.eltype(::Type{StratReprOpscenario{T,OP}}) where {T,OP}
    return OperationalPeriod
end
function Base.iterate(osc::StratReprOpscenario, state = nothing)
    next =
        isnothing(state) ? iterate(osc.operational) :
        iterate(osc.operational, state)
    isnothing(next) && return nothing

    return OperationalPeriod(osc, next[1]), next[2]
end
function Base.getindex(osc::StratReprOpscenario, index)
    per = osc.operational[index]
    return OperationalPeriod(osc, per)
end
function Base.eachindex(osc::StratReprOpscenario)
    return eachindex(osc.operational)
end
function Base.last(osc::StratReprOpscenario)
    per = last(osc.operational)
    return OperationalPeriod(osc, per)
end

"""
    StratReprOpscenarios{OP}

Type for iterating through the individual operational scenarios of a
[`StrategicPeriod`](@ref) time structure with [`RepresentativePeriods`](@ref). It is
automatically created through the function [`opscenarios`](@ref).
"""
struct StratReprOpscenarios{OP}
    srp::StratReprPeriod
    opscens::OP
end

_rper(oscs::StratReprOpscenarios) = _rper(oscs.srp)
_strat_per(oscs::StratReprOpscenarios) = _strat_per(oscs.srp)

mult_repr(oscs::StratReprOpscenarios) = mult_repr(oscs.srp)
mult_strat(oscs::StratReprOpscenarios) = mult_strat(oscs.srp)

function opscenarios(
    srp::StratReprPeriod{T,RepresentativePeriod{T,OP}},
) where {T,OP}
    return StratReprOpscenarios(srp, opscenarios(srp.operational.operational))
end
function opscenarios(rp::StratReprPeriod)
    return StratOpScens(_strat_per(rp), mult_strat(rp), opscenarios(rp.operational))
end

"""
When the `TimeStructure` is a [`StrategicPeriod`](@ref) with [`RepresentativePeriods`](@ref),
`opscenarios` returns a vector of [`StratReprOpscenario`](@ref)s.
"""
function opscenarios(
    sp::StrategicPeriod{S1,T,RepresentativePeriods{S2,T,OP}},
) where {S1,S2,T,OP}
    return collect(
        Iterators.flatten(opscenarios(rp) for rp in repr_periods(sp)),
    )
end

"""
When the `TimeStructure` is a [`TwoLevel`](@ref) with [`RepresentativePeriods`](@ref),
`opscenarios` returns a vector of [`StratReprOpscenario`](@ref)s.
"""
function opscenarios(
    ts::TwoLevel{S1,T,RepresentativePeriods{S2,T,OP}},
) where {S1,S2,T,OP}
    return collect(
        Iterators.flatten(opscenarios(rp) for sp in strategic_periods(ts) for rp in repr_periods(sp)),
    )
end

# Provide a constructor to simplify the design
function StratReprOpscenario(oscs::StratReprOpscenarios, scen, per)
    return StratReprOpscenario(
        _strat_per(oscs),
        _rper(oscs),
        scen,
        mult_strat(oscs),
        mult_repr(oscs),
        probability(per),
        per,
    )
end

# Add basic functions of iterators
Base.length(oscs::StratReprOpscenarios) = length(oscs.opscens)
function Base.eltype(_::Type{StratReprOpscenarios{SC}}) where {T,OP,SC<:OpScens{T,OP}}
    return StratReprOpscenario{T,eltype(SC)}
end
function Base.iterate(oscs::StratReprOpscenarios, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(oscs.opscens) :
        iterate(oscs.opscens, state[1])
    isnothing(next) && return nothing

    return StratReprOpscenario(oscs, state[2], next[1]), (next[2], state[2] + 1)
end
function Base.getindex(oscs::StratReprOpscenarios, index::Int)
    per = oscs.opscens[index]
    return StratReprOpscenario(oscs, _opscen(per), per)
end
function Base.eachindex(oscs::StratReprOpscenarios)
    return eachindex(oscs.opscens)
end
function Base.last(oscs::StratReprOpscenarios)
    per = last(oscs.opscens)
    return StratReprOpscenario(oscs, _opscen(per), per)
end
