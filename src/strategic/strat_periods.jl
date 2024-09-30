"""
    abstract type AbstractStrategicPeriod{S,T} <: TimeStructurePeriod{T}

Abstract type used for time structures that represent a strategic period.
These periods are obtained when iterating through the strategic periods of a time
structure declared by the function [`strat_periods`](@ref).
"""
abstract type AbstractStrategicPeriod{S,T} <: TimeStructurePeriod{T} end
"""
    abstract type AbstractStratPers{S,T} <: TimeStructInnerIter

Abstract type used for time structures that represent a collection of strategic periods,
obtained through calling the function [`strat_periods`](@ref).
"""
abstract type AbstractStratPers{T} <: TimeStructInnerIter{T} end

function _strat_per(sp::AbstractStrategicPeriod)
    return error("_strat_per() not implemented for $(typeof(sp))")
end

isfirst(sp::AbstractStrategicPeriod) = _strat_per(sp) == 1

"""
    mult_strat(sp)

Returns the multiplication factor to be used for this strategic period when
comparing the duration of the strategic period to the duration of the
time structure being used for the strategic period.
"""
mult_strat(sp::AbstractStrategicPeriod) = 1

function duration_strat(sp::AbstractStrategicPeriod)
    return error("duration_strat() not implemented for $(typeof(sp))")
end

function Base.isless(sp1::AbstractStrategicPeriod, sp2::AbstractStrategicPeriod)
    return _strat_per(sp1) < _strat_per(sp2)
end

abstract type StrategicIndexable end

struct HasStratIndex <: StrategicIndexable end
struct NoStratIndex <: StrategicIndexable end

StrategicIndexable(::Type) = NoStratIndex()
StrategicIndexable(::Type{<:AbstractStrategicPeriod}) = HasStratIndex()
StrategicIndexable(::Type{<:TimePeriod}) = HasStratIndex()

function start_time(sp::AbstractStrategicPeriod{S,T}, ts::TimeStructure{T}) where {S,T}
    return isfirst(sp) ? zero(S) :
           sum(duration_strat(spp) for spp in strategic_periods(ts) if spp < sp)
end

function end_time(sp::AbstractStrategicPeriod, ts::TimeStructure)
    return start_time(sp, ts) + duration_strat(sp)
end

function remaining(sp::AbstractStrategicPeriod, ts::TimeStructure)
    return sum(duration_strat(spp) for spp in strategic_periods(ts) if spp >= sp)
end

"""
    struct SingleStrategicPeriodWrapper{T,SP<:TimeStructure{T}} <: AbstractStrategicPeriod{T,T}

A type representing a single strategic period supporting iteration over its
time periods. It is created when iterating through [`SingleStrategicPeriodWrapper`](@ref).
"""
struct SingleStrategicPeriod{T,SP<:TimeStructure{T}} <: AbstractStrategicPeriod{T,T}
    ts::SP
end

_strat_per(sp::SingleStrategicPeriod) = 1

mult_strat(sp::SingleStrategicPeriod) = 1.0
duration_strat(sp::SingleStrategicPeriod) = _total_duration(sp.ts)

# Add basic functions of iterators
Base.length(sp::SingleStrategicPeriod) = length(sp.ts)
Base.eltype(::Type{SingleStrategicPeriod{T,SP}}) where {T,SP} = eltype(SP)
function Base.iterate(sp::SingleStrategicPeriod, state = nothing)
    next = isnothing(state) ? iterate(sp.ts) : iterate(sp.ts, state)
    return next
end
Base.last(sp::SingleStrategicPeriod) = last(sp.ts)

"""
    struct SingleStrategicPeriodWrapper{T,SP<:TimeStructure{T}} <: AbstractStratPers{T}

Type for iterating through the individual strategic periods of a time structure
without [`TwoLevel`](@ref). It is automatically created through the function
[`strat_periods`](@ref).
"""
struct SingleStrategicPeriodWrapper{T,SP<:TimeStructure{T}} <: AbstractStratPers{T}
    ts::SP
end

_oper_struct(sps::SingleStrategicPeriodWrapper) = sps.ts

"""
    strat_periods(ts::TimeStructure)

This function returns a type for iterating through the individual strategic
periods of a `TimeStructure`. The type of the iterator is dependent on the type of the
input `TimeStructure`. The elements returned of the iterator will be subtypes of
[`AbstractStrategicPeriod`](@ref).

When the `TimeStructure` is a `TimeStructure`, `strat_periods` returns a
[`SingleStrategicPeriodWrapper`](@ref). This corresponds to the default behavior.
"""
strat_periods(ts::TimeStructure) = SingleStrategicPeriodWrapper(ts)

"""
    strategic_periods(ts)

Convenience constructor for [`strat_periods`](@ref). Both names can be used interchangable.
"""
strategic_periods(ts) = strat_periods(ts)

