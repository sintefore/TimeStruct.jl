abstract type TimeProfile{T} end

"""
    FixedProfile(val)

Time profile with a constant value for all time periods
"""
struct FixedProfile{T<:Duration} <: TimeProfile{T}
    val::T
end

function Base.getindex(
    fp::FixedProfile,
    _::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return fp.val
end

"""
    OperationalProfile
Time profile with a value that varies with the operational time
period.

If too few values are provided, the last provided value will be
repeated.
"""
struct OperationalProfile{T<:Duration} <: TimeProfile{T}
    vals::Vector{T}
end

function Base.getindex(
    op::OperationalProfile,
    i::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return op.vals[_oper(i) > length(op.vals) ? end : _oper(i)]
end

"""
    StrategicProfile(vals)

Time profile with a separate time profile for each strategic period.

If too few profiles are provided, the last given profile will be
repeated.
"""
struct StrategicProfile{T<:Duration,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end

"""
    StrategicProfile(vals::Vector{<:Number})

Create a strategic profile with a fixed value for each strategic
period.
"""
function StrategicProfile(vals::Vector{<:Number})
    return StrategicProfile([FixedProfile(v) for v in vals])
end

function _value_lookup(::HasStratIndex, sp::StrategicProfile, period)
    return sp.vals[_strat_per(period) > length(sp.vals) ? end :
                   _strat_per(period)][period]
end

function _value_lookup(::NoStratIndex, sp::StrategicProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a strategic profile",
    )
end

function Base.getindex(
    sp::StrategicProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return _value_lookup(StrategicIndexable(T), sp, period)
end

"""
    ScenarioProfile(vals)

Time profile with a separate time profile for each scenario
"""
struct ScenarioProfile{T<:Duration,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end

"""
    ScenarioProfile(vals::Vector{<:Number})

Create a scenario profile with a fixed value for each operational scenario.
"""
function ScenarioProfile(vals::Vector{<:Number})
    return ScenarioProfile([FixedProfile(v) for v in vals])
end

function _value_lookup(::HasScenarioIndex, sp::ScenarioProfile, period)
    return sp.vals[_opscen(period) > length(sp.vals) ? end : _opscen(period)][period]
end

function _value_lookup(::NoScenarioIndex, sp::ScenarioProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a scenario profile",
    )
end

function Base.getindex(
    sp::ScenarioProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return _value_lookup(ScenarioIndexable(T), sp, period)
end

"""
    RepresentativeProfile(vals)

Time profile with a separate time profile for each representative period.

If too few profiles are provided, the last given profile will be
repeated.
"""
struct RepresentativeProfile{T<:Duration,P<:TimeProfile{T}} <: TimeProfile{T}
    vals::Vector{P}
end

"""
    RepresentativeProfile(vals::Vector{<:Number})

Create a representative profile with a fixed value for each representative
period.
"""
function RepresentativeProfile(vals::Vector{<:Number})
    return RepresentativeProfile([FixedProfile(v) for v in vals])
end

function _value_lookup(::HasReprIndex, rp::RepresentativeProfile, period)
    return rp.vals[_rper(period) > length(rp.vals) ? end : _rper(period)][period]
end

function _value_lookup(::NoReprIndex, rp::RepresentativeProfile, period)
    return error(
        "Type $(typeof(period)) can not be used as index for a representative profile",
    )
end

function Base.getindex(
    rp::RepresentativeProfile,
    period::T,
) where {T<:Union{TimePeriod,TimeStructure}}
    return _value_lookup(RepresentativeIndexable(T), rp, period)
end

struct StrategicStochasticProfile{T} <: TimeProfile{T}
    vals::Vector{Vector{T}}
end
function Base.getindex(ssp::StrategicStochasticProfile, i::TimePeriod)
    return ssp.vals[_strat_per(i)][_branch(i)]
end

struct DynamicStochasticProfile{T<:Duration} <: TimeProfile{T}
    vals::Vector{<:Vector{<:TimeProfile{T}}}
end
function Base.getindex(ssp::DynamicStochasticProfile, i::TimePeriod)
    return ssp.vals[_strat_per(i)][_branch(i)][i]
end

Base.getindex(TP::TimeProfile, inds...) = [TP[i] for i in inds]

function Base.getindex(
    TP::TimeProfile,
    inds::Vector{T},
) where {T<:Union{TimePeriod,TimeStructure}}
    return [TP[i] for i in inds]
end

function Base.getindex(TP::TimeProfile, inds::Any)
    return error(
        "Type $(typeof(inds)) can not be used as index for a $(typeof(TP))",
    )
end

import Base: +, -, *, /
+(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val + b)
function +(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals .+ b)
end
function +(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals .+ b)
end
function +(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals .+ b)
end
function +(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals .+ b)
end
+(a::Number, b::TimeProfile{T}) where {T<:Number} = b + a
-(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val - b)
function -(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals .- b)
end
function -(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals .- b)
end
function -(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals .- b)
end
function -(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals .- b)
end

*(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val .* b)
function *(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals .* b)
end
function *(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals .* b)
end
function *(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals .* b)
end
function *(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals .* b)
end

*(a::Number, b::TimeProfile{T}) where {T<:Number} = b * a
/(a::FixedProfile{T}, b::Number) where {T<:Number} = FixedProfile(a.val / b)
function /(a::OperationalProfile{T}, b::Number) where {T<:Number}
    return OperationalProfile(a.vals ./ b)
end
function /(a::StrategicProfile{T}, b::Number) where {T<:Number}
    return StrategicProfile(a.vals ./ b)
end
function /(a::ScenarioProfile{T}, b::Number) where {T<:Number}
    return ScenarioProfile(a.vals ./ b)
end
function /(a::RepresentativeProfile{T}, b::Number) where {T<:Number}
    return RepresentativeProfile(a.vals ./ b)
end
