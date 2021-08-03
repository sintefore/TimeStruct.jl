# Defintion of the main types for the timestructures
abstract type TimeStructure end
abstract type TimePeriod{TimeStructure} end

" Definition of the individual time structures with two levels and corresponding
functions.

UniformTwoLevel:
	Operational periods are the same for all strategic periods
	Strategic periods have the same, fixed duration
	
DynamicOperationalLevel:
	Operational periods are different in each strategic period
	Strategic periods have the same, fixed duration
	
DynamicOperationalLevel:
	Operational periods are the same for all strategic periods
	Strategic periods can have a different duration

DynamicTwoLevel:
	Operational periods are different in each strategic period
	Strategic periods can have a different duration
"

# Composite type defintion
struct UniformTwoLevel <: TimeStructure
	first
	len::Integer
	duration # or better scale?
	operational::TimeStructure
end

struct DynamicOperationalLevel <: TimeStructure
	first
	len::Integer
	duration
	operational::Array{TimeStructure}
end

struct DynamicStrategicLevel <: TimeStructure
	first
	len::Integer
	duration::Array
	operational::TimeStructure
end

struct DynamicTwoLevel <: TimeStructure
	first
	len::Integer
	duration::Array
	operational::Array{TimeStructure}
end

# Calculation of the length (number of time periods)
Base.length(itr::Union{UniformTwoLevel,DynamicStrategicLevel}) = itr.len * itr.operational.len
Base.length(itr::Union{DynamicOperationalLevel,DynamicTwoLevel}) = sum(itr.operational[sp].len for sp ∈ 1:itr.len)


Base.eltype(::Type{UniformTwoLevel}) = OperationalPeriod

# Function for defining the time periods when iterating through the time structures with two levels
function Base.iterate(itr::Union{UniformTwoLevel,DynamicStrategicLevel}, state=OperationalPeriod(1,1))
	if state.sp > itr.len
		return nothing
	end
	if state.op >= itr.operational.len
		return (state,
				OperationalPeriod(state.sp + 1, 1))
	else
		return (state,
				OperationalPeriod(state.sp, state.op + 1))
	end
end

function Base.iterate(itr::Union{DynamicOperationalLevel,DynamicTwoLevel}, state=OperationalPeriod(1,1))
	if state.sp > itr.len
		return nothing
	end
	if state.op >= itr.operational[state.sp].len
		return (state,
				OperationalPeriod(state.sp + 1, 1))
	else
		return (state,
				OperationalPeriod(state.sp, state.op + 1))
	end
end

# Create time periods when iterating a time structure
# Use to identify time period (e.g. in variables and constraints)
# Use to look up input values (price, demand etc)
struct OperationalPeriod <: TimePeriod{UniformTwoLevel}
	sp
	op
	duration
end
OperationalPeriod(sp, op) = OperationalPeriod(sp, op, 1)

function Base.getproperty(op::OperationalPeriod,sym::Symbol)
	if sym == :idx
		return (op.sp, op.op)
	else # fallback to getfield
        return getfield(op, sym)
    end
end
isfirst(op::OperationalPeriod) = op.op == 1 
Base.show(io::IO, op::OperationalPeriod) = print(io, "t$(op.sp)_$(op.op)")

struct StrategicPeriod <: TimePeriod{UniformTwoLevel}
	sp
	sps
	len
	duration
	operational::TimeStructure
end

isfirst(sp::StrategicPeriod) = sp.sp == 1
Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")


struct UniformTimes <: TimeStructure
	first
	len::Integer
	duration
end

struct UniformPeriod 
	op
	duration
end
UniformPeriod(op) = UniformPeriod(op, 1)

Base.length(itr::UniformTimes) = itr.len
Base.eltype(::Type{UniformTimes}) = UniformPeriod
function Base.iterate(itr::UniformTimes, state=UniformPeriod(1, itr.duration))
	if state.op > itr.len
		return nothing
	else
		return state, UniformPeriod(state.op + 1, itr.duration)
	end
end

function Base.getproperty(up::UniformPeriod,sym::Symbol)
	if sym == :idx
		return up.op
	else # fallback to getfield
        return getfield(up, sym)
    end
end
isfirst(up::UniformPeriod) = up.op == 1
previous(up::UniformPeriod) = (up.op == 1 ? nothing : UniformPeriod(up.op - 1, up.duration))
Base.show(io::IO, up::UniformPeriod) = print(io, "t$(up.op)")

struct DynamicPeriod 
	op
	duration
end

struct DynamicTimes <: TimeStructure
	first
	len::Integer
	duration::Array
end

isfirst(dp::DynamicPeriod) = dp.op == 1
Base.length(itr::DynamicTimes) = itr.len
Base.eltype(::Type{DynamicTimes}) = DynamicPeriod
Base.show(io::IO, up::DynamicPeriod) = print(io, "t$(up.op)")

function Base.iterate(itr::DynamicTimes)
	return DynamicPeriod(1, itr.duration[1]), 1
end

function Base.iterate(itr::DynamicTimes, state)
	state == itr.len && return nothing
	return DynamicPeriod(state + 1, itr.duration[state + 1]), state + 1 
end


Base.length(itr::StrategicPeriod) = itr.operational.len
Base.eltype(::Type{StrategicPeriod}) = OperationalPeriod

# Function for defining the time periods when iterating through a strategic period
function Base.iterate(itr::StrategicPeriod, state=OperationalPeriod(itr.sp,1))
	if state.op > itr.len
		return nothing
	else
		return state, OperationalPeriod(itr.sp, state.op + 1)
	end
end

"""
	strategic_periods(ts::UniformTwoLevel)
Return the strategic periods of the provided time structure.
"""
function strategic_periods(ts::UniformTwoLevel)
	return (StrategicPeriod(sp,ts.len,ts.operational.len,ts.duration,ts.operational) for sp ∈ 1:ts.len)
end

function strategic_periods(ts::DynamicOperationalLevel)
	return (StrategicPeriod(sp,ts.len,ts.operational[sp].len,ts.duration,ts.operational[sp]) for sp ∈ 1:ts.len)
end

function strategic_periods(ts::DynamicStrategicLevel)
	return (StrategicPeriod(sp,ts.len,ts.operational.len,ts.duration[sp],ts.operational) for sp ∈ 1:ts.len)
end

function strategic_periods(ts::DynamicTwoLevel)
	return (StrategicPeriod(sp,ts.len,ts.operational[sp].len,ts.duration[sp],ts.operational[sp]) for sp ∈ 1:ts.len)
end

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
        return OperationalPeriod(op.sp, max(1, op.op - 1))
    end
end


"""
	first_operational(sp::StrategicPeriod)
Return the first operational period of a strategic period sp
"""
function first_operational(sp::StrategicPeriod)
    return OperationalPeriod(sp.sp, 1)
end

"""
	last_operational(sp::StrategicPeriod)
Return the last operational period of a strategic period sp
"""
function last_operational(sp::StrategicPeriod)
    return OperationalPeriod(sp.sp, sp.len)
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