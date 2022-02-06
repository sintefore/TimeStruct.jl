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
struct TwoLevel{T <: Number} <: TimeStructure
	len::Integer
	duration::Vector{T} 
	operational::Vector{TimeStructure}
end

TwoLevel(len, duration::T, oper::TimeStructure) where {T <: Number} = TwoLevel{T}(len, fill(duration, len), fill(oper, len))
TwoLevel(len, duration::T, oper::Vector{TimeStructure}) where {T <: Number} = TwoLevel{T}(len, fill(duration, len), oper)
TwoLevel(duration::Vector{T}, oper::TimeStructure) where {T <: Number} = TwoLevel{T}(length(duration), duration, fill(oper,length(duration)))

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

"""
	struct OperationalPeriod <: TimePeriod{TwoLevel}    
Time period for iteration of a TwoLevel time structure. 
"""
struct OperationalPeriod{T <: Number} <: TimePeriod{TwoLevel}
	sp::Int64
	sc::Union{Nothing,Int64}
	op::Int64
	duration::T
	prob::Float64
end
OperationalPeriod(sp, op) = OperationalPeriod(sp, nothing, op, 1, 1.0)
OperationalPeriod(sp, sc, op) = OperationalPeriod(sp, sc, op, 1, 1.0)

op(scp::ScenarioPeriod, sp) = OperationalPeriod(sp, scp.sc, scp.op, scp.duration, scp.prob)

isfirst(op::OperationalPeriod) = op.op == 1 
duration(op::OperationalPeriod) = op.duration
probability(op::OperationalPeriod) = op.prob
Base.show(io::IO, op::OperationalPeriod) = isnothing(op.sc) ? print(io, "t$(op.sp)_$(op.op)") : print(io, "t$(op.sp)-$(op.sc)_$(op.op)") 
Base.isless(t1::OperationalPeriod, t2::OperationalPeriod) = t1.sp < t2.sp || (t1.sp == t2.sp &&t1.op < t2.op)


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

"""
    strat_periods(ts::TwoLevel)
Iteration through the strategic periods of a 'TwoLevel' structure.
"""
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


# Let SimpleTimes and OperationalScenarios behave as a TwoLevel time structure with one strategic period
strat_periods(ts::Union{SimpleTimes,OperationalScenarios}) = [StrategicPeriod{SimpleTimes}(1, duration(ts), ts)]
strat_per(t::Union{SimplePeriod,ScenarioPeriod}) = 1

Base.eltype(::Type{StrategicPeriod{SimpleTimes}}) = SimplePeriod
function Base.iterate(itr::StrategicPeriod{SimpleTimes}, state=nothing) 
	next = isnothing(state) ? iterate(itr.operational) : iterate(itr.operational, state)
	next === nothing && return nothing
	per = next[1]
	return per, next[2]
end
