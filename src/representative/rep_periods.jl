"""
    abstract type AbstractRepresentativePeriod{T} <: TimeStructurePeriod{T}

Abstract type used for time structures that represent a representative period.
These periods are obtained when iterating through the representative periods of a time
structure declared by the function [`repr_periods`](@ref).
"""
abstract type AbstractRepresentativePeriod{T} <: TimeStructurePeriod{T} end

function _rper(rp::AbstractRepresentativePeriod)
    return error("_rper() not implemented for $(typeof(rp))")
end

isfirst(rp::AbstractRepresentativePeriod) = _rper(rp) == 1

has_opscenarios(ts::AbstractRepresentativePeriod) = has_opscenarios(ts.operational)
has_repr_periods(::AbstractRepresentativePeriod) = false

"""
    mult_repr(rp)

Returns the multiplication factor to be used for this representative period when
comparing with the representative periods structure it is part of.
"""
mult_repr(rp::AbstractRepresentativePeriod) = 1

function Base.isless(rp1::AbstractRepresentativePeriod, rp2::AbstractRepresentativePeriod)
    return _rper(rp1) < _rper(rp2)
end

abstract type RepresentativeIndexable end

struct HasReprIndex <: RepresentativeIndexable end
struct NoReprIndex <: RepresentativeIndexable end

RepresentativeIndexable(::Type) = NoReprIndex()
RepresentativeIndexable(::Type{<:AbstractRepresentativePeriod}) = HasReprIndex()
RepresentativeIndexable(::Type{<:TimePeriod}) = HasReprIndex()

"""
    struct SingleReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A type representing a single representative period supporting iteration over its
time periods. It is created when iterating through [`SingleReprPeriodWrapper`](@ref).
"""
struct SingleReprPeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}
    ts::OP
end

_rper(rp::SingleReprPeriod) = 1

mult_repr(rp::SingleReprPeriod) = 1.0

operational_type(rp::SingleReprPeriod) = typeof(rp.ts)

has_opscenarios(ts::SingleReprPeriod) = has_opscenarios(ts.ts)

StrategicIndexable(::Type{<:SingleReprPeriod}) = HasStratIndex()

Base.length(rp::SingleReprPeriod) = length(rp.ts)
function Base.iterate(rp::SingleReprPeriod, state = nothing)
    next = isnothing(state) ? iterate(rp.ts) : iterate(rp.ts, state)
    return next
end
Base.eltype(::Type{SingleReprPeriod{T,OP}}) where {T,OP} = eltype(OP)
Base.last(rp::SingleReprPeriod) = last(rp.ts)

"""
    struct SingleReprPeriodWrapper{T,OP<:TimeStructure{T}} <: TimeStructInnerIter{T}

Type for iterating through the individual representative periods of a time structure
without [`RepresentativePeriods`](@ref). It is automatically created through the function
[`repr_periods`](@ref).
"""
struct SingleReprPeriodWrapper{T,OP<:TimeStructure{T}} <: TimeStructInnerIter{T}
    ts::OP
end

_oper_struct(rpers::SingleReprPeriodWrapper) = rpers.ts

# Add basic functions of iterators
Base.length(rpers::SingleReprPeriodWrapper) = 1
Base.eltype(::Type{SingleReprPeriodWrapper{T,OP}}) where {T,OP} = SingleReprPeriod{T,OP}
function Base.iterate(rpers::SingleReprPeriodWrapper, state = nothing)
    !isnothing(state) && return nothing
    return SingleReprPeriod(_oper_struct(rpers)), 1
end
Base.last(rpers::SingleReprPeriodWrapper) = SingleReprPeriod(_oper_struct(rpers))

"""
    repr_periods(ts::TimeStructure)

This function returns a type for iterating through the individual representative
periods of a `TimeStructure`. The type of the iterator is dependent on the type of the
input `TimeStructure`.

When the `TimeStructure` is a `TimeStructure`, `repr_periods` returns a
[`SingleReprPeriodWrapper`](@ref). This corresponds to the default behavior.
"""
repr_periods(ts::TimeStructure) = SingleReprPeriodWrapper(ts)

