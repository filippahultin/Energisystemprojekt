# I den här filen bygger ni modellen. Notera att det är skrivet som en modul, dvs ett paket. 
# Så när ni ska använda det, så skriver ni Using energisystemprojekt i er REPL, då får ni ut det ni
# exporterat. Se rad 9.

module energisystemprojekt

#import Pkg
#Pkg.add("Gurobi")
#Pkg.add("AxisArrays")
#Pkg.add("UnPack")
#Pkg.add("CSV")
#Pkg.add("DataFrames")
#Pkg.add("Revise")
#Pkg.add("StatsPlots")

using JuMP, AxisArrays, Gurobi, UnPack, StatsPlots, Revise

export runmodel, plotresults, plotGermany

include("input_energisystemprojekt.jl")

function buildmodel(input)

    println("\nBuilding model...")
 
    @unpack REGION, PLANT, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    m = Model(Gurobi.Optimizer)

    @variables m begin

        Electricity[r in REGION, p in PLANT, h in HOUR]       >= 0        # MWh/h usage
        Capacity[r in REGION, p in PLANT]                     >= 0        # MW investment
        StoredWater[h in HOUR]                                >= 0        # MWh
        Systemcost[r in REGION]                               >= 0        # €
        Emissions[r in REGION, h in HOUR]                     >= 0        # ton CO_2/MWh_fuel

    end # variables


     #Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(Capacity[r, p], maxcap[r, p])
    end


    @constraints m begin
        CO2cap,
            sum(Emissions[r, h] for r in REGION, h in HOUR) <= 1.3877444928469244*10^8 * 0.1

        Emission[r in REGION, h in HOUR],
            # The others don't pollute!
            Emissions[r, h] >= Electricity[r, :Gas, h]*emis[:Gas]/eff[:Gas]

        Generation[r in REGION, p in PLANT, h in HOUR],
            Electricity[r, p, h] <= Capacity[r, p] # * capacity factor

        SystemCost[r in REGION],
            Systemcost[r] >= 0 # sum of all annualized costs

        # Wind constraint
        Wind[r in REGION, h in HOUR],
            Electricity[r, :Wind, h] <= wind_cf[r, h]*Capacity[r, :Wind]

        # Solar constraint
        Solar[r in REGION, h in HOUR],
            Electricity[r, :Solar, h] <= pv_cf[r, h]*Capacity[r, :Solar]
        
        # Need to produce as much as is consumed!
        Consumption[r in REGION, h in HOUR],
            load[r, h] <= sum(Electricity[r, p, h] for p in PLANT)
        
        # Bound the water level
        WaterLevelMax[h in HOUR],
            StoredWater[h] <= 33*10^6 # 33 TWh, given i MWh
        
        # Constrain water levels
        WaterLevel[h in HOUR],
            StoredWater[h] <= StoredWater[h>1 ? h-1 : length(HOUR)] + inflow[h>1 ? h-1 : length(HOUR)] - Electricity[:SE, :Hydro, h>1 ? h-1 : length(HOUR)]
        
        # Ensure the system cost is what it claims to be
        Objective[r in REGION],
            Systemcost[r] >= sum(inv_cos[p].*disc[p].*Capacity[r, p] for p in PLANT) + sum(sum(Electricity[r, p, h] for h in HOUR).*(fu_cos[p]/eff[p] + run_cos[p]) for p in PLANT)

    end #constraints


    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (;m, Capacity, Electricity, Emissions, input)

end # buildmodel

function runmodel() 

    input = read_input()

    model = buildmodel(input)

    @unpack m, Capacity, Electricity, Emissions, input = model   
    @unpack REGION, PLANT, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input
    
    println("\nSolving model...")
    
    status = optimize!(m)
    

    if termination_status(m) == MOI.OPTIMAL
        println("\nSolve status: Optimal")   
    elseif termination_status(m) == MOI.TIME_LIMIT && has_values(m)
        println("\nSolve status: Reached the time-limit")
    else
        error("The model was not solved correctly.")
    end

    Cost_result = objective_value(m)/1000000 # M€
    Capacity_result = value.(Capacity)
    Electricity_result = value.(Electricity)
    Emissions_result = value.(Emissions)

    println("Cost (M€): ", Cost_result)
    println("Capacity: ", Capacity_result)
    println("Emissions: ", sum(Emissions_result[r, h] for r in REGION, h in HOUR))
   
    return (;m, Capacity, Electricity_result, Emissions_result, status, Capacity_result, input)

end #runmodel

function plotGermany(results)
    @unpack m, Capacity, Electricity_result, status, Capacity_result, input = results
    @unpack REGION, PLANT, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    relevant_load = sum(load[:DE, h] for h in 147:651)
    relevant_elec = [sum(Electricity_result[:DE, p, h] for h in 147:651) for p in [:Hydro, :Gas, :Wind, :Solar]]
    types = ["Hydro", "Gas", "Wind", "Solar", "Load"]

    groupedbar(["Production", "Production", "Production", "Production", "Load"], [relevant_elec; relevant_load], group=types, bar_position = :stack)
end

function plotresults(results)
    @unpack m, Capacity, status, Capacity_result, input = results
    @unpack REGION, PLANT, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    plantstr = repeat(["Hydro", "Gas", "Wind", "Solar"], outer=3)
    ticklabel = repeat(["DE", "SE", "DK"], inner=4)

    #groupedbar(["A", "A", "B", "B"], [4, 1, 2, 3], group=["x", "y", "x", "y"])
    
    groupedbar(ticklabel, collect(Iterators.flatten(Capacity_result[:,[:Hydro, :Gas, :Wind, :Solar]].data')), group=plantstr,
            bar_position = :stack)
    
end

end # module

