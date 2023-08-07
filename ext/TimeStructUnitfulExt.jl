module TimeStructUnitfulExt

using TimeStruct
using Unitful

function TimeStruct.SimpleTimes(dur::Vector{T}, u::Unitful.Units) where {T<:Real}
    return TimeStruct.SimpleTimes(length(dur), Unitful.Quantity.(dur, u))
end

function TimeStruct.TwoLevel(
    duration::Vector{<:Number},
    u::Unitful.Units,
    oper::TimeStructure{<:Unitful.Quantity{V,Unitful.𝐓}},
) where {V}
    return TimeStruct.TwoLevel(Unitful.Quantity.(duration, u), oper; op_per_strat = 1.0)
end

TimeStruct.stripunit(val::Unitful.Quantity) = Unitful.ustrip(Unitful.NoUnits, val)

function TimeStruct.FixedProfile(val::T, u::Unitful.Units) where {T}
    return TimeStruct.FixedProfile(Unitful.Quantity(val, u))
end

function TimeStruct.OperationalProfile(val::T, u::Unitful.Units) where {T}
    return TimeStruct.OperationalProfile(Unitful.Quantity.(val, u))
end

function TimeStruct._to_year(start::Unitful.Quantity{V,Unitful.𝐓}, disc) where {V}
    return Unitful.ustrip(Unitful.uconvert(Unitful.u"yr", start))
end

end