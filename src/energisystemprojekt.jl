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
# using energisystemprojekt

using JuMP, AxisArrays, Gurobi, UnPack

export runmodel

include("input_energisystemprojekt.jl")

function buildmodel(input)

    println("\nBuilding model...")
 
    @unpack REGION, PLANT, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis = input

    m = Model(Gurobi.Optimizer)

    @variables m begin

        Electricity[r in REGION, p in PLANT, h in HOUR]       >= 0        # MWh/h usage
        Capacity[r in REGION, p in PLANT]                     >= 0        # MW investment
        StoredWater[h in HOUR]                                >= 0        # MWh?

    end # variables


    # Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(Capacity[r, p], maxcap[r, p])
    end


    @constraints m begin
        Generation[r in REGION, p in PLANT, h in HOUR],
            Electricity[r, p, h] <= Capacity[r, p] # * capacity factor

        SystemCost[r in REGION],
            Systemcost[r] >= 0 # sum of all annualized costs
        
        # Need to produce as much as is consumed!
        Consumption[r in REGION, h in HOUR],
            load[r in REGION, h in HOUR] <= sum(Electricity[r in REGION, p in PLANT, h in HOUR] for p in PLANT)
        
        # Constrain water levels
        WaterLevel[h in HOUR[1:end-1]],
            StoredWater[h+1] <= StoredWater[h] + inflow[h] - Electricity[:SE, :Hydro, h]
        
        # Tail constraint
        TailLevel,
            StoredWater[1] <= StoredWater[length(HOUR)] + inflow[length(HOUR) - Electricity[:SE, :Hydro, length(HOUR)]]
        
    end #constraints


    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (;m, Capacity)

end # buildmodel

function runmodel() 

    input = read_input()

    model = buildmodel(input)

    @unpack m, Capacity = model   
    
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
   
    nothing

end #runmodel



end # module

