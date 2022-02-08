"""
    struct OperationalScenarios <: TimeStructure
Time structure that have multiple scenarios where each scenario has its own time structure
and an associated probability. Note that all scenarios must use the same type for the duration.
"""
struct OperationalScenarios{T} <: TimeStructure{T}
	len::Integer
	scenarios::Vector{<:TimeStructure{T}}
	probability::Vector{Float64}
end
OperationalScenarios(len, oper::TimeStructure{T}) where {T} = OperationalScenarios{T}(len, fill(oper, len), fill(1.0 / len, len))
OperationalScenarios(oper::Vector{<:TimeStructure{T}}, prob::Vector) where {T} = OperationalScenarios{T}(length(oper), oper, prob)


duration(os::OperationalScenarios) = maximum(duration(sc) for sc in os.scenarios)

# Iteration through all time periods for the operational scenarios
function Base.iterate(itr::OperationalScenarios)
	sc = 1
	next = iterate(itr.scenarios[sc])
	next === nothing && return nothing
	return ScenarioPeriod(sc, next[1].op, next[1].duration, itr.probability[sc]), (sc, next[2])
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
	return ScenarioPeriod(sc, next[1].op, next[1].duration, itr.probability[sc]), (sc,next[2])
end
Base.length(itr::OperationalScenarios) = sum(length(itr.scenarios[sc]) for sc ∈ 1:itr.len)
Base.eltype(::Type{OperationalScenarios{T}}) where {T} = ScenarioPeriod{T}

# A time period with scenario number and probability
struct ScenarioPeriod{T} <: TimePeriod{OperationalScenarios}
	sc::Int64
	op::Int64
	duration::T
	prob::Float64
end

ScenarioPeriod(sc, op) = ScenarioPeriod(sc, op, 1.0, 1.0)

Base.show(io::IO, up::ScenarioPeriod) = print(io, "t-$(up.sc)_$(up.op)")
Base.isless(t1::ScenarioPeriod, t2::ScenarioPeriod) = t1.sc < t2.sc || (t1.sc == t2.sc && t1.op < t2.op)


probability(::TimePeriod) = 1.0
probability(t::ScenarioPeriod) = t.prob 

"""
    struct OperationalScenario 
A structure representing a single operational scenario supporting
iteration over its time periods.
"""
struct OperationalScenario{T} 
	scen::Int64
	probability::Float64
	operational::TimeStructure{T}
end
Base.show(io::IO, os::OperationalScenario) = print(io, "sc-$(os.scen)")
probability(os::OperationalScenario) = os.probability

# Iterate the time periods of an operational scenario
function Base.iterate(os::OperationalScenario)
	next = iterate(os.operational)
	next === nothing && return nothing
	return ScenarioPeriod(1, next[1].op, next[1].duration, os.probability), (1, next[2])
end

function Base.iterate(os::OperationalScenario, state)
	next = iterate(os.operational, state[2])
	next === nothing && return nothing
	return ScenarioPeriod(os.scen, next[1].op, next[1].duration, os.probability), (1, next[2])
end
Base.length(os::OperationalScenario) = length(os.operational)
Base.eltype(::Type{OperationalScenario}) = ScenarioPeriod

# Iteration through scenarios 
struct OpScens{T}
	ts::OperationalScenarios{T}
end
"""
    opscenarios(ts)
Iterator that iterates over operational scnenarios in an `OperationalScenarios` time structure.
"""
opscenarios(ts) = OpScens(ts)

Base.length(ops::OpScens) = ops.ts.len

function Base.iterate(ops::OpScens)
	return OperationalScenario(1, ops.ts.probability[1], ops.ts.scenarios[1]), 1
end

function Base.iterate(ops::OpScens, state)
	state == ops.ts.len && return nothing
	return OperationalScenario(state+1, ops.ts.probability[state + 1], ops.ts.scenarios[state+1]), state + 1 
end

