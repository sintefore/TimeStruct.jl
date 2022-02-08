# Durations can be provided as real numbers or as a Quantity with time dimension
Duration = Union{Real, Unitful.Quantity{V,Unitful.𝐓} where {V}}

"""
    abstract type TimeStructure{T}
Abstract type representing different time structures that 
consists of one or more time periods. The type 'T' gives
the data type used for the duration of the time periods.  
"""
abstract type TimeStructure{T <: Duration} end

"""
    abstract type TimePeriod{TimeStructure}
Abstract type used for a uniform interface for iterating through
time structures and indexing of time profiles.
"""
abstract type TimePeriod{TimeStructure} end

"""
    duration(t::TimePeriod) 
The duration of a time period in number of time units.
"""
duration(::TimePeriod) = error("duration() not implemented for time period")

"""
    isfirst(t::TimePeriod)
Returns true if the time period is the first in a sequence and has no previous time period
"""
isfirst(::TimePeriod) = error("isfirst() not implemented for time period")

