mutable struct Discounter
    discount_rate
    timeunit_to_year
    ts::TimeStructure
end


function start(t::TimePeriod, ts::TimeStructure)
    if isfirst(t)
        return 0.0
    end

    return sum(duration(tt) for tt in ts if tt < t)
end

function start(t::OperationalPeriod, ts::TwoLevel)
    sp = t.sp
    if sp == 1
        return 0.0
    end
    
    return sum(duration(spp) for spp in strat_periods(ts) if spp.sp < sp)
end

function start(sp::StrategicPeriod, ts::TwoLevel)
    if sp.sp == 1
        return 0.0
    end
    
    return sum(duration(spp) for spp in strat_periods(ts) if spp < sp)
end    


function discount(disc::Discounter, t::TimePeriod; type = "start")

    start_year = disc.timeunit_to_year * start(t, disc.ts)
    duration_years = disc.timeunit_to_year * duration(t)

    multiplier = 1.0 

    if type == "start"
        multiplier= discount_start(disc.discount_rate, start_year)
    elseif type == "avg"
        multiplier = discount_avg(disc.discount_rate, start_year, duration_years)
    end
    
    return multiplier
end


function discount_avg(discount_rate, start_year, duration_years)
    if discount_rate > 0
        δ = 1 / (1 + discount_rate)
        m  = (δ^start_year - δ^(start_year + duration_years)) / log(1 + discount_rate) / duration_years
        return m
    else
        return 1.0
    end
end

function discount_start(discount_rate, start_year)
    δ = 1 / (1 + discount_rate)
    return δ^start_year
end

function objective_weight(p::SimplePeriod, disc::Discounter)
    return discount(disc, p) 
end

function objective_weight(op::OperationalPeriod, disc::Discounter)
    return probability(op) * discount(disc, op) * multiple(op, disc.ts)
end

function objective_weight(sp::StrategicPeriod, disc::Discounter)
    return discount(disc, sp)
end

