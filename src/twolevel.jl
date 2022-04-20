"""
    struct TwoLevel <: TimeStructure
A time structure with two levels of time periods. 

On the top level it has a sequence of strategic periods of varying duration. 
For each strategic period a separate time structure is used for 
operational decisions. Iterating the structure will go through all operational periods.

Example
```julia
periods = TwoLevel(5, 1u"yr", SimpleTimes(24,1u"hr")) # 5 years with 24 hours of operations for each year
```
"""
struct TwoLevel{S<:Duration,T} <: TimeStructure{T}
    len::Int
    duration::Vector{S}
    operational::Vector{<:TimeStructure{T}}
end

function TwoLevel(len::Integer, duration::S, oper::TimeStructure{T}) where {S,T}
    return TwoLevel{S,T}(len, fill(duration, len), fill(oper, len))
end
function TwoLevel(
    len::Integer,
    duration::S,
    oper::Vector{<:TimeStructure{T}},
) where {S,T}
    return TwoLevel{S,T}(len, fill(duration, len), oper)
end
function TwoLevel(duration::Vector{S}, oper::TimeStructure{T}) where {S,T}
    return TwoLevel{S,T}(
        length(duration),
        duration,
        fill(oper, length(duration)),
    )
end
function TwoLevel(
    duration::Vector{<:Number},
    u::Unitful.Units,
    oper::TimeStructure{T},
) where {T}
    return TwoLevel(Unitful.Quantity.(duration, u), oper)
end

function Base.iterate(itr::TwoLevel)
    sp = 1
    next = iterate(itr.operational[sp])
    next === nothing && return nothing
    per = next[1]
    return OperationalPeriod(sp, per), (sp, next[2])
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
    return OperationalPeriod(sp, per), (sp, next[2])
end

function Base.length(itr::TwoLevel)
    return sum(length(itr.operational[sp]) for sp in 1:itr.len)
end
Base.eltype(::Type{TwoLevel{S,T}}) where {S,T} = OperationalPeriod

"""
	struct OperationalPeriod <: TimePeriod{TwoLevel}    
Time period for iteration of a TwoLevel time structure. 
"""
struct OperationalPeriod{T} <: TimePeriod{TwoLevel} where {T<:TimePeriod}
    sp::Int
    period::T
end
#=
function OperationalPeriod(sp::Integer, op::Integer)
    return OperationalPeriod(sp, nothing, op, 1, 1.0)
end
function OperationalPeriod(sp::Integer, sc::Integer, op::Integer)
    return OperationalPeriod(sp, sc, op, 1, 1.0)
end

function op(scp::ScenarioPeriod, sp::Integer)
    return OperationalPeriod(sp, scp.sc, scp.op, scp.duration, scp.prob)
end
=#
oper(op::OperationalPeriod) = oper(op.period)
isfirst(op::OperationalPeriod) = isfirst(op.period)
duration(op::OperationalPeriod) = duration(op.period)
probability(op::OperationalPeriod) = probability(op.period)

function Base.show(io::IO, op::OperationalPeriod)
    return print(io, "sp$(op.sp)-$(op.period)")
end
function Base.isless(t1::OperationalPeriod, t2::OperationalPeriod)
    return t1.sp < t2.sp || (t1.sp == t2.sp && t1.period < t2.period)
end

stripunit(val) = val
stripunit(val::Unitful.Quantity) = Unitful.ustrip(Unitful.NoUnits, val)

function multiple(op::OperationalPeriod, ts::TwoLevel)
    if isa(ts.operational[op.sp], OperationalScenarios)
        dur = duration(ts.operational[op.sp].scenarios[opscen(op)])
    else
        dur = duration(ts.operational[op.sp])
    end
    return stripunit(ts.duration[op.sp] / dur)
end

opscen(::TimePeriod) = nothing
opscen(t::ScenarioPeriod) = t.sc
opscen(t::OperationalPeriod) = opscen(t.period)

"""
    struct StrategicPeriod <: TimePeriod{TwoLevel} 
Time period for iteration of strategic periods.
"""
struct StrategicPeriod{T} <: TimePeriod{TwoLevel}
    sp::Int
    duration::Any
    operational::TimeStructure
end

isfirst(sp::StrategicPeriod) = sp.sp == 1
Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")
Base.isless(sp1::StrategicPeriod, sp2::StrategicPeriod) = sp1.sp < sp2.sp

