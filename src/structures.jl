# Defintion of the main types for the timestructures
abstract type TimeStructure end
abstract type TimePeriod{TimeStructure} end

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
	return OperationalPeriod(sp, opscen(per), per.op, per.duration, prob(per)), (sp, next[2])
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
	return OperationalPeriod(sp, opscen(per), per.op, per.duration , prob(per)), (sp,next[2])
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
OperationalPeriod(sp, op, dur) = OperationalPeriod(sp, nothing, op, dur, 1.0)

isfirst(op::OperationalPeriod) = op.op == 1 
duration(op::OperationalPeriod) = op.duration
strat_per(op::OperationalPeriod) = op.sp
prob(op::OperationalPeriod) = op.prob
Base.show(io::IO, op::OperationalPeriod) = isnothing(op.sc) ? print(io, "t$(op.sp)_$(op.op)") : print(io, "t$(op.sp)-$(op.sc)_$(op.op)") 
Base.isless(t1::OperationalPeriod, t2::OperationalPeriod) = t1.sp < t2.sp || (t1.sp == t2.sp &&t1.op < t2.op)

function multiple(op::OperationalPeriod, ts::TwoLevel) 
	
	if op.sc !== nothing
		dur = duration(ts.operational[op.sp].scenarios[op.sc])
	else
		dur = duration(ts.operational[op.sp])
	end	
	return ts.duration[op.sp] / dur
end


" Time structure that have multiple scenarios where each scenario has its own time structure"
struct ScenarioOperational <: TimeStructure
	len
	scenarios::Vector{TimeStructure}
	probability::Vector{Float64}
end
ScenarioOperational(len, oper::TimeStructure) = ScenarioOperational(len, fill(oper, len), fill(1.0 / len, len))

function Base.iterate(itr::ScenarioOperational)
	sc = 1
	next = iterate(itr.scenarios[sc])
	next === nothing && return nothing
	return ScenarioPeriod(sc, next[1].op, next[1].duration, itr.probability[sc]), (sc, next[2])
end

function Base.iterate(itr::ScenarioOperational, state)
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
Base.length(itr::ScenarioOperational) = sum(length(itr.scenarios[sc]) for sc ∈ 1:itr.len)
Base.eltype(::Type{ScenarioOperational}) = ScenarioPerid

struct ScenarioPeriod <: TimePeriod{ScenarioOperational}
	sc
	op
	duration
	prob
end
Base.show(io::IO, up::ScenarioPeriod) = print(io, "t-$(up.sc)_$(up.op)")

prob(::TimePeriod) = 1.0
prob(t::ScenarioPeriod) = t.prob 
prob(t::OperationalPeriod) = t.prob 


opscen(::TimePeriod) = nothing
opscen(t::ScenarioPeriod) = t.sc
opscen(t::OperationalPeriod) = t.sc


struct StrategicPeriod <: TimePeriod{TwoLevel}
	sp
	duration
	operational::TimeStructure
end

isfirst(sp::StrategicPeriod) = sp.sp == 1
Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")
Base.isless(sp1::StrategicPeriod, sp2::StrategicPeriod) = sp1.sp < sp2.sp 

struct StratPeriods
	ts::TwoLevel
end

strat_periods(ts) = StratPeriods(ts)
Base.length(sps::StratPeriods) = sps.ts.len


function Base.iterate(sps::StratPeriods)
	return StrategicPeriod(1, sps.ts.duration[1], sps.ts.operational[1]), 1
end

function Base.iterate(sps::StratPeriods, state)
	state == sps.ts.len && return nothing
	return StrategicPeriod(state + 1, sps.ts.duration[state + 1], sps.ts.operational[state+1]), state + 1 
end


"""
A simple time structure with index and duration 
"""
struct SimpleTimes <: TimeStructure
	len::Integer
	duration::Vector{Float64}
end
SimpleTimes(len, duration::Number) = SimpleTimes(len, fill(duration, len))
Base.length(st::SimpleTimes) = st.len
duration(st::SimpleTimes) = sum(st.duration)

struct SimplePeriod <: TimePeriod{SimpleTimes}
	op::Integer
	duration::Float64
end
Base.isless(t1::SimplePeriod, t2::SimplePeriod) = t1.op < t2.op

duration(p::SimplePeriod) = p.duration
isfirst(p::SimplePeriod) = p.op == 1
strat_per(p::SimplePeriod) = 1
Base.length(itr::SimplePeriod) = itr.len
Base.eltype(::Type{SimplePeriod}) = SimplePeriod
Base.show(io::IO, up::SimplePeriod) = print(io, "t$(up.op)")


function Base.iterate(itr::SimpleTimes)
	return SimplePeriod(1, itr.duration[1]), 1
end

function Base.iterate(itr::SimpleTimes, state)
	state == itr.len && return nothing
	return SimplePeriod(state + 1, itr.duration[state + 1]), state + 1 
end


Base.length(itr::StrategicPeriod) = itr.operational.len
Base.eltype(::Type{StrategicPeriod}) = OperationalPeriod

