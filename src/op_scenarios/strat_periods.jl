"""
    struct StratOpScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}

A type representing a single operational scenario supporting iteration over its
time periods. It is created when iterating through [`StratOpScens`](@ref).
"""
struct StratOpScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    sp::Int
    scen::Int
    mult_sp::Float64
    mult_scen::Float64
    probability::Float64
    operational::OP
end

_strat_per(osc::StratOpScenario) = osc.sp
_opscen(osc::StratOpScenario) = osc.scen

mult_strat(osc::StratOpScenario) = osc.mult_sp
mult_scen(osc::StratOpScenario) = osc.mult_scen
probability(osc::StratOpScenario) = osc.probability

StrategicIndexable(::Type{<:StratOpScenario}) = HasStratIndex()
ScenarioIndexable(::Type{<:StratOpScenario}) = HasScenarioIndex()

# Provide a constructor to simplify the design
function OperationalPeriod(osc::StratOpScenario, per)
    mult = mult_strat(osc) * multiple(per)
    return OperationalPeriod(osc.sp, per, mult)
end

function Base.show(io::IO, osc::StratOpScenario)
    return print(io, "sp$(osc.sp)-sc$(osc.scen)")
end

# Add basic functions of iterators
Base.length(osc::StratOpScenario) = length(osc.operational)
function Base.eltype(::Type{StratOpScenario{T,OP}}) where {T,OP}
    return OperationalPeriod{eltype(OP)}
end
function Base.iterate(osc::StratOpScenario, state = nothing)
    next = isnothing(state) ? iterate(osc.operational) : iterate(osc.operational, state)
    isnothing(next) && return nothing

    return OperationalPeriod(osc, next[1]), next[2]
end
function Base.getindex(osc::StratOpScenario, index)
    per = osc.operational[index]
    return OperationalPeriod(osc, per)
end
function Base.eachindex(osc::StratOpScenario)
    return eachindex(osc.operational)
end
function Base.last(osc::StratOpScenario)
    per = last(osc.operational)
    return OperationalPeriod(osc, per)
end

"""
    struct StratOpScens{T,OP<:TimeStructInnerIter{T}} <: TimeStructOuterIter{T}

Type for iterating through the individual operational scenarios of a
[`StrategicPeriod`](@ref) time structure. It is automatically created through the function
[`opscenarios`](@ref).
"""
struct StratOpScens{T,OP<:TimeStructInnerIter{T}} <: TimeStructOuterIter{T}
    sp::Int
    mult_sp::Float64
    opscens::OP
end

_strat_per(oscs::StratOpScens) = oscs.sp

mult_strat(oscs::StratOpScens) = oscs.mult_sp

_oper_struct(oscs::StratOpScens) = oscs.opscens

"""
When the `TimeStructure` is a [`StrategicPeriod`](@ref), `opscenarios` returns the iterator
[`StratOpScens`](@ref).
"""
function opscenarios(sp::StrategicPeriod{S,T,OP}) where {S,T,OP}
    return StratOpScens(_strat_per(sp), mult_strat(sp), opscenarios(sp.operational))
end
# Provide a constructor to simplify the design
function StratOpScenario(oscs::StratOpScens, scen::Int, per)
    return StratOpScenario(
        _strat_per(oscs),
        scen,
        mult_strat(oscs),
        mult_scen(per),
        probability(per),
        per,
    )
end