"""
When the `TimeStructure` is a [`SingleStrategicScenario`](@ref) or
[`SingleStrategicScenarioWrapper`](@ref), `repr_periods` returns the value of its internal
[`TimeStructure`](@ref).
"""
repr_periods(sc::SingleStrategicScenario) = repr_periods(sc.ts)
repr_periods(sc::SingleStrategicScenarioWrapper) = repr_periods(sc.ts)

"""
    struct RepresentativePeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}

A type representing a single representative period supporting iteration over its
time periods. It is created when iterating through [`ReprPers`](@ref).
"""
struct RepresentativePeriod{T,OP<:TimeStructure{T}} <: AbstractRepresentativePeriod{T}
    rp::Int
    mult_rp::Float64
    operational::OP
end

_rper(rp::RepresentativePeriod) = rp.rp

mult_repr(rp::RepresentativePeriod) = rp.mult_rp

operational_type(rp::RepresentativePeriod) = typeof(rp.operational)

Base.show(io::IO, rp::RepresentativePeriod) = print(io, "rp-$(_rper(rp))")

# Provide a constructor to simplify the design
function ReprPeriod(rp::RepresentativePeriod, per::TimePeriod)
    mult = mult_repr(rp) * multiple(per)
    return ReprPeriod(_rper(rp), per, mult)
end

# Add basic functions of iterators
Base.length(rp::RepresentativePeriod) = length(rp.operational)
function Base.eltype(_::Type{RepresentativePeriod{T,OP}}) where {T,OP}
    return _eltype(ReprPeriod, eltype(OP))
end
function Base.iterate(rp::RepresentativePeriod, state = nothing)
    next = isnothing(state) ? iterate(rp.operational) : iterate(rp.operational, state)
    isnothing(next) && return nothing

    return ReprPeriod(rp, next[1]), next[2]
end
function Base.getindex(rp::RepresentativePeriod, index::Int)
    per = rp.operational[index]
    return ReprPeriod(rp, per)
end
function Base.eachindex(rp::RepresentativePeriod)
    return eachindex(rp.operational)
end
function Base.last(rp::RepresentativePeriod)
    per = last(rp.operational)
    return ReprPeriod(rp, per)
end

"""
    struct ReprPers{S,T,OP} <: TimeStructInnerIter{T}

Type for iterating through the individual representative periods of a
[`RepresentativePeriods`](@ref) time structure. It is automatically created through the
function [`repr_periods`](@ref).
"""
struct ReprPers{S,T,OP} <: TimeStructInnerIter{T}
    ts::RepresentativePeriods{S,T,OP}
end

_oper_struct(rpers::ReprPers) = rpers.ts

"""
When the `TimeStructure` is a [`RepresentativePeriods`](@ref), `repr_periods` returns the
iterator [`ReprPers`](@ref).
"""
repr_periods(ts::RepresentativePeriods) = ReprPers(ts)

# Provide a constructor to simplify the design
function RepresentativePeriod(rpers::ReprPers, per::Int)
    return RepresentativePeriod(
        per,
        _multiple_adj(_oper_struct(rpers), per),
        _oper_struct(rpers).rep_periods[per],
    )
end

# Add basic functions of iterators
Base.length(rpers::ReprPers) = _oper_struct(rpers).len
Base.eltype(::Type{ReprPers{S,T,OP}}) where {S,T,OP} = _eltype(RepresentativePeriod{T}, OP)
function Base.iterate(rpers::ReprPers, state = nothing)
    per = isnothing(state) ? 1 : state + 1
    per > length(rpers) && return nothing

    return RepresentativePeriod(rpers, per), per
end
function Base.getindex(rpers::ReprPers, index::Int)
    return RepresentativePeriod(rpers, index)
end
function Base.eachindex(rpers::ReprPers)
    return eachindex(_oper_struct(rpers).rep_periods)
end
Base.last(rpers::ReprPers) = RepresentativePeriod(rpers, length(rpers))
