"""
    struct SimpleTimes{T} <: TimeStructure{T}

    SimpleTimes(len::Integer, duration::Vector{T}) where {T}
    SimpleTimes(len::Integer, duration::Number)
    SimpleTimes(dur::Vector{T}) where {T<:Number}

A simple time structure conisisting of consecutive time periods of varying duration.
`SimpleTimes` is always the lowest level in a `TimeStruct` time structure.

## Example
```julia
uniform = SimpleTimes(5, 1.0) # 5 periods of equal length
varying = SimpleTimes([2, 2, 2, 4, 10]) # 5 periods of varying length
```
"""
struct SimpleTimes{T} <: TimeStructure{T}
    len::Integer
    duration::Vector{T}
    function SimpleTimes(len::Integer, duration::Vector{T}) where {T}
        if len > length(duration)
            throw(
                ArgumentError(
                    "The length of `duration` cannot be less than the length `len` of `SimpleTimes`.",
                ),
            )
        else
            new{T}(len, duration)
        end
    end
end
function SimpleTimes(len::Integer, duration::Number)
    return SimpleTimes(len, fill(duration, len))
end
SimpleTimes(dur::Vector{T}) where {T<:Number} = SimpleTimes(length(dur), dur)

Base.eltype(::Type{SimpleTimes{T}}) where {T} = SimplePeriod{T}
Base.length(st::SimpleTimes) = st.len

_total_duration(st::SimpleTimes) = sum(st.duration)

"""
    struct SimplePeriod <: TimePeriod
A single time period returned when iterating through a SimpleTimes structure
"""
struct SimplePeriod{T<:Number} <: TimePeriod
    op::Integer
    duration::T
end

duration(t::SimplePeriod) = t.duration
multiple(t::SimplePeriod) = 1
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

function Base.last(ts::SimpleTimes)
    return SimplePeriod(ts.len, ts.duration[ts.len])
end

function Base.getindex(itr::SimpleTimes{T}, index) where {T}
    return SimplePeriod{T}(index, itr.duration[index])
end

function Base.eachindex(itr::SimpleTimes{T}) where {T}
    return Base.OneTo(itr.len)
end
