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
periods = TwoLevel(5, 1u"yr", SimpleTimes(24,1u"hr")) # 5 years with 24 hours of operations for each year
```
"""
struct TwoLevel{S<:Duration,T} <: TimeStructure{T}
    len::Int
    duration::Vector{S}
    operational::Vector{<:TimeStructure{T}}
    op_per_strat::Float64
end

function TwoLevel(
    len::Integer,
    duration::S,
    oper::TimeStructure{T};
    op_per_strat = 1,
) where {S,T}
    return TwoLevel{S,T}(
        len,
        fill(duration, len),
        fill(oper, len),
        op_per_strat,
    )
end

function TwoLevel(
    len::Integer,
    duration::S,
    oper::Vector{<:TimeStructure{T}};
    op_per_strat = 1,
) where {S,T}
    return TwoLevel{S,T}(len, fill(duration, len), oper, op_per_strat)
end

function TwoLevel(
    duration::Vector{S},
    oper::TimeStructure{T};
    op_per_strat = 1,
) where {S,T}
    return TwoLevel{S,T}(
        length(duration),
        duration,
        fill(oper, length(duration)),
        op_per_strat,
    )
end

function TwoLevel(
    duration::Vector{<:Number},
    u::Unitful.Units,
    oper::TimeStructure{<:Unitful.Quantity{V,Unitful.𝐓}},
) where {V}
    return TwoLevel(Unitful.Quantity.(duration, u), oper; op_per_strat = 1.0)
end

function Base.iterate(itr::TwoLevel)
    sp = 1
    next = iterate(itr.operational[sp])
    next === nothing && return nothing
    per = next[1]
    return OperationalPeriod(sp, per, _multiple(per, sp, itr)), (sp, next[2])
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
    return OperationalPeriod(sp, per, _multiple(per, sp, itr)), (sp, next[2])
end

function Base.length(itr::TwoLevel)
    return sum(length(op) for op in itr.operational)
end

Base.eltype(::Type{TwoLevel{S,T}}) where {S,T} = OperationalPeriod

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

_oper(t::OperationalPeriod) = _oper(t.period)
_strat_per(t::OperationalPeriod) = t.sp
_opscen(t::OperationalPeriod) = _opscen(t.period)

function Base.show(io::IO, t::OperationalPeriod)
    return print(io, "sp$(t.sp)-$(t.period)")
end
function Base.isless(t1::OperationalPeriod, t2::OperationalPeriod)
    return t1.sp < t2.sp || (t1.sp == t2.sp && t1.period < t2.period)
end

stripunit(val) = val
stripunit(val::Unitful.Quantity) = Unitful.ustrip(Unitful.NoUnits, val)

# Returns the number of times a time period should be counted when aggregating
function _multiple(op::SimplePeriod, sp, ts::TwoLevel)
    mult = ts.duration[sp] * ts.op_per_strat / duration(ts.operational[sp])
    return stripunit(mult)
end

function _multiple(op::ScenarioPeriod, sp, ts::TwoLevel)
    mult =
        ts.duration[sp] * ts.op_per_strat /
        duration(ts.operational[sp].scenarios[_opscen(op)])
    return stripunit(mult)
end

"""
    struct StrategicPeriod <: TimePeriod
Time period for iteration of strategic periods.
"""
struct StrategicPeriod{S,T} <: TimePeriod
    sp::Int
    duration::S
    operational::TimeStructure{T}
    op_per_strat::Float64
end

isfirst(sp::StrategicPeriod) = sp.sp == 1
Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")
Base.isless(sp1::StrategicPeriod, sp2::StrategicPeriod) = sp1.sp < sp2.sp

duration(sp::StrategicPeriod) = sp.duration
_strat_per(sp::StrategicPeriod) = sp.sp

struct StratPeriods{S,T}
    ts::TwoLevel{S,T}
end

"""
    strat_periods(ts::TwoLevel)
Iteration through the strategic periods of a 'TwoLevel' structure.
"""
strat_periods(ts::TwoLevel) = StratPeriods(ts)
Base.length(sps::StratPeriods) = sps.ts.len

function Base.iterate(sps::StratPeriods{S,T}) where {S,T}
    return StrategicPeriod{S,T}(
        1,
        sps.ts.duration[1],
        sps.ts.operational[1],
        sps.ts.op_per_strat,
    ),
    1
end

function Base.iterate(sps::StratPeriods{S,T}, state) where {S,T}
    state == sps.ts.len && return nothing
    sp = StrategicPeriod{S,T}(
        state + 1,
        sps.ts.duration[state+1],
        sps.ts.operational[state+1],
        sps.ts.op_per_strat,
    )
    return sp, state + 1
end

Base.length(itr::StrategicPeriod) = itr.operational.len
function Base.eltype(::Type{StrategicPeriod{S,T}}) where {S,T}
    return OperationalPeriod
end

function _multiple(per::SimplePeriod, ts::SimpleTimes, sp::StrategicPeriod)
    mult = sp.duration * sp.op_per_strat / duration(ts)
    return stripunit(mult)
end

function _multiple(
    per::ScenarioPeriod,
    ts::OperationalScenarios,
    sp::StrategicPeriod,
)
    mult = sp.duration * sp.op_per_strat / duration(ts.scenarios[_opscen(per)])
    return stripunit(mult)
end

# Function for defining the time periods when iterating through a strategic period
function Base.iterate(itr::StrategicPeriod{S,T}, state = nothing) where {S,T}
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]
    return OperationalPeriod(itr.sp, per, _multiple(per, itr.operational, itr)),
    next[2]
end

function start_time(sp::StrategicPeriod{S,T}, ts::TwoLevel) where {S,T}
    return isfirst(sp) ? zero(S) :
           sum(duration(spp) for spp in strategic_periods(ts) if spp < sp)
end

end_time(sp::StrategicPeriod, ts::TwoLevel) = start_time(sp, ts) + duration(sp)

function remaining(sp::StrategicPeriod, ts::TwoLevel)
    return sum(duration(spp) for spp in strategic_periods(ts) if spp >= sp)
end

# Let SimpleTimes and OperationalScenarios behave as a TwoLevel time structure with one strategic period
strat_periods(ts::SimpleTimes) = [ts]
strat_periods(ts::OperationalScenarios) = [ts]

# Allow both strategic_periods and strat_periods as function name
strategic_periods(ts) = strat_periods(ts)

"""
    struct StratOperationalScenario 

A structure representing a single operational scenario for a strategic period supporting
iteration over its time periods.
"""
struct StratOperationalScenario{S,T} <: TimeStructure{T}
    sp::Int
    scen::Int
    duration::S
    probability::Float64
    operational::TimeStructure{T}
    op_per_strat::Float64
end

function Base.show(io::IO, os::StratOperationalScenario)
    return print(io, "sp$(os.sp)-sc$(os.scen)")
end
probability(os::StratOperationalScenario) = os.probability
_strat_per(os::StratOperationalScenario) = os.sp
_opscen(os::StratOperationalScenario) = os.scen

# Iterate the time periods of a StratOperationalScenario
function Base.iterate(os::StratOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    isnothing(next) && return nothing

    mult = stripunit(os.duration * os.op_per_strat / duration(os.operational))
    return OperationalPeriod(os.sp, next[1], mult), next[2]
end

Base.length(os::StratOperationalScenario) = length(os.operational)
function Base.eltype(::Type{StratOperationalScenario{S,T}}) where {S,T}
    return OperationalPeriod
end

# Iteration through scenarios 
struct StratOpScens
    sper::StrategicPeriod
    opscens::Any
end

"""
    opscenarios(sp)

    Iterator that iterates over operational scenarios for a specific strategic period.
"""
function opscenarios(sper::StrategicPeriod)
    return StratOpScens(sper, opscenarios(sper.operational))
end

Base.length(ops::StratOpScens) = length(ops.opscens)

function Base.iterate(ops::StratOpScens, state = (nothing, 1))
    next =
        isnothing(state[1]) ? iterate(ops.opscens) :
        iterate(ops.opscens, state[1])
    isnothing(next) && return nothing

    scen = state[2]

    return StratOperationalScenario(
        ops.sper.sp,
        scen,
        ops.sper.duration,
        probability(next[1]),
        next[1],
        ops.sper.op_per_strat,
    ),
    (next[2], scen + 1)
end
