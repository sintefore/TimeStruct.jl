"""
    struct OperationalScenarios <: TimeStructure

Time structure that have multiple scenarios where each scenario has its own time structure
and an associated probability. Note that all scenarios must use the same type for the duration.
"""
struct OperationalScenarios{T,OP<:TimeStructure{T}} <: TimeStructure{T}
    len::Int
    scenarios::Vector{OP}
    probability::Vector{Float64}
end
function OperationalScenarios(len::Integer, oper::TimeStructure{T}) where {T}
    return OperationalScenarios(len, fill(oper, len), fill(1.0 / len, len))
end
function OperationalScenarios(
    oper::Vector{<:TimeStructure{T}},
    prob::Vector,
) where {T}
    return OperationalScenarios(length(oper), oper, prob)
end
function OperationalScenarios(oper::Vector{<:TimeStructure{T}}) where {T}
    return OperationalScenarios(
        length(oper),
        oper,
        fill(1.0 / length(oper), length(oper)),
    )
end

function _total_duration(os::OperationalScenarios)
    return maximum(_total_duration(sc) for sc in os.scenarios)
end

function _multiple_adj(os::OperationalScenarios, scen)
    return stripunit(_total_duration(os) / _total_duration(os.scenarios[scen]))
end

# Iteration through all time periods for the operational scenarios
function Base.iterate(itr::OperationalScenarios)
    sc = 1
    next = iterate(itr.scenarios[sc])
    next === nothing && return nothing
    mult = _multiple_adj(itr, sc)
    return ScenarioPeriod(sc, itr.probability[sc], mult, next[1]), (sc, next[2])
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
    mult = _multiple_adj(itr, sc)
    return ScenarioPeriod(sc, itr.probability[sc], mult, next[1]), (sc, next[2])
end

function Base.length(itr::OperationalScenarios)
    return sum(length(itr.scenarios[sc]) for sc in 1:itr.len)
end

Base.eltype(::Type{OperationalScenarios{T}}) where {T} = ScenarioPeriod

# A time period with scenario number and probability
struct ScenarioPeriod{P} <: TimePeriod where {P<:TimePeriod}
    sc::Int
    prob::Float64
    multiple::Float64
    period::P
end

function ScenarioPeriod(scenario::Int, prob::Number, multiple::Number, period)
    return ScenarioPeriod(
        scenario,
        Base.convert(Float64, prob),
        Base.convert(Float64, multiple),
        period,
    )
end

Base.show(io::IO, up::ScenarioPeriod) = print(io, "sc$(up.sc)-$(up.period)")
function Base.isless(t1::ScenarioPeriod, t2::ScenarioPeriod)
    return t1.sc < t2.sc || (t1.sc == t2.sc && t1.period < t2.period)
end

isfirst(t::ScenarioPeriod) = isfirst(t.period)
duration(t::ScenarioPeriod) = duration(t.period)
probability(t::ScenarioPeriod) = t.prob
multiple(t::ScenarioPeriod) = t.multiple

_oper(t::ScenarioPeriod) = _oper(t.period)
_opscen(t::ScenarioPeriod) = t.sc
