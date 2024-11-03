using CairoMakie
using TimeStruct

periods = SimpleTimes([1, 2, 4, 2, 3])
profile = OperationalProfile([2.0, 3.4, 3.5, 1.2, 0.6])

stairs(periods, profile; step = :post)
scatter!(periods, profile)
current_figure()

lines(periods, profile)

scens = OperationalScenarios(3, periods)
scen_prof = ScenarioProfile([profile, 0.8 * profile, 1.2 * profile])
profilechart(scens, scen_prof)

two_level = TwoLevel(3, scens)
plot(two_level, scen_prof)
