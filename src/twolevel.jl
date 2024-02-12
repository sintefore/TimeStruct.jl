"""
    struct TwoLevel <: TimeStructure

A time structure with two levels of time periods.

On the top level it has a sequence of strategic periods of varying duration.
For each strategic period a separate time structure is used for
operational decisions. Iterating the structure will go through all operational periods.
It is possible to use different time units for the two levels by providing the number
of operational time units per strategic time unit.

Example
```julia
periods = TwoLevel(5, 8760, SimpleTimes(24, 1)) # 5 years with 24 hours of operations for each year
```
"""
struct TwoLevel{S<:Duration,T,OP<:TimeStructure{T}} <: TimeStructure{T}
    len::Int
    duration::Vector{S}
    operational::Vector{OP}
    op_per_strat::Float64
end

function TwoLevel(
    len::Integer,
    duration::S,
    oper::TimeStructure{T};
    op_per_strat = 1.0,
) where {S,T}
    return TwoLevel(
        len,
        fill(duration, len),
        fill(oper, len),
        convert(Float64, op_per_strat),
    )
end

function TwoLevel(
    duration::S,
    oper::Vector{OP};
    op_per_strat = 1.0,
) where {S,T,OP<:TimeStructure{T}}
    len = length(oper)
    return TwoLevel{S,T,OP}(len, fill(duration, len), oper, op_per_strat)
end

function TwoLevel(
    oper::Vector{<:TimeStructure{T}};
    op_per_strat = 1.0,
) where {T}
    len = length(oper)
    dur = [_total_duration(op) / op_per_strat for op in oper]
    return TwoLevel(len, dur, oper, op_per_strat)
end

function TwoLevel(
    duration::Vector{S},
    oper::TimeStructure{T};
    op_per_strat = 1.0,
) where {S,T}
    return TwoLevel(
        length(duration),
        duration,
        fill(oper, length(duration)),
        convert(Float64, op_per_strat),
    )
end

function TwoLevel(
    duration::Vector{<:Number},
    u::Unitful.Units,
    oper::TimeStructure{<:Unitful.Quantity{V,Unitful.𝐓}},
) where {V}
    return TwoLevel(Unitful.Quantity.(duration, u), oper; op_per_strat = 1.0)
end

"""
    TwoLevel(len, duration::Real, oper::RepresentativePeriods)

Creates a TwoLevel time structure of given length using the same duration
and representative periods for each strategic period. The `op_per_strat` parameter
is set equal to the duration of the RepresentativePeriods structure to ensure consistency.

# Example
```julia
# 3 strategic periods of length 5 years, where each year of 365 day is represented by two weeks
periods = TwoLevel(3, 5, RepresentativePeriods(2, 365, [0.5, 0.5], [SimpleTimes(7,1), SimpleTimes(7,1)]))
```
"""
function TwoLevel(len::Integer, duration::Real, oper::RepresentativePeriods)
    return TwoLevel(
        len,
        fill(duration, len),
        fill(oper, len),
        convert(Float64, TimeStruct._total_duration(oper)),
    )
end


_total_duration(itr::TwoLevel) = sum(itr.duration)

function _multiple_adj(itr::TwoLevel, sp)
    mult = itr.duration[sp] * itr.op_per_strat / _total_duration(itr.operational[sp])
    return stripunit(mult)
end

function Base.iterate(itr::TwoLevel)
    sp = 1
    next = iterate(itr.operational[sp])
    next === nothing && return nothing
    per = next[1]

    mult = _multiple_adj(itr, sp) * multiple(per)
    return OperationalPeriod(sp, per, mult), (sp, next[2])
end

function Base.iterate(itr::TwoLevel, state)
    sp = state[1]
    next = iterate(itr.operational[sp], state[2])
    if next === nothing
        sp = sp + 1
        if sp > itr.len
            return nothing
        end
        next = iterate(itr.operational[sp])
    end
    per = next[1]

    mult = _multiple_adj(itr, sp) * multiple(per)
    return OperationalPeriod(sp, per, mult), (sp, next[2])
end

function Base.length(itr::TwoLevel)
    return sum(length(op) for op in itr.operational)
end

Base.eltype(::Type{TwoLevel{S,T,OP}}) where {S,T,OP} = OperationalPeriod

"""
	struct OperationalPeriod <: TimePeriod
Time period for iteration of a TwoLevel time structure.
"""
struct OperationalPeriod <: TimePeriod
    sp::Int
    period::TimePeriod
    multiple::Float64
end

isfirst(t::OperationalPeriod) = isfirst(t.period)
duration(t::OperationalPeriod) = duration(t.period)
probability(t::OperationalPeriod) = probability(t.period)
multiple(t::OperationalPeriod) = t.multiple

multiple(ts::TwoLevel, sp::StrategicPeriod) = _multiple_adj(ts, sp.sp)
multiple(srp::StratReprPeriod, t::OperationalPeriod) = t.multiple / srp.mult_sp

_oper(t::OperationalPeriod) = _oper(t.period)
_strat_per(t::OperationalPeriod) = t.sp
_opscen(t::OperationalPeriod) = _opscen(t.period)
_rper(t::OperationalPeriod) = _rper(t.period)

