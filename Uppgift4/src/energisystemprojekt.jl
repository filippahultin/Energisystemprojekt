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

export runmodel, plotresults, plotGermany, annualProdPlot, plotTransmission

include("input_energisystemprojekt.jl")

function buildmodel(input)

    println("\nBuilding model...")
 
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    m = Model(Gurobi.Optimizer)

    REGION_PAIRS = [:SEDE, :SEDK, :DEDK]
    ORD_REGION_PAIRS = [:SEDE, :DESE, :SEDK, :DKSE, :DEDK, :DKDE]

    @variables m begin

        Supply[r in REGION, h in HOUR]                          >= 0            # supply of electricity in each region
        TransmissionElectricity[orp in ORD_REGION_PAIRS, h in HOUR] >= 0
        TransmissionCapacity[rp in REGION_PAIRS]                >= 0
        StorageBatteries[r in REGION, h in HOUR]                >= 0
        ElectricityBatteries[r in REGION, h in HOUR]            >= 0            # discharge of batteries
        AbsorbBatteries[r in REGION, h in HOUR]                 >= 0            # Charge of batteries
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
            sum(Emissions[r, h] for r in REGION, h in HOUR) <= 1.3877444928469244*10^8 * 0.1

        Emission[r in REGION, h in HOUR],
            # The others don't pollute!
            Emissions[r, h] >= Electricity[r, :Gas, h]*emis[:Gas]/eff[:Gas]

        # can not transmit more than capacity
        TransmissionCapSEDE[h in HOUR],
           TransmissionElectricity[:SEDE, h] <= TransmissionCapacity[:SEDE]

        TransmissionCapDESE[h in HOUR],
            TransmissionElectricity[:DESE, h] <= TransmissionCapacity[:SEDE]
        
        TransmissionCapSEDK[h in HOUR],
            TransmissionElectricity[:SEDK, h] <= TransmissionCapacity[:SEDK]
        
        TransmissionCapDKSE[h in HOUR],
            TransmissionElectricity[:DKSE, h] <= TransmissionCapacity[:SEDK]
        
        TransmissionCapDEDK[h in HOUR],
            TransmissionElectricity[:DEDK, h] <= TransmissionCapacity[:DEDK]
        
        TransmissionCapDKDE[h in HOUR],
            TransmissionElectricity[:DKDE, h] <= TransmissionCapacity[:DEDK]
        

        # Transmissioncost
        TransmissionCapacitySEDE,
            TransmissionCapacity[:SEDE] <= Capacity[:SE, :Transmission]

        TransmissionCapacityDEDK,
            TransmissionCapacity[:DEDK] <= Capacity[:DE, :Transmission]

        TransmissionCapacitySEDK,
            TransmissionCapacity[:SEDK] <= Capacity[:DK, :Transmission]

        # Supply constraint
        SupplySE[h in HOUR],
            Supply[:SE, h] <= sum(Electricity[:SE, p, h] for p in REAL_PLANTS) + eff[:Batteries]*ElectricityBatteries[:SE, h] + eff[:Transmission]*(TransmissionElectricity[:DESE, h] + TransmissionElectricity[:DKSE, h]) - (TransmissionElectricity[:SEDE, h] + TransmissionElectricity[:SEDK, h]) - AbsorbBatteries[:SE, h] #(StorageBatteries[:SE, h == length(HOUR) ? 1 : h+1] - StorageBatteries[:SE, h] + ElectricityBatteries[:SE, h])
        
        SupplyDE[h in HOUR],
            Supply[:DE, h] <= sum(Electricity[:DE, p, h] for p in REAL_PLANTS) + eff[:Batteries]*ElectricityBatteries[:DE, h] + eff[:Transmission]*(TransmissionElectricity[:SEDE, h] + TransmissionElectricity[:DKDE, h]) - (TransmissionElectricity[:DESE, h] + TransmissionElectricity[:DEDK, h]) - AbsorbBatteries[:DE, h] #(StorageBatteries[:DE, h == length(HOUR) ? 1 : h+1] - StorageBatteries[:DE, h] + ElectricityBatteries[:DE, h])

        SupplyDK[h in HOUR],
            Supply[:DK, h] <= sum(Electricity[:DK, p, h] for p in REAL_PLANTS) + eff[:Batteries]*ElectricityBatteries[:DK, h] + eff[:Transmission]*(TransmissionElectricity[:SEDK, h] + TransmissionElectricity[:DEDK, h]) - (TransmissionElectricity[:DKSE, h] + TransmissionElectricity[:DKDE, h]) - AbsorbBatteries[:DK, h] #(StorageBatteries[:DK, h == length(HOUR) ? 1 : h+1] - StorageBatteries[:DK, h] + ElectricityBatteries[:DK, h])

        Generation[r in REGION, p in REAL_PLANTS, h in HOUR],
            Electricity[r, p, h] <= Capacity[r, p]

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
            load[r, h] <= Supply[r, h]
        
        # Bound the water level
        WaterLevelMax[h in HOUR],
            StoredWater[h] <= 33*10^6 # 33 TWh, given i MWh
        
        # Constrain water levels
        WaterLevel[h in HOUR],
            StoredWater[h] <= StoredWater[h>1 ? h-1 : length(HOUR)] + inflow[h>1 ? h-1 : length(HOUR)] - Electricity[:SE, :Hydro, h>1 ? h-1 : length(HOUR)]
        
        # Constrain battery levels
        BatteryLevel[r in REGION, h in HOUR],
            StorageBatteries[r, h == length(HOUR) ? 1 : h+1] <= StorageBatteries[r, h] - ElectricityBatteries[r, h] + AbsorbBatteries[r, h]
        
        #BatteryLevelSE[h in HOUR],
        #    StorageBatteries[:SE, h == length(HOUR) ? 1 : h+1] <= StorageBatteries[:SE, h] - ElectricityBatteries[:SE, h] + (sum(Electricity[:SE, p, h] for p in REAL_PLANTS) + eff[:Batteries]*ElectricityBatteries[:SE, h] + eff[:Transmission]*(TransmissionElectricity[:DESE, h] + TransmissionElectricity[:DKSE, h]) - TransmissionElectricity[:SEDE, h] - TransmissionElectricity[:SEDK, h] - Supply[:SE, h])
        
        #BatteryLevelDE[h in HOUR],
        #    StorageBatteries[:DE, h == length(HOUR) ? 1 : h+1] <= StorageBatteries[:DE, h] - ElectricityBatteries[:DE, h] + (sum(Electricity[:DE, p, h] for p in REAL_PLANTS) + eff[:Batteries]*ElectricityBatteries[:DE, h] + eff[:Transmission]*(TransmissionElectricity[:SEDE, h] + TransmissionElectricity[:DKDE, h]) - TransmissionElectricity[:DESE, h] - TransmissionElectricity[:DEDK, h] - Supply[:DE, h])
        
        #BatteryLevelDK[h in HOUR],
        #    StorageBatteries[:DK, h == length(HOUR) ? 1 : h+1] <= StorageBatteries[:DK, h] - ElectricityBatteries[:DK, h] + (sum(Electricity[:DK, p, h] for p in REAL_PLANTS) + eff[:Batteries]*ElectricityBatteries[:DK, h] + eff[:Transmission]*(TransmissionElectricity[:SEDK, h] + TransmissionElectricity[:DEDK, h]) - TransmissionElectricity[:DKSE, h] - TransmissionElectricity[:DKDE, h] - Supply[:DK, h])
        
        # Ensure the system cost is what it claims to be
        Objective[r in REGION],
            Systemcost[r] >= sum(inv_cos[p].*disc[p].*Capacity[r, p] for p in PLANT) + sum(sum(Electricity[r, p, h] for h in HOUR).*(fu_cos[p]/eff[p] + run_cos[p]) for p in REAL_PLANTS) + sum(ElectricityBatteries[r, h].*run_cos[:Batteries] for h in HOUR)

    end #constraints


    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (;m, Capacity, Electricity, ElectricityBatteries, TransmissionElectricity, TransmissionCapacity, Emissions, StorageBatteries, input)

