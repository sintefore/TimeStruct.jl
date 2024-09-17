"""
    struct OperationalScenarios{T,OP<:TimeStructure{T}} <: TimeStructure{T}

    OperationalScenarios(len::Integer, scenarios::Vector{OP}, probability::Vector{<:Real}) where {T, OP<:TimeStructure{T}
    OperationalScenarios(len::Integer, oper::TimeStructure{T})

    OperationalScenarios(oper::Vector{<:TimeStructure{T}}, prob::Vector)
    OperationalScenarios(oper::Vector{<:TimeStructure{T}})

Time structure that have multiple scenarios where each scenario has its own time structure
and an associated probability. These scenarios are in general represented as
[`SimpleTimes`](@ref).

!!! note
    - All scenarios must use the same type for the duration, _.i.e._, either Integer or Float.
    - If the `probability` is not specified, it assigns the same probability to each scenario.
    - It is possible that `sum(probability)` is larger or smaller than 1. This can lead to
      problems in your application. Hence, it is advised to scale it. Currently, a warning
      will be given if the period shares do not sum to one as an automatic scaling will
      correspond to a breaking change.

## Example
The following examples create a time structure with 2 operational scenarios corresponding to
a single day with equal probability.
```julia
day = SimpleTimes(24, 1)
OperationalScenarios(2, day)
OperationalScenarios([day, day], [0.5, 0.5])
OperationalScenarios([day, day])
```
"""
struct OperationalScenarios{T,OP<:TimeStructure{T}} <: TimeStructure{T}
    len::Int
    scenarios::Vector{OP}
    probability::Vector{Float64}
    function OperationalScenarios(
        len::Integer,
        scenarios::Vector{OP},
        probability::Vector{<:Real},
    ) where {T,OP<:TimeStructure{T}}
        if len > length(scenarios)
            throw(
                ArgumentError(
                    "The length of `scenarios` cannot be less than the field `len` of `OperationalScenarios`.",
                ),
            )
        elseif len > length(probability)
            throw(
                ArgumentError(
                    "The length of `probability` cannot be less than the field `len` of `OperationalScenarios`.",
                ),
            )
        elseif sum(probability) > 1 || sum(probability) < 1
            @warn(
                "The sum of the probablity vector is given by $(sum(probability)). " *
                "This can lead to unexpected behaviour."
            )
        end
        return new{T,OP}(len, scenarios, convert(Vector{Float64}, probability))
    end
end
function OperationalScenarios(len::Integer, oper::TimeStructure{T}) where {T}
    return OperationalScenarios(len, fill(oper, len), fill(1.0 / len, len))
end
function OperationalScenarios(oper::Vector{<:TimeStructure{T}}, prob::Vector) where {T}
    return OperationalScenarios(length(oper), oper, prob)
end
function OperationalScenarios(oper::Vector{<:TimeStructure{T}}) where {T}
    return OperationalScenarios(length(oper), oper, fill(1.0 / length(oper), length(oper)))
end

function _total_duration(oscs::OperationalScenarios)
    return maximum(_total_duration(osc) for osc in oscs.scenarios)
end

function _multiple_adj(oscs::OperationalScenarios, scen)
    return stripunit(_total_duration(oscs) / _total_duration(oscs.scenarios[scen]))
end

# Iteration through all time periods for the operational scenarios
function Base.length(oscs::OperationalScenarios)
    return sum(length(oscs.scenarios[osc]) for osc in 1:oscs.len)
end
function Base.eltype(::Type{OperationalScenarios{T,OP}}) where {T,OP}
    return ScenarioPeriod{eltype(OP)}
end
function Base.iterate(oscs::OperationalScenarios, state = (nothing, 1))
    osc = state[2]
    next =
        isnothing(state[1]) ? iterate(oscs.scenarios[osc]) :
        iterate(oscs.scenarios[osc], state[1])
    if next === nothing
        osc = osc + 1
        if osc > oscs.len
            return nothing
        end
        next = iterate(oscs.scenarios[osc])
    end
    return ScenarioPeriod(oscs, next[1], osc), (next[2], osc)
end
function Base.last(oscs::OperationalScenarios)
    return ScenarioPeriod(
        oscs.len,
        oscs.probability[oscs.len],
        _multiple_adj(oscs, oscs.len),
        last(oscs.scenarios[oscs.len]),
    )
end

"""
	ScenarioPeriod{P} <: TimePeriod where {P<:TimePeriod}

Time period for a single operational period. It is created through iterating through a
[`OperationalScenarios`](@ref) time structure. It is as well created as period within
[`OperationalPeriod`](@ref) when the time structure includes [`OperationalScenarios`](@ref).
"""
struct ScenarioPeriod{P} <: TimePeriod where {P<:TimePeriod}
    osc::Int
    prob::Float64
    multiple::Float64
    period::P
end

_oper(t::ScenarioPeriod) = _oper(t.period)
_opscen(t::ScenarioPeriod) = t.osc

isfirst(t::ScenarioPeriod) = isfirst(t.period)
duration(t::ScenarioPeriod) = duration(t.period)
multiple(t::ScenarioPeriod) = t.multiple
probability(t::ScenarioPeriod) = t.prob

Base.show(io::IO, t::ScenarioPeriod) = print(io, "sc$(t.osc)-$(t.period)")
function Base.isless(t1::ScenarioPeriod, t2::ScenarioPeriod)
    return t1.osc < t2.osc || (t1.osc == t2.osc && t1.period < t2.period)
end

# Convenience constructors for the type
function ScenarioPeriod(osc::Int, prob::Number, multiple::Number, period)
    return ScenarioPeriod(
        osc,
        Base.convert(Float64, prob),
        Base.convert(Float64, multiple),
        period,
    )
end
function ScenarioPeriod(oscs::OperationalScenarios, per::TimePeriod, osc::Int)
    prob = oscs.probability[osc]
    mult = _multiple_adj(oscs, osc)
    return ScenarioPeriod(osc, prob, mult, per)
end
