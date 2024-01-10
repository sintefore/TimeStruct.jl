var documenterSearchIndex = {"docs":
[{"location":"manual/profiles/#Time-profiles","page":"Time profiles","title":"Time profiles","text":"","category":"section"},{"location":"manual/profiles/","page":"Time profiles","title":"Time profiles","text":"To provide data for different time structures there is a flexible system of different time profiles that can be indexed by time periods.","category":"page"},{"location":"manual/profiles/","page":"Time profiles","title":"Time profiles","text":"FixedProfile: Time profile with the same value for all time periods \nOperationalProfile: Time profile with values varying with operational time periods \nRepresentativeProfile: Holds a separate time profile for each representative period\nScenarioProfile: Holds a separate time profile for each operational scenario\nStrategicProfile : Holds a separate time profile for each strategic period","category":"page"},{"location":"manual/profiles/","page":"Time profiles","title":"Time profiles","text":"The following code example shows how these profile types can be combined in a flexible  manner to produce different overall profiles.","category":"page"},{"location":"manual/profiles/","page":"Time profiles","title":"Time profiles","text":"\nrep_periods = RepresentativePeriods(2, 365, [0.6, 0.4], [SimpleTimes(7,1), SimpleTimes(7,1)])\nperiods = TwoLevel(2, 365, rep_periods)\n\ncost = StrategicProfile(\n            [\n                RepresentativeProfile(\n                    [\n                        OperationalProfile([3, 3, 4, 3, 4, 6, 5]), \n                        FixedProfile(5)\n                    ]\n                ),\n                FixedProfile(7)\n            ]\n        )","category":"page"},{"location":"manual/profiles/","page":"Time profiles","title":"Time profiles","text":"Illustration of profile values for the various time periods as defined in the profile example (Image: Time profile values)","category":"page"},{"location":"manual/discount/#Discounting","page":"Discounting","title":"Discounting","text":"","category":"section"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"CurrentModule = TimeStruct","category":"page"},{"location":"reference/api/#Available-time-structures","page":"API reference","title":"Available time structures","text":"","category":"section"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"TimeStructure","category":"page"},{"location":"reference/api/#TimeStruct.TimeStructure","page":"API reference","title":"TimeStruct.TimeStructure","text":"abstract type TimeStructure{T}\n\nAbstract type representing different time structures that consists of one or more time periods. The type 'T' gives the data type used for the duration of the time periods.\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"SimpleTimes","category":"page"},{"location":"reference/api/#TimeStruct.SimpleTimes","page":"API reference","title":"TimeStruct.SimpleTimes","text":"struct SimpleTimes <: TimeStructure\n\nA simple time structure conisisting of consecutive time periods of varying duration\n\nExample\n\nuniform = SimpleTimes(5, 1.0) # 5 periods of equal length\nvarying = SimpleTimes([2, 2, 2, 4, 10])\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"CalendarTimes","category":"page"},{"location":"reference/api/#TimeStruct.CalendarTimes","page":"API reference","title":"TimeStruct.CalendarTimes","text":"struct CalendarTimes <: TimeStructure\n\nA time structure that iterates flexible calendar periods using calendar arithmetic.\n\nExample\n\nts = CalendarTimes(Dates.DateTime(2023, 1, 1), 12, Dates.Month(1))\nts_zoned = CalendarTimes(TimeZones.ZonedDateTime(Dates.DateTime(2023, 1, 1), tz\"CET\"), 52, Dates.Week(1))\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"RepresentativePeriods","category":"page"},{"location":"reference/api/#TimeStruct.RepresentativePeriods","page":"API reference","title":"TimeStruct.RepresentativePeriods","text":"RepresentativePeriods <: TimeStructure\n\nTime structure that allows a time period to be represented by one or more shorter representative time periods.\n\nThe representative periods are an ordered sequence of TimeStructures that are used for each representative period. In addition, each representative period has an associated share that specifies how much of the total duration that is attributed to it.\n\nExample\n\n# A year represented by two days with hourly resolution and relative shares of 0.7 and 0.3\nperiods = RepresentativePeriods(2, 8760, [0.7, 0.3], [SimpleTimes(24, 1), SimpleTimes(24,1)])\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"OperationalScenarios","category":"page"},{"location":"reference/api/#TimeStruct.OperationalScenarios","page":"API reference","title":"TimeStruct.OperationalScenarios","text":"struct OperationalScenarios <: TimeStructure\n\nTime structure that have multiple scenarios where each scenario has its own time structure and an associated probability. Note that all scenarios must use the same type for the duration.\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"TwoLevel","category":"page"},{"location":"reference/api/#TimeStruct.TwoLevel","page":"API reference","title":"TimeStruct.TwoLevel","text":"struct TwoLevel <: TimeStructure\n\nA time structure with two levels of time periods.\n\nOn the top level it has a sequence of strategic periods of varying duration. For each strategic period a separate time structure is used for operational decisions. Iterating the structure will go through all operational periods. It is possible to use different time units for the two levels by providing the number of operational time units per strategic time unit.\n\nExample\n\nperiods = TwoLevel(5, 8760, SimpleTimes(24, 1)) # 5 years with 24 hours of operations for each year\n\n\n\n\n\n","category":"type"},{"location":"reference/api/#Properties-of-time-periods","page":"API reference","title":"Properties of time periods","text":"","category":"section"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"duration","category":"page"},{"location":"reference/api/#TimeStruct.duration","page":"API reference","title":"TimeStruct.duration","text":"duration(t::TimePeriod)\n\nThe duration of a time period in number of operational time units.\n\n\n\n\n\n","category":"function"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"isfirst","category":"page"},{"location":"reference/api/#TimeStruct.isfirst","page":"API reference","title":"TimeStruct.isfirst","text":"isfirst(t::TimePeriod)\n\nReturns true if the time period is the first in a sequence and has no previous time period\n\n\n\n\n\n","category":"function"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"multiple","category":"page"},{"location":"reference/api/#TimeStruct.multiple","page":"API reference","title":"TimeStruct.multiple","text":"multiple(t::TimePeriod)\n\nReturns the number of times a time period should be counted for the whole time structure.\n\n\n\n\n\n","category":"function"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"probability","category":"page"},{"location":"reference/api/#TimeStruct.probability","page":"API reference","title":"TimeStruct.probability","text":"probability(t::TimePeriod)\n\nReturns the probability associated with the time period.\n\n\n\n\n\n","category":"function"},{"location":"reference/api/#Iterating-time-structures","page":"API reference","title":"Iterating time structures","text":"","category":"section"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"repr_periods","category":"page"},{"location":"reference/api/#TimeStruct.repr_periods","page":"API reference","title":"TimeStruct.repr_periods","text":"repr_periods(ts)\n\nIterator that iterates over representative periods in an RepresentativePeriods time structure.\n\n\n\n\n\nrepr_periods(sper)\n\nIterator that iterates over representative periods for a specific strategic period.\n\n\n\n\n\nrepr_periods(ts)\n\nReturns a collection of all representative periods for a TwoLevel time structure.\n\n\n\n\n\n","category":"function"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"opscenarios","category":"page"},{"location":"reference/api/#TimeStruct.opscenarios","page":"API reference","title":"TimeStruct.opscenarios","text":"opscenarios(ts)\n\nIterator that iterates over operational scenarios in an OperationalScenarios time structure.\n\n\n\n\n\nopscenarios(rep::RepresentativePeriod)\n\nIterator that iterates over operational scenarios in a RepresentativePeriod time structure.\n\n\n\n\n\nopscenarios(sp::StrategicPeriod)\n\nIterator that iterates over operational scenarios for a specific strategic period.\n\n\n\n\n\nopscenarios(sp::StrategicPeriod)\n\nReturns a collection of all operational scenarios for a TwoLevel time structure.\n\n\n\n\n\n","category":"function"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"strat_periods","category":"page"},{"location":"reference/api/#TimeStruct.strat_periods","page":"API reference","title":"TimeStruct.strat_periods","text":"strat_periods(ts::TwoLevel)\n\nIteration through the strategic periods of a 'TwoLevel' structure.\n\n\n\n\n\n","category":"function"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"withprev","category":"page"},{"location":"reference/api/#TimeStruct.withprev","page":"API reference","title":"TimeStruct.withprev","text":"withprev(iter)\n\nIterator wrapper that yields (prev, t) where prev is the previous time period or nothing for the first time period.\n\n\n\n\n\n","category":"function"},{"location":"reference/api/#Time-profiles","page":"API reference","title":"Time profiles","text":"","category":"section"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"FixedProfile","category":"page"},{"location":"reference/api/#TimeStruct.FixedProfile","page":"API reference","title":"TimeStruct.FixedProfile","text":"FixedProfile\n\nTime profile with a constant value for all time periods\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"OperationalProfile","category":"page"},{"location":"reference/api/#TimeStruct.OperationalProfile","page":"API reference","title":"TimeStruct.OperationalProfile","text":"OperationalProfile\n\nTime profile with a value that varies with the operational time period.\n\nIf too few values are provided, the last provided value will be repeated.\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"RepresentativeProfile","category":"page"},{"location":"reference/api/#TimeStruct.RepresentativeProfile","page":"API reference","title":"TimeStruct.RepresentativeProfile","text":"RepresentativeProfile\n\nTime profile with a separate time profile for each representative period.\n\nIf too few profiles are provided, the last given profile will be repeated.\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"ScenarioProfile","category":"page"},{"location":"reference/api/#TimeStruct.ScenarioProfile","page":"API reference","title":"TimeStruct.ScenarioProfile","text":"ScenarioProfile\n\nTime profile with a separate time profile for each scenario\n\n\n\n\n\n","category":"type"},{"location":"reference/api/","page":"API reference","title":"API reference","text":"StrategicProfile","category":"page"},{"location":"reference/api/#TimeStruct.StrategicProfile","page":"API reference","title":"TimeStruct.StrategicProfile","text":"StrategicProfile\n\nTime profile with a separate time profile for each strategic period.\n\nIf too few profiles are provided, the last given profile will be repeated.\n\n\n\n\n\n","category":"type"},{"location":"manual/iteration/#Iteration-utilities","page":"Iteration utilities","title":"Iteration utilities","text":"","category":"section"},{"location":"manual/iteration/#Basic-iteration","page":"Iteration utilities","title":"Basic iteration","text":"","category":"section"},{"location":"manual/iteration/","page":"Iteration utilities","title":"Iteration utilities","text":"All time structures are iterable over all operational time periods","category":"page"},{"location":"manual/iteration/#Iteration-with-previous","page":"Iteration utilities","title":"Iteration with previous","text":"","category":"section"},{"location":"manual/iteration/","page":"Iteration utilities","title":"Iteration utilities","text":"In many settings, e.g. tracking of storage, it is convenient to have access to the previous time period. By using the custom iterator withprev it is possible to return both the previous and  current time period as a tuple when iterating:","category":"page"},{"location":"manual/iteration/","page":"Iteration utilities","title":"Iteration utilities","text":"using TimeStruct\nperiods = SimpleTimes(5, 1);\ncollect(withprev(periods))","category":"page"},{"location":"manual/iteration/","page":"Iteration utilities","title":"Iteration utilities","text":"using JuMP\n\n","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"using TimeStruct","category":"page"},{"location":"manual/basic/#Operational-time-structures","page":"Operational time structures","title":"Operational time structures","text":"","category":"section"},{"location":"manual/basic/#SimpleTimes","page":"Operational time structures","title":"SimpleTimes","text":"","category":"section"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"The basic time structure is SimpleTimes which represents a continuous period of time divided into individual time periods of varying duration.  The length of each time period is obtained by the duration(t) function.","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"periods = SimpleTimes(5, [1, 1, 1, 5, 5]);\ndurations = [duration(t) for t in periods]","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"(Image: Illustration of SimpleTimes)","category":"page"},{"location":"manual/basic/#Calendar-based","page":"Operational time structures","title":"Calendar based","text":"","category":"section"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"For some applications it is required to relate the time periods to actual calendar dates.  This is supported by the time structure CalendarTimes that alllows for creation and iteration of a calendar based sequence of periods in combination with calendar arithmetic.","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"The following example shows the creation of a time structure with 12 months starting from the first of January 2024. The duration of each time period is given in hours by default, but it is possible to specify the time units to use by providing the period type to use:","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"using Dates\nyear = CalendarTimes(DateTime(2024, 1, 1), 12, Month(1));\nduration(first(year); dfunc = Dates.Day)","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"You can also make the time structure for a specific time zone as shown in the following  example with 3 days in the end of March with a transition to summer time on the second day:","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"using TimeZones\nperiods = CalendarTimes(DateTime(2023, 3, 25), tz\"CET\", 3, Day(1));\nduration.(periods)","category":"page"},{"location":"manual/basic/#Representative-periods","page":"Operational time structures","title":"Representative periods","text":"","category":"section"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"In some cases, a fine-scale representation for the operations of the infrastructure of the whole time horizon, is not feasible. A possible strategy is then to select one or more representative periods and use them to evaluate operational cost and feasibility. The time structure  RepresentativePeriods consists of an ordered sequence of representative periods that represents a longer period of time. Each  representative period covers a specified share of the whole time period. ","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"The following example shows an example with a year with daily resolution represented by two weeks with a share of 0.7 and 0.3 respectively. ","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"using JuMP, TimeStruct\n\nperiods = RepresentativePeriods(\n    2, \n    365, \n    [0.7, 0.3], \n    [SimpleTimes(7,1), SimpleTimes(7,1)]\n);","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"The time periods can be iterated both for the whole time structure and individually by each representative period using the repr_periods function. This is illustrated here  when setting up a JuMP model with a separate constraint for each representative period:","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"m = Model();\n@variable(m, prod[periods] >= 0);\n\nfor rp in repr_periods(periods)\n    @constraint(m, sum(prod[t] for t in rp) <= 10)\nend\n\n@constraint(m, sum(prod[t] * multiple(t) for t in periods) <= 1);","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"For each time period the multiple function returns how many times the given period should be counted when aggregating to the whole RepresentativePeriods structure. This will take into account both the duration and share of each representative period, thus we have that: ","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"sum(duration(t) * multiple(t) for t in periods)\nduration(periods)","category":"page"},{"location":"manual/basic/#Operational-scenarios","page":"Operational time structures","title":"Operational scenarios","text":"","category":"section"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"Operations often face uncertain operating conditions. In energy systems modeling, a typical example is the availability of wind and solar power.  One method for accounting for this uncertainty is to have multiple operational scenarios that are used to evaluate the cost and feasibility of  operations, where each scenario has a given probability of occurring.","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"The time structure OperationalScenarios represents an unordered collection of  operational scenarios where each scenario has a separate time structure and an associated  probability.","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"using TimeStruct, JuMP\nscenarios = OperationalScenarios(\n    3, \n    [SimpleTimes(5,1), SimpleTimes(7,2), SimpleTimes(10,1)], \n    [0.3, 0.2, 0.5]\n);","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"(Image: Illustration of OperationalScenarios)","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"Similar to representative periods, each period has a multiple that is defined relative to the maximum duration for all scenarios. In addition, each time period has a probabilityequal to the probability of its scenario. Thus we have that:","category":"page"},{"location":"manual/basic/","page":"Operational time structures","title":"Operational time structures","text":"sum(duration(t) * probability(t) * multiple(t) for t in scenarios) \nduration(scenarios)","category":"page"},{"location":"#Introduction","page":"Introduction","title":"Introduction","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Welcome to the documentation of the TimeStruct package!","category":"page"},{"location":"#What-is-TimeStruct","page":"Introduction","title":"What is TimeStruct","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"TimeStruct is a Julia package that supports the efficient development of optimization models with multi-horizon time modelling. The package is designed to be used in combination with the JuMP package for optimization modeling in Julia.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"The main concept is a TimeStructure which is an abstract type that enables iteration over a sequence of time periods. These time periods can serve as indices for optimization variables and can also facilitate the lookup of associated data values from time-varying profiles. By having a well-defined interface that is supported by all time structures, optimization models that are valid for arbitrary time structures can be written. The following example shows how a small optimization model can be set up in a function that accepts a general time structure and cost profile.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"    using JuMP, TimeStruct\n\n    function(periods::TimeStructure, cost::TimeProfile)\n        m = Model()\n        @variable(m, x[periods] >= 0)\n        @constraint(m, sum(x[t] for t in periods) >= 10)\n        @objective(m, Min, sum(cost[t] * x[t] for t in periods))\n    end","category":"page"},{"location":"#How-to-get-started","page":"Introduction","title":"How to get started","text":"","category":"section"},{"location":"manual/multi/#Multi-horizon-time-structures","page":"Multi-horizon","title":"Multi-horizon time structures","text":"","category":"section"},{"location":"manual/multi/#TwoLevel","page":"Multi-horizon","title":"TwoLevel","text":"","category":"section"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"As described earlier, the main motivation for the TimeStruct package is to support multi-horizon optimization models. The time structure TwoLevel allows for a two level  approach, combining an ordered sequence of strategic periods with given duration and an associated operational time structure. ","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"using TimeStruct\nperiods = TwoLevel(\n    [SimpleTimes(5,1), SimpleTimes(5,1), SimpleTimes(5,1)], \n);","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"(Image: Illustration of TwoLevel)","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"The following example shows a typical usage of a TwoLevel strucure with investment  decisions on a strategic level and operational decision variables. It is possible to iterate  through each strategic period using the strat_periodsfunction. ","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"using JuMP\nm = Model();\n@variable(m, invest[strat_periods(periods)] >= 0);\n@variable(m, prod[periods] >= 0);\n\nfor sp in strat_periods(periods)\n    @constraint(m, sum(prod[t] for t in sp) <= invest[sp])\nend","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"It is also possible to combine a TwoLevel time structure with more complex operational structures like RepresentativePeriods and OperationalScenarios, alone or in combination, as shown in the following example and illustrated the figure below.","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"oper = SimpleTimes(5,1);\nscen = OperationalScenarios([oper, oper, oper], [0.4, 0.5, 0.1]);\nrepr = RepresentativePeriods(2, 5, [0.5, 0.5], [oper, oper]);\nrepr_scen = RepresentativePeriods(2, 5, [0.5, 0.5], [scen, scen]);\n\nperiods = TwoLevel([scen, repr, repr_scen]);        ","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"(Image: Complex TwoLevel)","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"In the above examples, the duration of the operational time structures have been equal to the duration of the strategic periods, but this is not required. If the duration of the operational time structure is shorter than the strategic period, this will be accounted for with the multiple function.","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"It is also sometimes convenient to use a different time unit for the strategic periods than the operational time periods. This is controlled by the op_per_strat field of the TwoLevel structure that holds the number of operational periods per strategic period.","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"A typical use case is an investment problem where one uses years to measure duration at the strategic level and hours/days on the operational level. Below is an example with 3 strategic periods of duration 5, 5, and 10 years  respectively, while the operational time structure is given by  representative periods with duration in days. The op_per_strat is then set to 365.","category":"page"},{"location":"manual/multi/","page":"Multi-horizon","title":"Multi-horizon","text":"week = SimpleTimes(7,1);\nrepr = RepresentativePeriods(2, 365, [0.6, 0.4], [week, week]);\nperiods = TwoLevel(3, [5, 5, 10], [repr, repr, repr], 365.0);","category":"page"},{"location":"manual/multi/#TwoLevelTree","page":"Multi-horizon","title":"TwoLevelTree","text":"","category":"section"}]
}
