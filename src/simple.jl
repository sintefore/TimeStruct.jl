"""
    struct SimpleTimes{T} <: TimeStructure{T}

    SimpleTimes(len::Integer, duration::Vector{T}) where {T<:Duration}
    SimpleTimes(len::Integer, duration::Duration)
    SimpleTimes(dur::Vector{T}) where {T<:Duration}

A simple time structure consisting of consecutive time periods of varying duration.
`SimpleTimes` is always the lowest level in a `TimeStruct` time structure, if used.

An alternative to `SimpleTimes` is [`CalendarTimes`](@ref)

## Example
```julia
uniform = SimpleTimes(5, 1.0) # 5 periods of equal length
varying = SimpleTimes([2, 2, 2, 4, 10]) # 5 periods of varying length
```
"""
struct SimpleTimes{T} <: TimeStructure{T}
    len::Int
    duration::Vector{T}
    total_duration::T
    function SimpleTimes(len::Integer, duration::Vector{T}) where {T<:Duration}
        if len > length(duration)
            throw(
                ArgumentError(
                    "The length of `duration` cannot be less than the length `len` of `SimpleTimes`.",
                ),
            )
        else
            new{T}(len, duration, sum(duration))
        end
    end
end
function SimpleTimes(len::Integer, duration::Duration)
    return SimpleTimes(len, fill(duration, len))
end
SimpleTimes(dur::Vector{T}) where {T<:Duration} = SimpleTimes(length(dur), dur)

_total_duration(st::SimpleTimes) = st.total_duration

# Add basic functions of iterators
Base.length(st::SimpleTimes) = st.len
Base.eltype(::Type{SimpleTimes{T}}) where {T} = SimplePeriod{T}
function Base.iterate(itr::SimpleTimes{T}, state = nothing) where {T}
    next = isnothing(state) ? 1 : state + 1
    next > itr.len && return nothing

    return SimplePeriod{T}(next, itr.duration[next]), next
end
function Base.getindex(itr::SimpleTimes{T}, index) where {T}
    return SimplePeriod{T}(index, itr.duration[index])
end
function Base.eachindex(itr::SimpleTimes{T}) where {T}
    return Base.OneTo(itr.len)
end
function Base.last(ts::SimpleTimes{T}) where {T}
    return SimplePeriod{T}(ts.len, ts.duration[ts.len])
end

"""
    struct SimplePeriod{T<:Number} <: TimePeriod

Time period for a single operational period. It is created through iterating through a
[`SimpleTimes`](@ref) time structure.
"""
struct SimplePeriod{T<:Number} <: TimePeriod
    op::Int
    duration::T
end

_oper(t::SimplePeriod) = t.op

isfirst(t::SimplePeriod) = t.op == 1
duration(t::SimplePeriod) = t.duration

Base.show(io::IO, t::SimplePeriod) = print(io, "t$(t.op)")
Base.isless(t1::SimplePeriod, t2::SimplePeriod) = t1.op < t2.op
