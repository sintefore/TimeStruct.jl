""" 
    struct SimpleTimes <: TimeStructure
A simple time structure conisisting of consecutive time periods of varying duration

Example
```julia
uniform = SimpleTimes(5, 1.0) # 5 periods of equal length
varying = SimpleTimes([2, 2, 2, 4, 10]) 
```
"""
struct SimpleTimes{T} <: TimeStructure{T}
    len::Int
    duration::Vector{T}
end
function SimpleTimes(len::Integer, duration::Number)
    return SimpleTimes(len, fill(duration, len))
end
SimpleTimes(dur::Vector{T}) where {T<:Number} = SimpleTimes(length(dur), dur)
function SimpleTimes(dur::Vector{T}, u::Unitful.Units) where {T<:Real}
    return SimpleTimes(length(dur), Unitful.Quantity.(dur, u))
end

Base.eltype(::Type{SimpleTimes{T}}) where {T} = SimplePeriod{T}
Base.length(st::SimpleTimes) = st.len

duration(st::SimpleTimes) = sum(st.duration)

""" 
    struct SimplePeriod <: TimePeriod
A single time period returned when iterating through a SimpleTimes structure
"""
struct SimplePeriod{T<:Number} <: TimePeriod
    op::Int
    duration::T
end

duration(t::SimplePeriod) = t.duration
isfirst(t::SimplePeriod) = t.op == 1
_oper(t::SimplePeriod) = t.op

Base.isless(t1::SimplePeriod, t2::SimplePeriod) = t1.op < t2.op
Base.show(io::IO, t::SimplePeriod) = print(io, "t$(t.op)")

function Base.iterate(itr::SimpleTimes{T}) where {T}
    return SimplePeriod{T}(1, itr.duration[1]), 1
end

function Base.iterate(itr::SimpleTimes{T}, state) where {T}
    state == itr.len && return nothing
    return SimplePeriod{T}(state + 1, itr.duration[state+1]), state + 1
end
