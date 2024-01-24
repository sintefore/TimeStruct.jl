# Discounting

For multi-year investment optimization models it is common pratice to use an
objective that is discounted to get the net present value of the investment.
Since investment decisions usually are done on a strategic level, discount 
factors are also calculated based on strategic periods. 

The discount factor for a time period `t` is found by the [`discount`](@ref)
function. There are two strategies for calculating the discount factor,
either all discounting is calculated based on the start of the strategic period
or it is based on finding an approximation of the average value over the 
strategic period. The following example shows how these two types will
differ for a planning period of 50 years, consisting of 5 periods of 
10 years:
```@repl ts
using TimeStruct
ts = TwoLevel(5, 10, SimpleTimes(1,1));
df_start = [discount(t, ts, 0.05; type = "start") for t in ts]
df_avg = [discount(t, ts, 0.05; type = "avg") for t in ts]
```
While it is often normal to assume investments at the start of each 
strategic period, it can be more correct to average the discount factor
for operational costs that are accrued throughout the strategic period.

To help setting up the objective function in a typical optimization problem,
there is a utility function [`objective_weight`](@ref) that returns
the weight to give a time period in the objective, considering both
discount factor, probability and possible multiplicity. 
