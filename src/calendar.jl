
"""
    struct CalendarTimes <: TimeStructure

A time structure that iterates flexible calendar periods using calendar arithmetic.

## Example
```julia
ts = CalendarTimes(Dates.DateTime(2023, 1, 1), 12, Dates.Month(1))
ts_zoned = CalendarTimes(TimeZones.ZonedDateTime(Dates.DateTime(2023, 1, 1), tz"CET"), 52, Dates.Week(1))
```
"""
struct CalendarTimes{T<:Union{Dates.DateTime,TimeZones.ZonedDateTime}} <:
       TimeStructure{Float64}
    start_date::T
    length::Integer
    period::Dates.Period
end

"""
    CalendarTimes(start_date, end_date, period)

Construct a CalendarTimes with time periods of length `period` with the first period
starting at `start_date` and the last period ending at or before `end_date`

## Example
```jldoctest
julia> using TimeStruct, Dates

julia> ts = CalendarTimes(DateTime(2023, 1, 1), DateTime(2025, 1, 1), Month(3))
CalendarTimes{DateTime}(DateTime("2023-01-01T00:00:00"), 8, Month(3))
```
"""
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
    length,
    period::Dates.Period,
)
    return CalendarTimes(
        TimeZones.ZonedDateTime(start_date, zone),
        length,
        period,
    )
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

Base.eltype(::Type{CalendarTimes{T}}) where {T} = CalendarPeriod{T}
Base.length(ts::CalendarTimes) = ts.length

duration(ts::CalendarTimes) = sum(duration(t) for t in ts)

"""
    struct CalendarPeriod <: TimePeriod
A single time period returned when iterating through a CalendarTimes structure
with duration measured in hours (by default).
"""
struct CalendarPeriod{T} <: TimePeriod
    start_dt::T
    stop_dt::T
    op::Integer
end

function duration(t::CalendarPeriod; dfunc = Dates.Hour)
    return Dates.value(dfunc(t.stop_dt - t.start_dt))
end
isfirst(t::CalendarPeriod) = t.op == 1
multiple(t::CalendarPeriod) = 1
_oper(t::CalendarPeriod) = t.op
start_date(t::CalendarPeriod) = t.start_dt

Base.isless(t1::CalendarPeriod, t2::CalendarPeriod) = t1.op < t2.op
Base.show(io::IO, t::CalendarPeriod) = print(io, "ct$(t.op)")

function Base.iterate(ts::CalendarTimes)
    return CalendarPeriod(ts.start_date, ts.start_date + ts.period, 1),
    (1, ts.start_date)
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