Base.length(sps::SingleStrategicPeriodWrapper) = 1
function Base.iterate(sps::SingleStrategicPeriodWrapper, state = nothing)
    !isnothing(state) && return nothing
    return SingleStrategicPeriod(_oper_struct(sps)), 1
end
function Base.eltype(::Type{SingleStrategicPeriodWrapper{T,SP}}) where {T,SP}
    return SingleStrategicPeriod{T,SP}
end
Base.last(sps::SingleStrategicPeriodWrapper) = SingleStrategicPeriod(_oper_struct(sps))

"""
    struct StrategicPeriod{S,T,OP<:TimeStructure{T}} <: AbstractStrategicPeriod{S,T}

A type representing a single strategic period supporting iteration over its
time periods. It is created when iterating through [`StratPers`](@ref).
"""
struct StrategicPeriod{S,T,OP<:TimeStructure{T}} <: AbstractStrategicPeriod{S,T}
    sp::Int
    duration::S
    mult_sp::Float64
    operational::OP
end

_strat_per(sp::StrategicPeriod) = sp.sp

mult_strat(sp::StrategicPeriod) = sp.mult_sp
duration_strat(sp::StrategicPeriod) = sp.duration

Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")
# Provide a constructor to simplify the design
function OperationalPeriod(sp::StrategicPeriod, per::TimePeriod)
    mult = mult_strat(sp) * multiple(per)
    return OperationalPeriod(sp.sp, per, mult)
end

# Add basic functions of iterators
Base.length(sp::StrategicPeriod) = length(sp.operational)
function Base.eltype(_::Type{StrategicPeriod{S,T,OP}}) where {S,T,OP}
    return OperationalPeriod{eltype(OP)}
end
function Base.iterate(sp::StrategicPeriod, state = nothing)
    next = isnothing(state) ? iterate(sp.operational) : iterate(sp.operational, state)
    next === nothing && return nothing

    return OperationalPeriod(sp, next[1]), next[2]
end
function Base.getindex(sp::StrategicPeriod, index::Int)
    per = sp.operational[index]
    return OperationalPeriod(sp, per)
end
function Base.eachindex(sp::StrategicPeriod)
    return eachindex(sp.operational)
end
function Base.last(sp::StrategicPeriod)
    per = last(sp.operational)
    return OperationalPeriod(sp, per)
end

"""
    multiple_strat(sp::StrategicPeriod, t)

Returns the number of times a time period `t` should be accounted for
when accumulating over one single unit of strategic time.

# Example
```julia
periods = TwoLevel(10, 1, SimpleTimes(24,1); op_per_strat = 8760)
for sp in strategic_periods(periods)
    hours_per_year = sum(duration(t) * multiple_strat(sp, t) for t in sp)
end
```
"""
multiple_strat(sp::StrategicPeriod, t) = multiple(t) / duration_strat(sp)

"""
    struct StratPers{S,T,OP} <: AbstractStratPers{T}

Type for iterating through the individual strategic periods of a
[`TwoLevel`](@ref) time structure. It is automatically created through the
function [`strat_periods`](@ref).
"""
struct StratPers{S,T,OP} <: AbstractStratPers{T}
    ts::TwoLevel{S,T,OP}
end

_oper_struct(sps::StratPers) = sps.ts

function remaining(sp::AbstractStrategicPeriod, sps::StratPers)
    return sum(duration_strat(spp) for spp in sps if spp >= sp)
end

"""
When the `TimeStructure` is a [`TwoLevel`](@ref), `strat_periods` returns the
iterator [`StratPers`](@ref).

## Example
```julia
periods = TwoLevel(5, SimpleTimes(10,1))
total_dur = sum(duration_strat(sp) for sp in strategic_periods(periods))
```
"""
strat_periods(ts::TwoLevel) = StratPers(ts)

# Provide a constructor to simplify the design
function StrategicPeriod(sps::StratPers, sp::Int)
    return StrategicPeriod(
        sp,
        _oper_struct(sps).duration[sp],
        _multiple_adj(_oper_struct(sps), sp),
        _oper_struct(sps).operational[sp],
    )
end

# Add basic functions of iterators
Base.length(sps::StratPers) = _oper_struct(sps).len
function Base.eltype(_::StratPers{S,T,OP}) where {S,T,OP<:TimeStructure{T}}
    return StrategicPeriod{S,T,OP}
end
function Base.iterate(sps::StratPers, state = nothing)
    sp = isnothing(state) ? 1 : state + 1
    sp > length(sps) && return nothing

    return StrategicPeriod(sps, sp), sp
end
function Base.getindex(sps::StratPers, index::Int)
    return StrategicPeriod(sps, index)
end
function Base.eachindex(sps::StratPers)
    return eachindex(_oper_struct(sps).operational)
end
function Base.last(sps::StratPers)
    return StrategicPeriod(sps, length(sps))
end
