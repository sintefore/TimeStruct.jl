module TimeStructUnitfulExt

using Unitful
using TimeStruct

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

function TimeStruct._to_year(
    start::Unitful.Quantity{V,Unitful.𝐓},
    timeunit_to_year,
) where {V}
    return Unitful.ustrip(Unitful.uconvert(Unitful.u"yr", start))
end

function TimeStruct.FixedProfile(val::Real, u::Unitful.Units)
    return TimeStruct.FixedProfile(Unitful.Quantity.(val, u))
end

function TimeStruct.OperationalProfile(vals::Vector{<:Real}, u::Unitful.Units)
    return TimeStruct.OperationalProfile(Unitful.Quantity.(vals, u))
end

end
