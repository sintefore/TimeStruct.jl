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
    len::Integer
    duration::Vector{S}
    operational::Vector{<:TimeStructure{T}}
end

function TwoLevel(len, duration::S, oper::TimeStructure{T}) where {S,T}
    return TwoLevel{S,T}(len, fill(duration, len), fill(oper, len))
end
function TwoLevel(
    len,
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
    return OperationalPeriod(
        sp,
        opscen(per),
        per.op,
        per.duration,
        probability(per),
    ),
    (sp, next[2])
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
    return OperationalPeriod(
        sp,
        opscen(per),
        per.op,
        per.duration,
        probability(per),
    ),
    (sp, next[2])
end

function Base.length(itr::TwoLevel)
    return sum(length(itr.operational[sp]) for sp in 1:itr.len)
end
Base.eltype(::Type{TwoLevel{S,T}}) where {S,T} = OperationalPeriod{T}

"""
	struct OperationalPeriod <: TimePeriod{TwoLevel}    
Time period for iteration of a TwoLevel time structure. 
"""
struct OperationalPeriod{T} <: TimePeriod{TwoLevel}
    sp::Int64
    sc::Union{Nothing,Int64}
    op::Int64
    duration::T
    prob::Float64
end
OperationalPeriod(sp, op) = OperationalPeriod(sp, nothing, op, 1, 1.0)
OperationalPeriod(sp, sc, op) = OperationalPeriod(sp, sc, op, 1, 1.0)

function op(scp::ScenarioPeriod, sp)
    return OperationalPeriod(sp, scp.sc, scp.op, scp.duration, scp.prob)
end

isfirst(op::OperationalPeriod) = op.op == 1
duration(op::OperationalPeriod) = op.duration
probability(op::OperationalPeriod) = op.prob
function Base.show(io::IO, op::OperationalPeriod)
    return isnothing(op.sc) ? print(io, "t$(op.sp)_$(op.op)") :
           print(io, "t$(op.sp)-$(op.sc)_$(op.op)")
end
function Base.isless(t1::OperationalPeriod, t2::OperationalPeriod)
    return t1.sp < t2.sp || (t1.sp == t2.sp && t1.op < t2.op)
end

stripunit(val) = val
stripunit(val::Unitful.Quantity) = Unitful.ustrip(Unitful.NoUnits, val)

function multiple(op::OperationalPeriod, ts::TwoLevel)
    if isa(ts.operational[op.sp], OperationalScenarios)
        dur = duration(ts.operational[op.sp].scenarios[op.sc])
    else
        dur = duration(ts.operational[op.sp])
    end
    return stripunit(ts.duration[op.sp] / dur)
end

opscen(::TimePeriod) = nothing
opscen(t::ScenarioPeriod) = t.sc
opscen(t::OperationalPeriod) = t.sc

"""
    struct StrategicPeriod <: TimePeriod{TwoLevel} 
Time period for iteration of strategic periods.
"""
struct StrategicPeriod{T} <: TimePeriod{TwoLevel}
    sp::Int64
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
    return OperationalPeriod(
        itr.sp,
        opscen(per),
        per.op,
        per.duration,
        probability(per),
    ),
    next[2]
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