# Function for defining the time periods when iterating through a strategic period
function Base.iterate(itr::StrategicPeriod, state=OperationalPeriod(itr.sp,1,itr.operational.duration[1]))
	if state.op > itr.len
		return nothing
	else
		if length(itr.operational.duration) == 1
			return state, OperationalPeriod(itr.sp, state.op + 1, itr.operational.duration)
		elseif state.op == itr.len
			return state, OperationalPeriod(itr.sp, state.op + 1, itr.operational.duration[state.op])
		else
			return state, OperationalPeriod(itr.sp, state.op + 1, itr.operational.duration[state.op + 1])
		end
	end
end

"""
	strategic_periods(ts::TwoLevel)
Return the strategic periods of the provided time structure.
"""
#function strategic_periods(ts::TwoLevel)
#	return (StrategicPeriod(sp,ts.len,ts.operational[sp].len,ts.duration[sp],ts.operational[sp]) for sp ∈ 1:ts.len)
#end




###########################################################################################
###########################################################################################
# The following code is duplicated as it does not adhere to the proposed approach regarding
# the duration as well as the flexibility in the proposed two level timestructures
#=
"""
	next(sp::StrategicPeriod)
Return the following strategic period of a strategic period sp
"""
function next(sp::StrategicPeriod)
	if sp.sp > sp.sps
		return nothing
	else
		return StrategicPeriod(sp.sp + 1, sp.sps, sp.len, sp.duration, sp.operational)
	end
end

"""
	previous(sp::StrategicPeriod)
Return the previous strategic period of a strategic period sp
"""
function previous(sp::StrategicPeriod)
	if sp.sp == 1
		return nothing
	else
		return StrategicPeriod(sp.sp - 1, sp.sps, sp.len, sp.duration, sp.operational)
	end
end

"""
	previous(op::OperationalPeriod)
Return the previous operational period of an operational period op
"""
function previous(op::OperationalPeriod)
    if op.op == 1
        return nothing
    else
        return OperationalPeriod(op.sp, op.sc, max(1, op.op - 1))
    end
end

###########################################################################################
###########################################################################################

"""
next(sp::StrategicPeriod)
Return the following strategic period of a strategic period sp
"""
function next(sp::StrategicPeriod, ts::TwoLevel)
	if sp.sp > sp.sps
		return nothing
	else
		return StrategicPeriod(sp.sp + 1, sp.sps, ts.operational[sp].len, ts.duration[sp.sp + 1], ts.operational[sp.sp + 1])
	end
end

"""
previous(sp::StrategicPeriod)
Return the previous strategic period of a strategic period sp
"""
function previous(sp::StrategicPeriod, ts::TwoLevel)
	if sp.sp == 1
		return nothing
	else
		return StrategicPeriod(sp.sp - 1, sp.sps, ts.operational[sp].len, ts.duration[sp.sp - 1], ts.operational[sp.sp - 1])
	end
end

"""
previous(op::OperationalPeriod)
Return the previous operational period of an operational period op
"""
function previous(op::OperationalPeriod, ts::TwoLevel)
	if op.op == 1
		return nothing
	else
		return OperationalPeriod(op.sp, op.sc, op.op - 1, ts.operational[op.sp].duration[op.op - 1])
	end
end

###########################################################################################
###########################################################################################

"""
	first_operational(sp::StrategicPeriod)
Return the first operational period of a strategic period sp
"""
function first_operational(sp::StrategicPeriod)
	if typeof(sp.operational) == UniformTimes
    	return OperationalPeriod(sp.sp, 1, 1, sp.operational.duration)
	else 
    	return OperationalPeriod(sp.sp, 1, 1, sp.operational.duration[1])
	end
end

"""
	last_operational(sp::StrategicPeriod)
Return the last operational period of a strategic period sp
"""
function last_operational(sp::StrategicPeriod)
	if typeof(sp.operational) == UniformTimes
    	return OperationalPeriod(sp.sp, sp.len, sp.operational.duration)
	else 
    	return OperationalPeriod(sp.sp, sp.len, sp.operational.duration[sp.len])
	end
end

"""
	duration_years(ts::TimeStructure, sp::StrategicPeriod)
Return duration of a strategic period sp
"""
function duration_years(ts::TimeStructure, sp::StrategicPeriod)
    sp.duration
end


"""
	startyear(ts::TimeStructure, sp::StrategicPeriod)
Return start year of a strategic period sp
"""
function startyear(ts::TimeStructure, sp::StrategicPeriod)
    sy = ts.first
    for s ∈ strategic_periods(ts) # Not efficient, consider memoizing or storing in sp
        if s.sp == sp.sp
            return sy
        else
            sy += duration_years(ts, s)
        end
    end
end

"""
	endyear(ts::TimeStructure, sp::StrategicPeriod)
Return end year of a strategic period sp
"""
function endyear(ts::TimeStructure, sp::StrategicPeriod)
    startyear(ts, sp) + sp.duration
end
=#