module TimeStructDataFramesExt

using DataFrames
using TimeStruct
const TS = TimeStruct
function TimeStruct.expand_dataframe!(df::DataFrame, periods)
    for col in eachcol(df)
        if eltype(col) <: TS.StratNode
            df[!, :strategic_period] = [TS._strat_per(t) for t in col]
            df[!, :branch] = [TS._branch(t) for t in col]
        elseif eltype(col) <: TS.OperationalPeriod
            df[!, :strategic_period] = [TS._strat_per(t) for t in col]
            df[!, :op_scenario] = [TS._opscen(t) for t in col]
            df[!, :oper_period] = [TS._oper(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_oper_time] = [start_oper_time(t, periods) for t in col]
            df[!, :end_oper_time] = [end_oper_time(t, periods) for t in col]
        elseif eltype(col) <: TS.SimplePeriod
            df[!, :oper_period] = [t.op for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = [start_oper_time(t, periods) for t in col]
            df[!, :end_time] = [end_oper_time(t, periods) for t in col]
        elseif eltype(col) <: TS.ScenarioPeriod
            df[!, :op_scenario] = [TS._opscen(t) for t in col]
            df[!, :oper_period] = [TS._oper(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = [start_oper_time(t, periods) for t in col]
            df[!, :end_time] = [end_oper_time(t, periods) for t in col]
        elseif eltype(col) <: TS.StrategicPeriod
            df[!, :strategic_period] = [TS._strat_per(t) for t in col]
            df[!, :duration] = [duration(t) for t in col]
            df[!, :start_time] = [start_time(t, periods) for t in col]
            df[!, :end_time] = [end_time(t, periods) for t in col]
        end
    end
end

end