function Base.show(io::IO, t::OperationalPeriod)
    return print(io, "sp$(t.sp)-$(t.period)")
end
function Base.isless(t1::OperationalPeriod, t2::OperationalPeriod)
    return t1.sp < t2.sp || (t1.sp == t2.sp && t1.period < t2.period)
end


"""
    StrategicPeriod <: TimePeriod

Time period for iteration of strategic periods.
"""
struct StrategicPeriod{S,T,OP<:TimeStructure{T}} <: TimePeriod
    sp::Int
    duration::S
    mult_sp::Float64
    operational::OP
end

isfirst(sp::StrategicPeriod) = sp.sp == 1
Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")
Base.isless(sp1::StrategicPeriod, sp2::StrategicPeriod) = sp1.sp < sp2.sp

duration(sp::StrategicPeriod) = sp.duration
_strat_per(sp::StrategicPeriod) = sp.sp

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
multiple_strat(sp::StrategicPeriod, t) = multiple(t) / duration(sp)

struct StratPeriods{S,T,OP}
    ts::TwoLevel{S,T,OP}
end

"""
    strat_periods(ts::TwoLevel)

Iteration through the strategic periods of a 'TwoLevel' structure.
"""
strat_periods(ts::TwoLevel) = StratPeriods(ts)
Base.length(sps::StratPeriods) = sps.ts.len

function Base.iterate(sps::StratPeriods)
    mult_sp = _multiple_adj(sps.ts, 1)
    return StrategicPeriod(
        1,
        sps.ts.duration[1],
        mult_sp,
        sps.ts.operational[1],
    ),
    1
end

function Base.iterate(sps::StratPeriods, state)
    state == sps.ts.len && return nothing
    mult_sp = _multiple_adj(sps.ts, state + 1)
    sp = StrategicPeriod(
        state + 1,
        sps.ts.duration[state+1],
        mult_sp,
        sps.ts.operational[state+1],

    )
    return sp, state + 1
end

Base.length(itr::StrategicPeriod) = length(itr.operational)
function Base.eltype(::Type{StrategicPeriod{S,T,OP}}) where {S,T,OP}
    return OperationalPeriod
end

# Function for defining the time periods when iterating through a strategic period
function Base.iterate(itr::StrategicPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]

    mult = itr.mult_sp * multiple(per)
    return OperationalPeriod(itr.sp, per, mult), next[2]
end

function start_time(sp::StrategicPeriod, ts::TwoLevel{S}) where {S}
    return isfirst(sp) ? zero(S) :
           sum(duration(spp) for spp in strategic_periods(ts) if spp < sp)
end

end_time(sp::StrategicPeriod, ts::TwoLevel) = start_time(sp, ts) + duration(sp)

function remaining(sp::StrategicPeriod, ts::TwoLevel)
    return sum(duration(spp) for spp in strategic_periods(ts) if spp >= sp)
end

# Default behaviour if no strategic periods are involved
strat_periods(ts) = SingleTimeStructWrapper(ts)

# Allow both strategic_periods and strat_periods as function name
strategic_periods(ts) = strat_periods(ts)

"""
    struct StratOperationalScenario

A structure representing a single operational scenario for a strategic period supporting
iteration over its time periods.
"""
struct StratOperationalScenario{T} <: TimeStructure{T}
    sp::Int
    scen::Int
    mult_sp::Float64
    probability::Float64
    operational::TimeStructure{T}
end

function Base.show(io::IO, os::StratOperationalScenario)
    return print(io, "sp$(os.sp)-sc$(os.scen)")
end
#probability(os::StratOperationalScenario) = os.probability
#_strat_per(os::StratOperationalScenario) = os.sp
#_opscen(os::StratOperationalScenario) = os.scen

