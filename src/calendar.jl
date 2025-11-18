"""
    struct CalendarTimes{T} <: TimeStructure{T}

    CalendarTimes(start_date, length, period)
    CalendarTimes(start_date, end_date, period)
    CalendarTimes(start_date, timezone, length, period)
    CalendarTimes(start_date, end_date, timezone, period)

A time structure that iterates flexible calendar periods using calendar arithmetic.
This time structure can be used at the lowest level of time structures similar
to [`SimpleTimes`](@ref).

## Example
```julia
ts = CalendarTimes(Dates.DateTime(2023, 1, 1), 12, Dates.Month(1))
ts_zoned = CalendarTimes(Dates.DateTime(2023, 1, 1), tz"Europe/Berlin", 52, Dates.Week(1))
```
"""
struct CalendarTimes{T<:Union{Dates.DateTime,TimeZones.ZonedDateTime}} <:
       TimeStructure{Float64}
    start_date::T
    length::Int
    period::Dates.Period
    total_duration::Float64
    function CalendarTimes(
        start_date::T,
        length::Integer,
        period::Dates.Period,
    ) where {T<:Union{Dates.DateTime,TimeZones.ZonedDateTime}}
        end_date = start_date + length * period
        total_duration = Dates.value(Dates.Hour(end_date - start_date))
        return new{T}(start_date, length, period, total_duration)
    end
end

function CalendarTimes(
    start_date::Union{Dates.Date,Dates.DateTime},
    end_date::Union{Dates.Date,Dates.DateTime},
    period::Dates.Period,
)
    length = 0
    dt = start_date
    while dt + period <= end_date
        dt += period
        length += 1
    end
    return CalendarTimes(Dates.DateTime(start_date), length, period)
end
function CalendarTimes(
    start_date::Union{Dates.Date,Dates.DateTime},
    zone::TimeZones.TimeZone,
    length::Integer,
    period::Dates.Period,
)
    return CalendarTimes(TimeZones.ZonedDateTime(start_date, zone), length, period)
end
function CalendarTimes(
    start_date::Union{Dates.Date,Dates.DateTime},
    end_date::Union{Dates.Date,Dates.DateTime},
    zone::TimeZones.TimeZone,
    period::Dates.Period,
)
    length = 1
    first = TimeZones.ZonedDateTime(start_date, zone)
    last = TimeZones.ZonedDateTime(end_date, zone)
    dt = first + period
    while dt < last
        dt += period
        length += 1
    end
    return CalendarTimes(first, length, period)
end

_total_duration(ts::CalendarTimes) = ts.total_duration

# Add basic functions of iterators
Base.length(ts::CalendarTimes) = ts.length
Base.eltype(::Type{CalendarTimes{T}}) where {T} = CalendarPeriod{T}
function Base.iterate(ts::CalendarTimes)
    return CalendarPeriod(ts.start_date, ts.start_date + ts.period, 1), (1, ts.start_date)
end
function Base.iterate(ts::CalendarTimes, state)
    state[1] == ts.length && return nothing
    start_time = state[2] + ts.period
    return CalendarPeriod(start_time, start_time + ts.period, state[1] + 1),
    (state[1] + 1, start_time)
end
function Base.getindex(ts::CalendarTimes, index)
    start_time = ts.start_date + (index - 1) * ts.period
    return CalendarPeriod(start_time, start_time + ts.period, index)
end
function Base.eachindex(ts::CalendarTimes)
    return Base.OneTo(ts.length)
end
function Base.last(ts::CalendarTimes)
    n = ts.length
    start = ts.start_date + (n - 1) * ts.period
    stop = start + ts.period
    return CalendarPeriod(start, stop, n)
end

"""
    struct CalendarPeriod{T} <: TimePeriod

Time period for a single operational period. It is created through iterating through a
[`CalendarTimes`](@ref) time structure with duration measured in hours (by default).
"""
struct CalendarPeriod{T} <: TimePeriod
    start_dt::T
    stop_dt::T
    op::Int
end

_oper(t::CalendarPeriod) = t.op

isfirst(t::CalendarPeriod) = t.op == 1
function duration(t::CalendarPeriod; dfunc = Dates.Hour)
    return Dates.value(dfunc(t.stop_dt - t.start_dt))
end
multiple(t::CalendarPeriod) = 1
start_date(t::CalendarPeriod) = t.start_dt

Base.show(io::IO, t::CalendarPeriod) = print(io, "ct$(t.op)")
Base.isless(t1::CalendarPeriod, t2::CalendarPeriod) = t1.op < t2.op