# Add basic functions of iterators
Base.length(oscs::StratOpScens) = length(_oper_struct(oscs))
function Base.iterate(oscs::StratOpScens, state = (nothing, 1))
    next = isnothing(state[1]) ? iterate(_oper_struct(oscs)) : iterate(_oper_struct(oscs), state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratOpScenario(oscs, _opscen(next[1]), next[1]), (next[2], scen + 1)
end
function Base.getindex(oscs::StratOpScens, index::Int)
    per = _oper_struct(oscs)[index]
    return StratOpScenario(oscs, index, per)
end
function Base.eachindex(oscs::StratOpScens)
    return eachindex(_oper_struct(oscs))
end
function Base.last(oscs::StratOpScens)
    per = last(oscs.repr)
    return StratOpScenario(oscs, _opscen(per), per)
end

"""
    struct StratReprOpScenario{T, OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A type representing a single representative period supporting iteration over its
time periods. It is created when iterating through [`StratReprPers`](@ref).
"""
struct StratReprOpScenario{T,OP<:TimeStructure{T}} <: AbstractOperationalScenario{T}
    sp::Int
    rp::Int
    scen::Int
    mult_sp::Float64
    mult_rp::Float64
    mult_scen::Float64
    probability::Float64
    operational::OP
end

_opscen(osc::StratReprOpScenario) = osc.scen
_rper(osc::StratReprOpScenario) = osc.rp
_strat_per(osc::StratReprOpScenario) = osc.sp

probability(osc::StratReprOpScenario) = osc.probability
mult_strat(osc::StratReprOpScenario) = osc.mult_sp
mult_repr(osc::StratReprOpScenario) = osc.mult_rp
mult_scen(osc::StratReprOpScenario) = osc.mult_scen

StrategicIndexable(::Type{<:StratReprOpScenario}) = HasStratIndex()
function RepresentativeIndexable(::Type{<:StratReprOpScenario})
    return HasReprIndex()
end
ScenarioIndexable(::Type{<:StratReprOpScenario}) = HasScenarioIndex()

# Provide a constructor to simplify the design
function OperationalPeriod(osc::StratReprOpScenario, per)
    rper = ReprPeriod(_rper(osc), per, mult_repr(osc) * multiple(per))
    mult = mult_strat(osc) * mult_repr(osc) * multiple(per)
    return OperationalPeriod(_strat_per(osc), rper, mult)
end

function Base.show(io::IO, osc::StratReprOpScenario)
    return print(io, "sp$(osc.sp)-rp$(_rper(osc))-sc$(osc.opscen)")
end

# Add basic functions of iterators
Base.length(osc::StratReprOpScenario) = length(osc.operational)
function Base.eltype(::Type{StratReprOpScenario{T,OP}}) where {T,OP}
    return OperationalPeriod{ReprPeriod{eltype(OP)}}
end
function Base.iterate(osc::StratReprOpScenario, state = nothing)
    next = isnothing(state) ? iterate(osc.operational) : iterate(osc.operational, state)
    isnothing(next) && return nothing

    return OperationalPeriod(osc, next[1]), next[2]
end
function Base.getindex(osc::StratReprOpScenario, index)
    per = osc.operational[index]
    return OperationalPeriod(osc, per)
end
function Base.eachindex(osc::StratReprOpScenario)
    return eachindex(osc.operational)
end
function Base.last(osc::StratReprOpScenario)
    per = last(osc.operational)
    return OperationalPeriod(osc, per)
end

"""
    struct StratReprOpScens{T,OP<:TimeStructInnerIter{T}} <: TimeStructOuterIter{T}

Type for iterating through the individual operational scenarios of a
[`StrategicPeriod`](@ref) time structure with [`RepresentativePeriods`](@ref). It is
automatically created through the function [`opscenarios`](@ref).
"""
struct StratReprOpScens{T,OP<:TimeStructInnerIter{T}} <: TimeStructOuterIter{T}
    sp::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    opscens::OP
end

_strat_per(oscs::StratReprOpScens) = oscs.sp
_rper(oscs::StratReprOpScens) = oscs.rp

mult_strat(oscs::StratReprOpScens) = oscs.mult_sp
mult_repr(oscs::StratReprOpScens) = oscs.mult_rp

_oper_struct(oscs::StratReprOpScens) = oscs.opscens

function opscenarios(rp::StratReprPeriod{T,RepresentativePeriod{T,OP}}) where {T,OP}
    return StratReprOpScens(
        _strat_per(rp),
        _rper(rp),
        mult_strat(rp),
        mult_repr(rp),
        opscenarios(rp.operational.operational),
    )
end
function opscenarios(rp::StratReprPeriod)
    return StratOpScens(_strat_per(rp), mult_strat(rp), opscenarios(rp.operational))
end

"""
When the `TimeStructure` is a [`StrategicPeriod`](@ref) with [`RepresentativePeriods`](@ref),
`opscenarios` returns a vector of [`StratReprOpScenario`](@ref)s.
"""
function opscenarios(
    sp::StrategicPeriod{S1,T,RepresentativePeriods{S2,T,OP}},
) where {S1,S2,T,OP}
    return collect(Iterators.flatten(opscenarios(rp) for rp in repr_periods(sp)))
end

# Provide a constructor to simplify the design
function StratReprOpScenario(oscs::StratReprOpScens, scen, per)
    return StratReprOpScenario(
        _strat_per(oscs),
        _rper(oscs),
        scen,
        mult_strat(oscs),
        mult_repr(oscs),
        mult_scen(per),
        probability(per),
        per,
    )
end

# Add basic functions of iterators
Base.length(oscs::StratReprOpScens) = length(_oper_struct(oscs))
function Base.eltype(_::Type{StratReprOpScens{SC}}) where {T,OP,SC<:OpScens{T,OP}}
    return StratReprOpScenario{T,eltype(SC)}
end
function Base.iterate(oscs::StratReprOpScens, state = (nothing, 1))
    next = isnothing(state[1]) ? iterate(_oper_struct(oscs)) : iterate(_oper_struct(oscs), state[1])
    isnothing(next) && return nothing

    return StratReprOpScenario(oscs, state[2], next[1]), (next[2], state[2] + 1)
end
function Base.getindex(oscs::StratReprOpScens, index::Int)
    per = _oper_struct(oscs)[index]
    return StratReprOpScenario(oscs, _opscen(per), per)
end
function Base.eachindex(oscs::StratReprOpScens)
    return eachindex(_oper_struct(oscs))
end
function Base.last(oscs::StratReprOpScens)
    per = last(_oper_struct(oscs))
    return StratReprOpScenario(oscs, _opscen(per), per)
end

"""
When the `TimeStructure` is a [`SingleStrategicPeriod`](@ref), `opscenarios` returns the
correct behavior based on the substructure.
"""
opscenarios(ts::SingleStrategicPeriod) = opscenarios(ts.ts)
"""
When the `TimeStructure` is a [`TwoLevel`](@ref), `opscenarios` returns a vector of
[`StratOpScenario`](@ref)s.
"""
function opscenarios(ts::TwoLevel{S,T,OP}) where {S,T,OP}
    return collect(Iterators.flatten(opscenarios(sp) for sp in strategic_periods(ts)))
end
"""
When the `TimeStructure` is a [`TwoLevel`](@ref) with [`RepresentativePeriods`](@ref),
`opscenarios` returns a vector of [`StratReprOpScenario`](@ref)s.
"""
function opscenarios(ts::TwoLevel{S1,T,RepresentativePeriods{S2,T,OP}}) where {S1,S2,T,OP}
    return collect(
        Iterators.flatten(
            opscenarios(rp) for sp in strategic_periods(ts) for rp in repr_periods(sp)
        ),
    )
end
