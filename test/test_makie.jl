using CairoMakie
using TimeStruct
using AlgebraOfGraphics

periods = SimpleTimes([1, 2, 4, 2, 3])
profile = OperationalProfile([2.0, 3.4, 3.5, 1.2, 0.6])

stairs(periods, profile; step = :post)
scatter!(periods, profile)
current_figure()

lines(periods, profile)

scens = OperationalScenarios(3, periods)
scen_prof = ScenarioProfile([profile, 0.8 * profile, 1.2 * profile])
profilechart(scens, scen_prof)

repr = RepresentativePeriods(2, [0.7, 0.3], [scens, scens])

two_level = TwoLevel(3, repr)
plot(two_level, scen_prof)

# Testing with AlgebraOfGraphics and rowtables
set_aog_theme!()
axis = (width = 225, height = 225)

tab = TimeStruct.rowtable(profile, periods)

plt = data(tab) * mapping(:t, :value) * visual(Stairs, step = :post)
draw(plt; axis = axis)

sc_tab = TimeStruct.rowtable(scen_prof, scens)
plt = data(sc_tab) * mapping(:t, :value, color = :opscen) * visual(Stairs, step = :post)
draw(plt; axis = axis)

plt = data(sc_tab) * mapping(:t, :value, col = :opscen) * visual(Stairs, step = :post)
draw(plt; axis = axis)

two_tab = TimeStruct.rowtable(scen_prof, two_level)
plt =
    data(two_tab) *
    mapping(:t, :value, row = :repr, col = :strat, color = :opscen) *
    visual(Stairs, step = :post)
draw(plt; axis = axis)

plt = data(two_tab) * mapping(:t, :value, layout = :strat) * visual(Stairs, step = :post)
draw(plt; axis = axis)

using JuMP, HiGHS

m = Model()
@variable(m, x[periods] >= 0)
@constraint(m, [t in periods], x[t] == profile[t])
@objective(m, Min, 0)

set_optimizer(m, HiGHS.Optimizer)
optimize!(m)

tab = Containers.rowtable(value, x)

set_aog_theme!()
axis = (width = 225, height = 225)

plt = data(tab) * mapping(:x1 => (t -> start_oper_time(t, periods)), :y)
draw(plt; axis = axis)

plt = data(tab) * mapping(:x1, :y)
draw(plt; axis = axis)
