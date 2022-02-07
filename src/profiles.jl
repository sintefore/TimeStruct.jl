abstract type TimeProfile{T} end


struct FixedProfile{T<:Number} <: TimeProfile{T}
    vals::T
end
FixedProfile(val::T, u::Unitful.Units) where {T} = FixedProfile(Unitful.Quantity(val, u))
Base.getindex(fp::FixedProfile, _::TimePeriod) = fp.vals

struct OperationalProfile{T<:Number} <: TimeProfile{T}
    vals::Array{T}
end
OperationalProfile(val::T, u::Unitful.Units) where {T} = OperationalProfile(Unitful.Quantity.(val, u))
Base.getindex(ofp::OperationalProfile, i::TimePeriod) = ofp.vals[mod(i.op - 1, length(ofp.vals)) + 1]

struct StrategicProfile{T<:Number} <: TimeProfile{T}
    vals::Array{T}
end
StrategicProfile(val::T, u::Unitful.Units) where {T} = StrategicProfile(Unitful.Quantity.(val, u))
Base.getindex(sfp::StrategicProfile, i::TimePeriod) = sfp.vals[isnothing(strat_per(i)) ? 1 : strat_per(i)]

struct DynamicProfile{T<:Number}<: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
Base.getindex(dp::DynamicProfile, i::TimePeriod) = dp.vals[isnothing(strat_per(i)) ? 1 : strat_per(i)][i]

struct ScenarioProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{<:TimeProfile{T}}
end
Base.getindex(sfp::ScenarioProfile, i::TimePeriod) = sfp.vals[isnothing(opscen(i)) ? 1 : opscen(i)][i]

function ScenarioProfile(vals::Vector{Vector{T}}) where T <: Number
    v = Vector{OperationalProfile{T}}()
    for scv in vals
        push!(v, OperationalProfile{T}(scv))
    end
    return ScenarioProfile(v)
end

struct StrategicStochasticProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{Vector{T}}
end
Base.getindex(ssp::StrategicStochasticProfile, i::TimePeriod) = ssp.vals[strat_per(i)][branch(i)]

struct DynamicStochasticProfile{T<:Number} <: TimeProfile{T}
    vals::Vector{ <:Vector{ <:TimeProfile{T}}}
end
Base.getindex(ssp::DynamicStochasticProfile, i::TimePeriod) = ssp.vals[strat_per(i)][branch(i)][i]



import Base:+,-,*,/
+(a::FixedProfile, b::Number) = FixedProfile(a.vals .+ b)
+(a::OperationalProfile, b::Number) = OperationalProfile(a.vals .+ b)
+(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .+ b)
+(a::StrategicProfile, b::Number) = StrategicProfile(a.vals .+ b)
+(a::Number, b::TimeProfile) = b + a
-(a::FixedProfile, b::Number) = FixedProfile(a.vals .- b)
-(a::OperationalProfile, b::Number) = OperationalProfile(a.vals .- b)
-(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .- b)
-(a::StrategicProfile, b::Number) = StrategicProfile(a.vals .- b)
*(a::FixedProfile, b::Number) = FixedProfile(a.vals .* b)
*(a::OperationalProfile, b::Number) = OperationalProfile(a.vals .* b)
*(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .* b)
*(a::StrategicProfile, b::Number) = StrategicProfile(a.vals .* b)
*(a::Number, b::TimeProfile) = b * a
/(a::FixedProfile, b::Number) = FixedProfile(a.vals ./ b)
/(a::OperationalProfile, b::Number) = OperationalProfile(a.vals ./ b)
/(a::DynamicProfile, b::Number) = DynamicProfile(a.vals ./ b)
/(a::StrategicProfile, b::Number) = StrategicProfile(a.vals ./ b)