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

function duration(os::OperationalScenarios)
    return maximum(duration(sc) for sc in os.scenarios)
end

# Iteration through all time periods for the operational scenarios
function Base.iterate(itr::OperationalScenarios)
    sc = 1
    next = iterate(itr.scenarios[sc])
    next === nothing && return nothing
    mult = duration(itr) / duration(itr.scenarios[sc])
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
    mult = duration(itr) / duration(itr.scenarios[sc])
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

"""
    struct OperationalScenario
A structure representing a single operational scenario supporting
iteration over its time periods.
"""
struct OperationalScenario{T,OP<:TimeStructure{T}} <: TimeStructure{T}
    scen::Int
    probability::Float64
    multiple::Float64
    operational::OP
end
Base.show(io::IO, os::OperationalScenario) = print(io, "sc-$(os.scen)")
probability(os::OperationalScenario) = os.probability
duration(os::OperationalScenario) = duration(os.operational)

# Iterate the time periods of an operational scenario
function Base.iterate(os::OperationalScenario, state = ())
    next = iterate(os.operational, state...)
    next === nothing && return nothing
    return ScenarioPeriod(os.scen, os.probability, os.multiple, next[1]),
    next[2]
end

Base.length(os::OperationalScenario) = length(os.operational)
Base.eltype(::Type{OperationalScenario}) = ScenarioPeriod

function Base.getindex(os::OperationalScenario, index)
    return ScenarioPeriod(
        os.scen,
        os.probability,
        os.multiple,
        os.operational[index],
    )
end

function Base.eachindex(os::OperationalScenario)
    return eachindex(os.operational)
end

# Iteration through scenarios
struct OpScens{T}
    ts::OperationalScenarios{T}
end

"""
    opscenarios(ts)
Iterator that iterates over operational scenarios in an `OperationalScenarios` time structure.
"""
opscenarios(ts::OperationalScenarios) = OpScens(ts)

Base.length(ops::OpScens) = ops.ts.len

function Base.iterate(ops::OpScens)
    mult = duration(ops.ts) / duration(ops.ts.scenarios[1])
    return OperationalScenario(
        1,
        ops.ts.probability[1],
        mult,
        ops.ts.scenarios[1],
    ),
    1
end

function Base.iterate(ops::OpScens, state)
    state == ops.ts.len && return nothing
    mult = duration(ops.ts) / duration(ops.ts.scenarios[state+1])
    return OperationalScenario(
        state + 1,
        ops.ts.probability[state+1],
        mult,
        ops.ts.scenarios[state+1],
    ),
    state + 1
end

# Allow SimpleTimes to behave as one operational scenario
opscenarios(ts::SimpleTimes) = [ts]
probability(ts::SimpleTimes) = 1.0

struct ReprOperationalScenario{T,OP<:TimeStructure{T}} <: TimeStructure{T}
    rper::Int64
    scen::Int64
    probability::Float64
    multiple_repr::Float64
    multiple_scen::Float64
    operational::OP
end

function Base.show(io::IO, ros::ReprOperationalScenario)
    return print(io, "rp$(ros.rp)-sc$(ros.scen)")
end

# Iterate the time periods of an operational scenario
function Base.iterate(ros::ReprOperationalScenario, state = nothing)
    next =
        isnothing(state) ? iterate(ros.operational) :
        iterate(ros.operational, state)
    next === nothing && return nothing
    period = next[1]
    return ReprPeriod(
        ros.rper,
        ScenarioPeriod(
            ros.scen,
            ros.probability,
            ros.multiple_scen * multiple(period),
            period,
        ),
        ros.multiple_repr * ros.multiple_scen * multiple(period),
    ),
    next[2]
end

function Base.getindex(ros::ReprOperationalScenario, index)
    period = ros.operational[index]
    scen_per = ScenarioPeriod(
        ros.scen,
        ros.probability,
        ros.multiple_scen * multiple(period),
        period,
    )
    return ReprPeriod(
        ros.rper,
        scen_per,
        ros.multiple_scen * multiple(scen_period),
    )
end

function Base.eachindex(ros::ReprOperationalScenario)
    return eachindex(ros.operational)
end

# Iteration through scenarios of a representative period
struct RepOpScens{T}
    rper::Int64
    mult::Float64
    op_scens::OperationalScenarios{T}
end

"""
    opscenarios(rep::RepresentativePeriod)

Iterator that iterates over operational scenarios in a `RepresentativePeriod` time structure.
"""
function opscenarios(
    rep::RepresentativePeriod{T,OperationalScenarios{T,OP}},
) where {T,OP}
    mult = rep.per_share * duration(rep) / duration(rep.operational)
    return RepOpScens(rep.rper, mult, rep.operational)
end

opscenarios(rep::RepresentativePeriod) = [rep]

Base.length(ros::RepOpScens) = length(ros.op_scens)

function Base.iterate(ros::RepOpScens)
    mult_scen = duration(ros.op_scens) / duration(ros.op_scens.scenarios[1])
    return ReprOperationalScenario(
        ros.rper,
        1,
        ros.op_scens.probability[1],
        ros.mult,
        mult_scen,
        ros.op_scens.scenarios[1],
    ),
    1
end

function Base.iterate(ros::RepOpScens, state)
    state == length(ros.op_scens.scenarios) && return nothing
    mult_scen =
        duration(ros.op_scens) / duration(ros.op_scens.scenarios[state+1])
    return ReprOperationalScenario(
        ros.rper,
        state + 1,
        ros.op_scens.probability[state+1],
        ros.mult,
        mult_scen,
        ros.op_scens.scenarios[state+1],
    ),
    state + 1
end
