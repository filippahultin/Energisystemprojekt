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

export runmodel, plotresults

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

    end # variables


     #Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(Capacity[r, p], maxcap[r, p])
    end


    @constraints m begin
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

    return (;m, Capacity, input)

end # buildmodel

function runmodel() 

    input = read_input()

    model = buildmodel(input)

    @unpack m, Capacity, input = model   
    
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


    println("Cost (M€): ", Cost_result)
    println("Capacity: ", Capacity_result)
   
    return (;m, Capacity, status, Capacity_result, input)



end #runmodel

function plotresults(results)
    @unpack m, Capacity, status, Capacity_result, input = results
    @unpack REGION, PLANT, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    plantstr = repeat(["Hydro", "Gas", "Wind", "Solar", "Batteries", "Transmission", "Nuclears"], inner=3)
    ticklabel = repeat(["DE", "SE", "DK"], outer=3)
    groupedbar(ticklabel, Capacity_result[:,:], group=plantstr,
            bar_position = :stack)
           #bar_width=0.7,
           #xticks=(1:7, ticklabel))
          #label=plantstr)
          
end

end # module

