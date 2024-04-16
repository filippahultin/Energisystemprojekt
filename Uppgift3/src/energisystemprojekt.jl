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
 
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    m = Model(Gurobi.Optimizer)

    @variables m begin

        StorageBatteries[r in REGION, h in HOUR]                >= 0
        ElectricityBatteries[r in REGION, h in HOUR]            >= 0            # discharge of batteries
        Electricity[r in REGION, p in REAL_PLANTS, h in HOUR]       >= 0        # MWh/h usage
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
            sum(Emissions[r, h] for r in REGION, h in HOUR) <= 5.5509779713876806*10^7 * 0.1

        Emission[r in REGION, h in HOUR],
            # The others don't pollute!
            Emissions[r, h] >= Electricity[r, :Gas, h]*emis[:Gas]

        Generation[r in REGION, p in REAL_PLANTS, h in HOUR],
            Electricity[r, p, h] <= Capacity[r, p] # * capacity factor

        BatteryStorage[r in REGION, h in HOUR],
            StorageBatteries[r, h] <= Capacity[r, :Batteries]

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
            load[r, h] <= sum(Electricity[r, p, h] for p in REAL_PLANTS) + ElectricityBatteries[r, h] * 0.9 # loss of battery storage
        
        # Constrain water levels
        WaterLevel[h in HOUR],
            StoredWater[h] <= StoredWater[h>1 ? h-1 : length(HOUR)] + inflow[h>1 ? h-1 : length(HOUR)] - Electricity[:SE, :Hydro, h>1 ? h-1 : length(HOUR)]
        
        # Constrain battery levels
        BatteryLevel[r in REGION, h in HOUR],
            StorageBatteries[r, h] <= StorageBatteries[r, h>1 ? h-1 : length(HOUR)] + (sum(Electricity[r, p, h>1 ? h-1 : length(HOUR)] for p in REAL_PLANTS) - load[r, h>1 ? h-1 : length(HOUR)]) - ElectricityBatteries[r, h>1 ? h-1 : length(HOUR)]
        
        # Ensure the system cost is what it claims to be
        Objective[r in REGION],
            Systemcost[r] >= sum(inv_cos[p].*disc[p].*Capacity[r, p] for p in PLANT) + sum(sum(Electricity[r, p, h] for h in HOUR).*(fu_cos[p]/eff[p] + run_cos[p]) for p in REAL_PLANTS) + sum(ElectricityBatteries[r, h].*run_cos[:Batteries] for h in HOUR)

    end #constraints


    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (;m, Capacity, Electricity, ElectricityBatteries, Emissions, input)

end # buildmodel

function runmodel() 

    input = read_input()

    model = buildmodel(input)

    @unpack m, Capacity, Electricity, ElectricityBatteries Emissions, input = model   
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input
    
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
    ElectricityBatteries_result = value.(ElectricityBatteries)
    Emissions_result = value.(Emissions)

    println("Cost (M€): ", Cost_result)
    println("Capacity: ", Capacity_result)
    println("Emissions: ", sum(Emissions_result[r, h] for r in REGION, h in HOUR))
   
    return (;m, Capacity, Electricity_result, ElectricityBatteries_result, Emissions_result, status, Capacity_result, input)

end #runmodel

function plotGermany(results)
    @unpack m, Capacity, Electricity_result, ElectricityBatteries_result, status, Capacity_result, input = results
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    relevant_load = sum(load[:DE, h] for h in 147:651)
    relevant_elec = [sum(Electricity_result[:DE, p, h] for h in 147:651) for p in [:Hydro, :Gas, :Wind, :Solar]]
    batteries_elec = [sum(ElectricityBatteries_result[:DE, h] for h in 147:651)]
    types = ["Hydro", "Gas", "Wind", "Solar", "Batteries", "Load"]

    groupedbar(["Production", "Production", "Production", "Production", "Production", "Load"], [relevant_elec; batteries_elec; relevant_load], group=types, bar_position = :stack)
end

function plotresults(results)
    @unpack m, Capacity, status, Capacity_result, input = results
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    plantstr = repeat(["Hydro", "Gas", "Wind", "Solar", "Batteries"], outer=3)
    ticklabel = repeat(["DE", "SE", "DK"], inner=5)

    #groupedbar(["A", "A", "B", "B"], [4, 1, 2, 3], group=["x", "y", "x", "y"])
    
    groupedbar(ticklabel, collect(Iterators.flatten(Capacity_result[:,[:Hydro, :Gas, :Wind, :Solar, :Batteries]].data')), group=plantstr,
            bar_position = :stack)
    
end

end # module

