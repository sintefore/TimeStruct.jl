module TimeStructMakieExt
using Makie
using TimeStruct
import TimeStruct: profilechart, profilechart!

function Makie.convert_arguments(P::PointBased, periods, profile::TimeProfile)
    pts = [Point2(start_oper_time(t, periods), profile[t]) for t in periods]
    l = last(periods)
    push!(pts, Point2(end_oper_time(l, periods), profile[l]))
    return (pts,)
end

@recipe(ProfileChart) do scene
    Attributes(
        type = :stairs
    )
end

function Makie.plot!(sc::ProfileChart{<:Tuple{<:TimeStructure, <:TimeProfile}})
    periods = sc[1]
    profile = sc[2]

    for opscen in opscenarios(periods[])
        stairs!(sc, opscen, profile[]; step = :post)
    end

    return sc
end

function Makie.plot(periods::TwoLevel, profile::TimeProfile)
    fig = Figure()
    for (i, sp) in enumerate(strat_periods(periods))
        fig[1, i] = Axis(fig, title = "sp = $sp")
        for opscen in opscenarios(sp)
            stairs!(fig[1, i ], opscen, profile; step = :post)
        end
    end
    fig
end



end
