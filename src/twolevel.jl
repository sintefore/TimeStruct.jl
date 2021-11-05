" Definition of a time structures with two levels and corresponding functions.
	len - number of strategic periods
	duration - the duration of each strategic period
	operational - the operational time structure for each strategic period"
struct TwoLevel <: TimeStructure
	len::Integer
	duration::Vector{Float64} 
	operational::Vector{TimeStructure}
end

TwoLevel(len, duration::Number, oper::TimeStructure) = TwoLevel(len, fill(duration, len), fill(oper, len))
TwoLevel(len, duration::Number, oper::Vector{T}) where T<:TimeStructure = TwoLevel(len, fill(duration, len), oper)
TwoLevel(len, duration::Vector, oper::TimeStructure) = TwoLevel(len, duration, fill(oper,len))

function Base.iterate(itr::TwoLevel)
	sp = 1
	next = iterate(itr.operational[sp])
	next === nothing && return nothing
	per = next[1]
	return OperationalPeriod(sp, opscen(per), per.op, per.duration, probability(per)), (sp, next[2])
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
	return OperationalPeriod(sp, opscen(per), per.op, per.duration , probability(per)), (sp,next[2])
end

Base.length(itr::TwoLevel) = sum(length(itr.operational[sp]) for sp ∈ 1:itr.len)
Base.eltype(::Type{TwoLevel}) = OperationalPeriod

# Create time periods when iterating a time structure
# Use to identify time period (e.g. in variables and constraints)
# Use to look up input values (price, demand etc)
struct OperationalPeriod <: TimePeriod{TwoLevel}
	sp
	sc
	op
	duration
	prob
end
OperationalPeriod(sp, op) = OperationalPeriod(sp, nothing, op, 1, 1.0)
OperationalPeriod(sp, sc, op) = OperationalPeriod(sp, sc, op, 1, 1.0)

op(scp::ScenarioPeriod, sp) = OperationalPeriod(sp, scp.sc, scp.op, scp.duration, scp.prob)

isfirst(op::OperationalPeriod) = op.op == 1 
duration(op::OperationalPeriod) = op.duration
probability(op::OperationalPeriod) = op.prob
Base.show(io::IO, op::OperationalPeriod) = isnothing(op.sc) ? print(io, "t$(op.sp)_$(op.op)") : print(io, "t$(op.sp)-$(op.sc)_$(op.op)") 
Base.isless(t1::OperationalPeriod, t2::OperationalPeriod) = t1.sp < t2.sp || (t1.sp == t2.sp &&t1.op < t2.op)

function multiple(op::OperationalPeriod, ts::TwoLevel) 
	
	if isa(ts.operational[op.sp], OperationalScenarios)
		dur = duration(ts.operational[op.sp].scenarios[op.sc])
	else
		dur = duration(ts.operational[op.sp])
	end	
	return ts.duration[op.sp] / dur
end


opscen(::TimePeriod) = nothing
opscen(t::ScenarioPeriod) = t.sc
opscen(t::OperationalPeriod) = t.sc


struct StrategicPeriod{T} <: TimePeriod{TwoLevel} where T <: TimeStructure
	sp
	duration
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

strat_periods(ts::TwoLevel) = StratPeriods(ts)
Base.length(sps::StratPeriods) = sps.ts.len


function Base.iterate(sps::StratPeriods) 
	return StrategicPeriod{TwoLevel}(1, sps.ts.duration[1], sps.ts.operational[1]), 1
end

function Base.iterate(sps::StratPeriods, state) 
	state == sps.ts.len && return nothing
	return StrategicPeriod{TwoLevel}(state + 1, sps.ts.duration[state + 1], sps.ts.operational[state+1]), state + 1 
end

Base.length(itr::StrategicPeriod{T}) where {T} = itr.operational.len
Base.eltype(::Type{StrategicPeriod{TwoLevel}}) = OperationalPeriod

# Function for defining the time periods when iterating through a strategic period
function Base.iterate(itr::StrategicPeriod{TwoLevel}, state=nothing) 
	next = isnothing(state) ? iterate(itr.operational) : iterate(itr.operational, state)
	next === nothing && return nothing
	per = next[1]
	return OperationalPeriod(itr.sp, opscen(per), per.op, per.duration, probability(per)), next[2]
end


# Let SimpleTimes behave as a TwoLevel time structure with one strategic period
strat_periods(ts::SimpleTimes) = [StrategicPeriod{SimpleTimes}(1, duration(ts), ts)]
strat_per(t::SimplePeriod) = 1
Base.eltype(::Type{StrategicPeriod{SimpleTimes}}) = SimplePeriod
function Base.iterate(itr::StrategicPeriod{SimpleTimes}, state=nothing) 
	next = isnothing(state) ? iterate(itr.operational) : iterate(itr.operational, state)
	next === nothing && return nothing
	per = next[1]
	return per, next[2]
end