duration(sp::StrategicPeriod) = sp.duration

strat_per(::TimePeriod) = nothing
strat_per(sp::StrategicPeriod) = sp.sp
strat_per(op::OperationalPeriod) = op.sp

struct StratPeriods
    ts::TwoLevel
end

"""
    strat_periods(ts::TwoLevel)
Iteration through the strategic periods of a 'TwoLevel' structure.
"""
strat_periods(ts::TwoLevel) = StratPeriods(ts)
Base.length(sps::StratPeriods) = sps.ts.len

function Base.iterate(sps::StratPeriods)
    return StrategicPeriod{TwoLevel}(
        1,
        sps.ts.duration[1],
        sps.ts.operational[1],
    ),
    1
end

function Base.iterate(sps::StratPeriods, state)
    state == sps.ts.len && return nothing
    return StrategicPeriod{TwoLevel}(
        state + 1,
        sps.ts.duration[state+1],
        sps.ts.operational[state+1],
    ),
    state + 1
end

Base.length(itr::StrategicPeriod{T}) where {T} = itr.operational.len
Base.eltype(::Type{StrategicPeriod{TwoLevel}}) = OperationalPeriod

# Function for defining the time periods when iterating through a strategic period
function Base.iterate(itr::StrategicPeriod{TwoLevel}, state = nothing)
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]
    return OperationalPeriod(itr.sp, per), next[2]
end

# Let SimpleTimes and OperationalScenarios behave as a TwoLevel time structure with one strategic period
function strat_periods(ts::Union{SimpleTimes,OperationalScenarios})
    return [StrategicPeriod{SimpleTimes}(1, duration(ts), ts)]
end
strat_per(t::Union{SimplePeriod,ScenarioPeriod}) = 1

Base.eltype(::Type{StrategicPeriod{SimpleTimes}}) = SimplePeriod
function Base.iterate(itr::StrategicPeriod{SimpleTimes}, state = nothing)
    next =
        isnothing(state) ? iterate(itr.operational) :
        iterate(itr.operational, state)
    next === nothing && return nothing
    per = next[1]
    return per, next[2]
end

"""
    struct StratOperationalScenario 
A structure representing a single operational scenario for a strategic period supporting
iteration over its time periods.
"""
struct StratOperationalScenario{T}
    sp::Int
    scen::Int
    probability::Float64
    operational::TimeStructure{T}
end
function Base.show(io::IO, os::StratOperationalScenario)
    return print(io, "sp-$(os.sp)-sc-$(os.scen)")
end
probability(os::StratOperationalScenario) = os.probability

# Iterate the time periods of an stratoperational scenario
function Base.iterate(os::StratOperationalScenario)
    next = iterate(os.operational)
    next === nothing && return nothing
    return OperationalPeriod(
        os.sp,
        ScenarioPeriod(os.scen, os.probability, next[1]),
    ),
    (1, next[2])
end

function Base.iterate(os::StratOperationalScenario, state)
    next = iterate(os.operational, state[2])
    next === nothing && return nothing
    return OperationalPeriod(
        os.sp,
        ScenarioPeriod(os.scen, os.probability, next[1]),
    ),
    (1, next[2])
end
Base.length(os::StratOperationalScenario) = length(os.operational)
Base.eltype(::Type{StratOperationalScenario}) = OperationalPeriod

# Iteration through scenarios 
struct StratOpScens{T}
    sper::StrategicPeriod
    ts::OperationalScenarios{T}
end
"""
    opscenarios(sp,ts)
Iterator that iterates over operational scenarios for a specific strategic period.
"""
function opscenarios(sper::StrategicPeriod, ts::TwoLevel)
    return StratOpScens(sper, ts.operational[sper.sp])
end

Base.length(ops::StratOpScens) = ops.ts.len

function Base.iterate(ops::StratOpScens)
    return StratOperationalScenario(
        ops.sper.sp,
        1,
        ops.ts.probability[1],
        ops.ts.scenarios[1],
    ),
    1
end

function Base.iterate(ops::StratOpScens, state)
    state == ops.ts.len && return nothing
    return StratOperationalScenario(
        ops.sper.sp,
        state + 1,
        ops.ts.probability[state+1],
        ops.ts.scenarios[state+1],
    ),
    state + 1
end