end # buildmodel

function runmodel() 

    input = read_input()

    model = buildmodel(input)

    @unpack m, Capacity, Electricity, ElectricityBatteries, TransmissionElectricity, TransmissionCapacity, Emissions, StorageBatteries, input = model   
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
    TransmissionElectricity_result = value.(TransmissionElectricity)
    TransmissionCapacity_result = value.(TransmissionCapacity)
    StorageBatteries_result = value.(StorageBatteries)

    println("Cost (M€): ", Cost_result)
    println("Capacity: ", Capacity_result)
    println("Emissions: ", sum(Emissions_result[r, h] for r in REGION, h in HOUR))
   
    return (;m, Capacity, Electricity_result, ElectricityBatteries_result, TransmissionElectricity_result, TransmissionCapacity_result, Emissions_result, Cost_result, StorageBatteries_result, status, Capacity_result, input)

end #runmodel

function plotGermany(results)
    @unpack m, Capacity, Electricity_result, ElectricityBatteries_result, TransmissionElectricity_result, status, Capacity_result, Cost_result, Emissions_result, input = results
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    relevant_load = [sum(load[:DE, h] for h in 147:651)]
    relevant_elec = [sum(Electricity_result[:DE, p, h] for h in 147:651) for p in [:Hydro, :Gas, :Wind, :Solar, :Nuclear]]
    #batteries_elec = [sum(ElectricityBatteries_result[:DE, h] for h in 147:651)]
    transmission_elec = [sum(eff[:Transmission]*(TransmissionElectricity_result[:SEDE, h] + TransmissionElectricity_result[:DKDE, h]) for h in 147:651)]
    types = ["Hydro", "Gas", "Wind", "Solar", "Nuclear", "Transmission", "Load"]

    println(Cost_result)
    println([sum(Emissions_result[r, h] for h in HOUR) for r in [:DE, :SE, :DK]])
    println(relevant_elec)
    #println(batteries_elec)
    println(transmission_elec)
    println(relevant_load)

    groupedbar(["Supply", "Supply", "Supply", "Supply", "Supply", "Supply", "Load"], [relevant_elec; transmission_elec; relevant_load],
    group=types, bar_position = :stack, title="E4: Germany supply/demand")
