abstract type TimeStructure end
abstract type TimePeriod{TimeStructure} end

duration(::TimePeriod) = error("duration() not implemented for time period")
isfirst(::TimePeriod) = error("isfirst() not implemented for time period")


"""
    struct SimpleTimes <: TimeStructure
A simple time structure conisisting of a sequence of time periods of varying length

Example
```julia
uniform = SimpleTimes(5, 1) # 5 periods of equal length
varying = SimpleTimes([2, 2, 2, 4, 10]) 
```
"""
struct SimpleTimes <: TimeStructure
	len::Integer
	duration::Vector{Float64}
end
SimpleTimes(len, duration::Number) = SimpleTimes(len, fill(duration, len))
SimpleTimes(dur::Vector{Float64}) = SimpleTimes(length(dur), dur)

Base.eltype(::Type{SimpleTimes}) = SimplePeriod
Base.length(st::SimpleTimes) = st.len

duration(st::SimpleTimes) = sum(st.duration)

""" 
    struct SimplePeriod <: TimePeriod{SimpleTimes} 
A single time period returned when iterating through a SimpleTimes structure
"""
struct SimplePeriod <: TimePeriod{SimpleTimes}
	op::Integer
	duration::Float64
end

duration(p::SimplePeriod) = p.duration
isfirst(p::SimplePeriod) = p.op == 1

Base.isless(t1::SimplePeriod, t2::SimplePeriod) = t1.op < t2.op
Base.length(itr::SimplePeriod) = itr.len
Base.show(io::IO, up::SimplePeriod) = print(io, "t$(up.op)")

function Base.iterate(itr::SimpleTimes)
	return SimplePeriod(1, itr.duration[1]), 1
end

function Base.iterate(itr::SimpleTimes, state)
	state == itr.len && return nothing
	return SimplePeriod(state + 1, itr.duration[state + 1]), state + 1 
end
