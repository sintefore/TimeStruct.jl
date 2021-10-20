# Defintion of the main types for the timestructures
abstract type TimeStructure end
abstract type TimePeriod{TimeStructure} end

duration(::TimePeriod) = error("duration() not implemented for time period")

"""
A simple time structure with index and duration 
"""
struct SimpleTimes <: TimeStructure
	len::Integer
	duration::Vector{Float64}
end
SimpleTimes(len, duration::Number) = SimpleTimes(len, fill(duration, len))

Base.eltype(::Type{SimpleTimes}) = SimplePeriod
Base.length(st::SimpleTimes) = st.len

duration(st::SimpleTimes) = sum(st.duration)

struct SimplePeriod <: TimePeriod{SimpleTimes}
	op::Integer
	duration::Float64
end
Base.isless(t1::SimplePeriod, t2::SimplePeriod) = t1.op < t2.op

duration(p::SimplePeriod) = p.duration
isfirst(p::SimplePeriod) = p.op == 1

Base.length(itr::SimplePeriod) = itr.len
Base.show(io::IO, up::SimplePeriod) = print(io, "t$(up.op)")


function Base.iterate(itr::SimpleTimes)
	return SimplePeriod(1, itr.duration[1]), 1
end

function Base.iterate(itr::SimpleTimes, state)
	state == itr.len && return nothing
	return SimplePeriod(state + 1, itr.duration[state + 1]), state + 1 
end
