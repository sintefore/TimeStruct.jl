# Defintion of the main types for time profiles
abstract type TimeProfile{T} end

" Definition of the individual time profiles

FixedProfile:
	Fixed profile independent of strategic and operational period

OperationalFixedProfile:
    Fixed strategic profile with varying operational profiles
	
StrategicFixedProfile:
	Fixed operational profile with varying strategic profiles

DynamicProfile:
    Variations in both strategic and operational horizons
"

struct FixedProfile{T} <: TimeProfile{T}
    vals::T
end
Base.getindex(fp::FixedProfile, i) = fp.vals

struct OperationalFixedProfile{T} <: TimeProfile{T}
    vals::Array{T}
end
Base.getindex(ofp::OperationalFixedProfile, i::TimePeriod{UniformTwoLevel}) = ofp.vals[i.op]

struct StrategicFixedProfile{T} <: TimeProfile{T}
    vals::Array{T}
end
Base.getindex(sfp::StrategicFixedProfile, i::TimePeriod{UniformTwoLevel}) = sfp.vals[i.sp]
# Base.getindex(sfp::StrategicFixedProfile, i::OperationalPeriod) = sfp.vals[i.sp]
# Base.getindex(sfp::StrategicFixedProfile, i::StrategicPeriod) = sfp.vals[i.sp]

struct DynamicProfile{T} <: TimeProfile{T}
    vals::Array{T,2}
end
Base.getindex(dp::DynamicProfile, i::TimePeriod{UniformTwoLevel}) = dp.vals[i.sp, i.op]

import Base:+,-,*,/
+(a::FixedProfile, b::Number) = FixedProfile(a.vals .+ b)
+(a::OperationalFixedProfile, b::Number) = OperationalFixedProfile(a.vals .+ b)
+(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .+ b)
+(a::StrategicFixedProfile, b::Number) = StrategicFixedProfile(a.vals .+ b)
+(a::Number, b::TimeProfile) = b + a
-(a::FixedProfile, b::Number) = FixedProfile(a.vals .- b)
-(a::OperationalFixedProfile, b::Number) = OperationalFixedProfile(a.vals .- b)
-(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .- b)
-(a::StrategicFixedProfile, b::Number) = StrategicFixedProfile(a.vals .- b)
*(a::FixedProfile, b::Number) = FixedProfile(a.vals .* b)
*(a::OperationalFixedProfile, b::Number) = OperationalFixedProfile(a.vals .* b)
*(a::DynamicProfile, b::Number) = DynamicProfile(a.vals .* b)
*(a::StrategicFixedProfile, b::Number) = StrategicFixedProfile(a.vals .* b)
*(a::Number, b::TimeProfile) = b * a
/(a::FixedProfile, b::Number) = FixedProfile(a.vals ./ b)
/(a::OperationalFixedProfile, b::Number) = OperationalFixedProfile(a.vals ./ b)
/(a::DynamicProfile, b::Number) = DynamicProfile(a.vals ./ b)
/(a::StrategicFixedProfile, b::Number) = StrategicFixedProfile(a.vals ./ b)