# Iterate the time periods of a StratOperationalScenario
function Base.iterate(os::StratOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    return OperationalPeriod(os.sp, next[1], os.mult_sp * multiple(next[1])), next[2]
end

Base.length(os::StratOperationalScenario) = length(os.operational)
function Base.eltype(::Type{StratOperationalScenario{T}}) where {T}
    return OperationalPeriod
end

# Iteration through scenarios
struct StratOpScens
    sp::Int
    mult_sp::Float64
    opscens
end

function StratOpScens(sper::StrategicPeriod, opscens)
    return StratOpScens(sper.sp, sper.mult_sp, opscens)
end

"""
    opscenarios(sp::StrategicPeriod)

    Iterator that iterates over operational scenarios for a specific strategic period.
"""
function opscenarios(sper::StrategicPeriod{S,T,OP}) where {S,T,OP}
    return StratOpScens(sper, opscenarios(sper.operational))
end

function opscenarios(sp::StrategicPeriod{S1,T,RepresentativePeriods{S2,T,OP}}) where {S1,S2,T,OP}
    opscens = StratReprOpscenPeriod[]
    for rp in repr_periods(sp)
        push!(opscens, opscenarios(rp)...)
    end
    return opscens
end

"""
    opscenarios(ts::TwoLevel)

    Returns a collection of all operational scenarios for a TwoLevel time structure.
"""
function opscenarios(ts::TwoLevel{S,T,OP}) where {S,T,OP}
    opscens = StratOperationalScenario[]
    for sp in strategic_periods(ts)
        push!(opscens, opscenarios(sp)...)
    end
    return opscens
end

function opscenarios(
    ts::TwoLevel{S1,T,RepresentativePeriods{S2,T,OP}},
) where {S1,S2,T,OP}
    opscens = StratReprOpscenPeriod[]
    for sp in strategic_periods(ts)
        for rp in repr_periods(sp)
            push!(opscens, opscenarios(rp)...)
        end
    end
    return opscens
end

Base.length(ops::StratOpScens) = length(ops.opscens)

function Base.iterate(ops::StratOpScens, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(ops.opscens) :
        iterate(ops.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratOperationalScenario(
        ops.sp,
        scen,
        ops.mult_sp,
        probability(next[1]),
        next[1],
    ),
    (next[2], scen + 1)
end

struct StratReprPeriod{T, OP<:TimeStructure{T}} <: TimeStructure{T}
    sp::Int
    rp::Int
    mult_sp::Float64
    mult_rp::Float64
    operational::OP
end

isfirst(srp::StratReprPeriod) = srp.rp == 1

function Base.show(io::IO, srp::StratReprPeriod)
    return print(io, "sp$(srp.sp)-rp$(srp.rp)")
end
_strat_per(srp::StratReprPeriod) = srp.sp
_rper(srp::StratReprPeriod) = srp.rp


# Iterate the time periods of a StratReprPeriod
function Base.iterate(srp::StratReprPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(srp.operational) :
        iterate(srp.operational, state)
    isnothing(next) && return nothing

    per = next[1]
    mult = srp.mult_sp * multiple(per)
    return OperationalPeriod(srp.sp, per, mult), next[2]
end

Base.length(srp::StratReprPeriod) = length(srp.operational)
function Base.eltype(::Type{StratReprPeriod{T}}) where {T}
    return OperationalPeriod
end

# Iteration through representative periods
struct StratReprPeriods
    sper::StrategicPeriod
    repr
end

"""
    repr_periods(sper)

    Iterator that iterates over representative periods for a specific strategic period.
"""
function repr_periods(sper::StrategicPeriod)
    return StratReprPeriods(sper, repr_periods(sper.operational))
end

"""
    repr_periods(ts)

    Returns a collection of all representative periods for a TwoLevel time structure.
"""
function repr_periods(ts::TwoLevel)
    rps = StratReprPeriod[]
    for sp in strategic_periods(ts)
        push!(rps, repr_periods(sp)...)
    end
    return rps
end

Base.length(reps::StratReprPeriods) = length(reps.repr)


_multiple_rp(rpers, rper) = 1.0
_multiple_rp(rpers::ReprPeriods, rper) = _multiple_adj(rpers.ts, rper)

function Base.iterate(reps::StratReprPeriods, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(reps.repr) :
        iterate(reps.repr, state[1])
    isnothing(next) && return nothing

    rper = state[2]
    mult_sp = reps.sper.mult_sp
    mult_rp = _multiple_rp(reps.repr, rper)
    return StratReprPeriod(
        reps.sper.sp,
        rper,
        mult_sp,
        mult_rp,
        next[1],
    ),
    (next[2], rper + 1)
end

struct StratReprOpscenPeriod{T} <: TimeStructure{T}
    sp::Int
    rp::Int
    opscen::Int
    mult_sp::Float64
    mult_rp::Float64
    operational::TimeStructure{T}
end

function Base.show(io::IO, srop::StratReprOpscenPeriod)
    return print(io, "sp$(srop.sp)-rp$(srop.rp)-sc$(srop.opscen)")
end

# Iterate the time periods of a StratReprOpscenPeriod
function Base.iterate(os::StratReprOpscenPeriod, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    period = ReprPeriod(os.rp, next[1], os.mult_rp * multiple(next[1]))
    return OperationalPeriod(os.sp, period, os.mult_sp * os.mult_rp * multiple(next[1])), next[2]
end

Base.length(os::StratReprOpscenPeriod) = length(os.operational)
function Base.eltype(::Type{StratReprOpscenPeriod{T}}) where {T}
    return OperationalPeriod
end

struct StratReprOpscenPeriods
    srp::StratReprPeriod
    opscens
end

function opscenarios(srp::StratReprPeriod{T, RepresentativePeriod{T,OP}}) where {T,OP}
    return StratReprOpscenPeriods(srp, opscenarios(srp.operational.operational))
end

function opscenarios(srp::StratReprPeriod)
    return StratOpScens(srp.sp, srp.mult_sp, opscenarios(srp.operational))
end

Base.length(srop::StratReprOpscenPeriods) = length(srop.opscens)

function Base.iterate(srop::StratReprOpscenPeriods, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(srop.opscens) :
        iterate(srop.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]
    return StratReprOpscenPeriod(
        srop.srp.sp,
        srop.srp.rp,
        scen,
        srop.srp.mult_sp,
        srop.srp.mult_rp,
        next[1],
    ),
    (next[2], scen + 1)
end
