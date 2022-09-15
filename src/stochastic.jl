"""
    struct OperationalScenarios <: TimeStructure
Time structure that have multiple scenarios where each scenario has its own time structure
and an associated probability. Note that all scenarios must use the same type for the duration.
"""
struct OperationalScenarios{T} <: TimeStructure{T}
    len::Int
    scenarios::Vector{<:TimeStructure{T}}
    probability::Vector{Float64}
end
function OperationalScenarios(len::Integer, oper::TimeStructure{T}) where {T}
    return OperationalScenarios{T}(len, fill(oper, len), fill(1.0 / len, len))
end
function OperationalScenarios(
    oper::Vector{<:TimeStructure{T}},
    prob::Vector,
) where {T}
    return OperationalScenarios{T}(length(oper), oper, prob)
end
function OperationalScenarios(oper::Vector{<:TimeStructure{T}}) where {T}
    return OperationalScenarios{T}(
        length(oper),
        oper,
        fill(1.0 / length(oper), length(oper)),
    )
end

function duration(os::OperationalScenarios)
    return maximum(duration(sc) for sc in os.scenarios)
end

# Iteration through all time periods for the operational scenarios
function Base.iterate(itr::OperationalScenarios)
    sc = 1
    next = iterate(itr.scenarios[sc])
    next === nothing && return nothing
    return ScenarioPeriod(sc, itr.probability[sc], next[1]), (sc, next[2])
end

function Base.iterate(itr::OperationalScenarios, state)
    sc = state[1]
    next = iterate(itr.scenarios[sc], state[2])
    if next === nothing
        sc = sc + 1
        if sc > itr.len
            return nothing
        end
        next = iterate(itr.scenarios[sc])
    end
    return ScenarioPeriod(sc, itr.probability[sc], next[1]), (sc, next[2])
end
function Base.length(itr::OperationalScenarios)
    return sum(length(itr.scenarios[sc]) for sc in 1:itr.len)
end
Base.eltype(::Type{OperationalScenarios{T}}) where {T} = ScenarioPeriod

# A time period with scenario number and probability
struct ScenarioPeriod{T} <: TimePeriod where {T<:TimePeriod}
    sc::Int
    prob::Float64
    period::T
end

Base.show(io::IO, up::ScenarioPeriod) = print(io, "sc$(up.sc)-$(up.period)")
function Base.isless(t1::ScenarioPeriod, t2::ScenarioPeriod)
    return t1.sc < t2.sc || (t1.sc == t2.sc && t1.period < t2.period)
end

isfirst(t::ScenarioPeriod) = isfirst(t.period)
duration(t::ScenarioPeriod) = duration(t.period)
probability(t::ScenarioPeriod) = t.prob

_oper(t::ScenarioPeriod) = _oper(t.period)
_opscen(t::ScenarioPeriod) = t.sc

"""
    struct OperationalScenario 
A structure representing a single operational scenario supporting
iteration over its time periods.
"""
struct OperationalScenario{T} <: TimeStructure{T}
    scen::Int
    probability::Float64
    operational::TimeStructure{T}
end
Base.show(io::IO, os::OperationalScenario) = print(io, "sc-$(os.scen)")
probability(os::OperationalScenario) = os.probability
duration(os::OperationalScenario) = duration(os.operational)

# Iterate the time periods of an operational scenario
function Base.iterate(os::OperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(os.operational) :
        iterate(os.operational, state)
    next === nothing && return nothing
    return ScenarioPeriod(os.scen, os.probability, next[1]), next[2]
end

Base.length(os::OperationalScenario) = length(os.operational)
Base.eltype(::Type{OperationalScenario}) = ScenarioPeriod

# Iteration through scenarios 
struct OpScens{T}
    ts::OperationalScenarios{T}
end

"""
    opscenarios(ts)
Iterator that iterates over operational scenarios in an `OperationalScenarios` time structure.
"""
opscenarios(ts) = OpScens(ts)

Base.length(ops::OpScens) = ops.ts.len

function Base.iterate(ops::OpScens)
    return OperationalScenario(1, ops.ts.probability[1], ops.ts.scenarios[1]), 1
end

function Base.iterate(ops::OpScens, state)
    state == ops.ts.len && return nothing
    return OperationalScenario(
        state + 1,
        ops.ts.probability[state+1],
        ops.ts.scenarios[state+1],
    ),
    state + 1
end

# Allow SimpleTimes to behave as one operational scenario
opscenarios(ts::SimpleTimes) = [ts]
probability(ts::SimpleTimes) = 1.0