end

function plotresults(results)
    @unpack m, Capacity, status, Capacity_result, TransmissionCapacity_result, input = results
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    plantstr = repeat(["Hydro", "Gas", "Wind", "Solar", "Nuclear", "Batteries", "Transmission"], inner=3)
    ticklabel = repeat(["DE", "SE", "DK"], outer=7)
    big_cap = collect(Iterators.flatten(Capacity_result[:,[:Hydro, :Gas, :Wind, :Solar, :Nuclear, :Batteries]].data))
    transmission_cap = [(TransmissionCapacity_result[:SEDE]+TransmissionCapacity_result[:DEDK])/2, (TransmissionCapacity_result[:SEDE]+TransmissionCapacity_result[:SEDK])/2, (TransmissionCapacity_result[:SEDK]+TransmissionCapacity_result[:DEDK])/2]

    #groupedbar(["A", "A", "B", "B"], [4, 1, 2, 3], group=["x", "y", "x", "y"])
    
    println(plantstr)
    println(ticklabel)
    println(big_cap)
    println(transmission_cap)

    groupedbar(ticklabel, [big_cap; transmission_cap], group=plantstr,
            bar_position = :stack, title="E4: Total capacity")
end

function annualProdPlot(results)

    @unpack m, Electricity_result, ElectricityBatteries_result, TransmissionElectricity_result, StorageBatteries_result, input = results
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input

    plantstr = repeat(["Hydro", "Gas", "Wind", "Solar", "Nuclear", "Batteries", "Transmission"], inner=3)
    ticklabel = repeat(["DE", "SE", "DK"], outer=7)
    big_elec = collect(Iterators.flatten(sum(Electricity_result[[:DE, :SE, :DK],[:Hydro, :Gas, :Wind, :Solar, :Nuclear],h].data for h in HOUR)))
    batteries = [sum(ElectricityBatteries_result[:DE, h] for h in HOUR), sum(ElectricityBatteries_result[:SE, h] for h in HOUR), sum(ElectricityBatteries_result[:DK, h] for h in HOUR)]
    transmission = [sum(eff[:Transmission]*(TransmissionElectricity_result[:SEDE,h]+TransmissionElectricity_result[:DKDE,h]) for h in HOUR), sum(eff[:Transmission]*(TransmissionElectricity_result[:DESE,h]+TransmissionElectricity_result[:DKSE,h]) for h in HOUR), sum(eff[:Transmission]*(TransmissionElectricity_result[:SEDK,h]+TransmissionElectricity_result[:DEDK,h]) for h in HOUR)]

    println(StorageBatteries_result[:DE, 1:500])

    println(plantstr)
    println(ticklabel)
    println(big_elec)
    println(batteries)
    println(transmission)

    groupedbar(ticklabel, [big_elec; batteries; transmission], group=plantstr,
            bar_position = :stack, title="E4: Annual production")
end

function plotTransmission(results)
    @unpack m, Electricity_result, ElectricityBatteries_result, TransmissionElectricity_result, StorageBatteries_result, input = results
    @unpack REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf = input
    
    transm = ["SE", "DK", "DE", "DK", "DE", "SE"]
    ticklabel = ["DE", "DE", "SE", "SE", "DK", "DK"]

    transm_elec = [sum(eff[:Transmission]*TransmissionElectricity_result[:DESE, h] for h in HOUR), sum(eff[:Transmission]*TransmissionElectricity_result[:DEDK, h] for h in HOUR), sum(eff[:Transmission]*TransmissionElectricity_result[:SEDE, h] for h in HOUR), sum(eff[:Transmission]*TransmissionElectricity_result[:SEDK, h] for h in HOUR), sum(eff[:Transmission]*TransmissionElectricity_result[:DKDE, h] for h in HOUR), sum(eff[:Transmission]*TransmissionElectricity_result[:DKSE, h] for h in HOUR)]

    groupedbar(ticklabel, transm_elec, group=transm,
                title="E4: Annual production")

end

end # module

