abstract type TimeProfile{T} end

"""
    FixedProfile
Time profile with a constant value for all time periods
"""
struct FixedProfile{T} <: TimeProfile{T}
    val::T
end
function FixedProfile(val::T, u::Unitful.Units) where {T}
    return FixedProfile(Unitful.Quantity(val, u))
end
Base.getindex(fp::FixedProfile, _::TimePeriod) = fp.val

"""
    OperationalProfile
Time profile with a value that varies with the operational time
period.

If too few values are provided, the last provided value will be
repeated. 
"""
struct OperationalProfile{T} <: TimeProfile{T}
    vals::Array{T}
end
function OperationalProfile(val::T, u::Unitful.Units) where {T}
    return OperationalProfile(Unitful.Quantity.(val, u))
end
function Base.getindex(op::OperationalProfile, i::TimePeriod)
    return op.vals[_oper(i) > length(op.vals) ? end : _oper(i)]
end

"""
    StrategicProfile
Time profile with a separate time profile for each strategic period.

If too few profiles are provided, the last given profile will be
repeated.    
"""
struct StrategicProfile{T} <: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
function Base.getindex(sp::StrategicProfile, i::TimePeriod)
    return sp.vals[_strat_per(i) > length(sp.vals) ? end : _strat_per(i)][i]
end

function StrategicProfile(vals::Vector{T}) where {T}
    return StrategicProfile{T}([FixedProfile{T}(v) for v in vals])
end

""" 
    ScenarioProfile
Time profile with a separate time profile for each scenario
"""
struct ScenarioProfile{T} <: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
function Base.getindex(scp::ScenarioProfile, i::TimePeriod)
    return scp.vals[_opscen(i) > length(scp.vals) ? end : _opscen(i)][i]
end

function ScenarioProfile(vals::Vector{Vector{T}}) where {T}
    v = Vector{OperationalProfile{T}}()
    for scv in vals
        push!(v, OperationalProfile{T}(scv))
    end
    return ScenarioProfile(v)
end

struct StrategicStochasticProfile{T} <: TimeProfile{T}
    vals::Vector{Vector{T}}
end
function Base.getindex(ssp::StrategicStochasticProfile, i::TimePeriod)
    return ssp.vals[_strat_per(i)][_branch(i)]
end

struct DynamicStochasticProfile{T} <: TimeProfile{T}
    vals::Vector{<:Vector{<:TimeProfile{T}}}
end
function Base.getindex(ssp::DynamicStochasticProfile, i::TimePeriod)
    return ssp.vals[_strat_per(i)][_branch(i)][i]
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
