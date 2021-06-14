abstract type TimePeriod{TimeStructure} end

abstract type TimeStructure end

struct UniformTwoLevel <: TimeStructure
	first
	len::Integer
	duration # or better scale?
	operational::TimeStructure
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

Base.show(io::IO, sp::StrategicPeriod) = print(io, "sp$(sp.sp)")

# Each strategic period may have different operational structure
struct DynamicOperationalLevel <: TimeStructure
	first
	len::Integer
	duration
	operational::Array{TimeStructure}
end

# Each strategic period may have different duration and different operational structure
struct DynamicTwoLevel <: TimeStructure
	first
	len::Integer
	duration::Array
	operational::Array{TimeStructure}
end

struct UniformTimes <: TimeStructure
	first
	len::Integer
	duration
end

Base.length(itr::UniformTwoLevel) = itr.len * itr.operational.len
Base.eltype(::Type{UniformTwoLevel}) = OperationalPeriod

function Base.iterate(itr::UniformTwoLevel, state=OperationalPeriod(1,1))
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

function Base.iterate(itr::DynamicTimes)
	return DynamicPeriod(1, itr.duration[1]), 1
end

function Base.iterate(itr::DynamicTimes, state)
	state == itr.len && return nothing
	return DynamicPeriod(state + 1, itr.duration[state + 1]), state + 1 
end



Base.length(itr::StrategicPeriod) = itr.operational.len
Base.eltype(::Type{StrategicPeriod}) = OperationalPeriod

function Base.iterate(itr::StrategicPeriod, state=OperationalPeriod(itr.sp,1))
	if state.op > itr.len
		return nothing
	else
		return state, OperationalPeriod(itr.sp, state.op + 1)
	end
end

function strategic_periods(ts::UniformTwoLevel)
	return (StrategicPeriod(sp,ts.len,ts.operational.len,ts.duration,ts.operational) for sp ∈ 1:ts.len)
end

function next(sp::StrategicPeriod)
	if sp.sp > sp.sps
		return nothing
	else
		return StrategicPeriod(sp.sp + 1, sp.sps, sp.len, sp.duration, sp.operational)
	end
end

function previous(sp::StrategicPeriod)
	if sp.sp == 1
		return nothing
	else
		return StrategicPeriod(sp.sp - 1, sp.sps, sp.len, sp.duration, sp.operational)
	end
end

function previous(op::OperationalPeriod)
    if op.op == 1
        return nothing
    else
        return OperationalPeriod(op.sp, max(1, op.op - 1))
    end
end

function first_operational(sp::StrategicPeriod)
    return OperationalPeriod(sp.sp, 1)
end

function last_operational(sp::StrategicPeriod)
    return OperationalPeriod(sp.sp, sp.len)
end

function duration_years(ts::TimeStructure, sp::StrategicPeriod)
    ts.duration
end

function duration_years(ts::DynamicTwoLevel, sp::StrategicPeriod)
    ts.duration[sp.sp]
end

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

function endyear(ts::TimeStructure, sp::StrategicPeriod)
    startyear(ts, sp) + ts.duration
end
