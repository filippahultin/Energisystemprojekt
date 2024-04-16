# I den här filen kan ni stoppa all inputdata. 
# Läs in datan ni fått som ligger på Canvas genom att använda paketen CSV och DataFrames

using CSV, DataFrames


r = 0.05  # discountrate = r
discount(lt) = r/(1 - 1/((1+r)^lt))

function dmap(f, d)
        newd = Dict()
        
        for (key, value) in d
                newd[key] = f(value)
        end

        return newd
end

function read_input()
println("\nReading Input Data...")
folder = dirname(@__FILE__)

filepath = joinpath(folder, "TimeSeries.csv")

#Sets
REGION = [:DE, :SE, :DK]
PLANT = [:Hydro, :Gas, :Wind, :Solar, :Batteries, :Transmission, :Nuclear] # Add all plants
REAL_PLANTS = [:Hydro, :Gas, :Wind, :Solar, :Nuclear]
HOUR = 1:8760

#Parameters
numregions = length(REGION)
numhours = length(HOUR)

timeseries = CSV.read(filepath, DataFrame)
wind_cf = AxisArray(ones(numregions, numhours), REGION, HOUR)
pv_cf = AxisArray(ones(numregions, numhours), REGION, HOUR)
load = AxisArray(zeros(numregions, numhours), REGION, HOUR)
inflow = AxisArray(zeros(numhours), HOUR)

inflow[:] = timeseries[:, "Hydro_inflow"]
 
    for r in REGION
        wind_cf[r, :]=timeseries[:, "Wind_"*"$r"]  
        pv_cf[r, :]=timeseries[:, "PV_"*"$r"]                                                     # 0-1, share of installed cap
        load[r, :]=timeseries[:, "Load_"*"$r"]                                                           # [MWh]
    end

myinf = 1e8
maxcaptable = [                                                             # GW
        # PLANT         DE             SE              DK       
        :Hydro          0              14              0       
        :Gas            myinf          myinf           myinf      
        :Wind           180            280             90  
        :Solar          460            75              60
        :Batteries      myinf          myinf           myinf    
        :Transmission   0              0               0        # change all to myinf later
        :Nuclear        0              0               0        # change all to myinf later
        ]

maxcap = AxisArray(maxcaptable[:,2:end]'.*1000, REGION, PLANT) # MW

lifet = Dict(                                                            # years
        # PLANT         LT      
        :Hydro        =>   80,   
        :Gas          =>   30,   
        :Wind         =>   25,
        :Solar        =>   25,
        :Batteries    =>   10,
        :Transmission =>   50,
        :Nuclear      =>  50
)

disc = dmap(discount, lifet) # AC/IC, how much to discount for each plant

inv_cos = Dict(          # euro/MW, was in euro/kW in table, so converted by multiplying
        # PLANT         IC      
        :Hydro        =>  0*1000,   
        :Gas          =>  550*1000,   
        :Wind         =>  1100*1000,
        :Solar        =>  600*1000,
        :Batteries    =>  150*1000,
        :Transmission =>  2500*1000,
        :Nuclear      =>  7700*1000
)

run_cos = Dict(
        # PLANT         RC      
        :Hydro        =>  0.1,   
        :Gas          =>  2,   
        :Wind         =>  0.1,
        :Solar        =>  0.1,
        :Batteries    =>  0.1,
        :Transmission =>   0,
        :Nuclear      =>  4
)

fu_cos = Dict(
        # PLANT         FC      
        :Hydro        =>  0,
        :Gas          =>  22,
        :Wind         =>  0,
        :Solar        =>  0,
        :Batteries    =>  0,
        :Transmission =>   0,
        :Nuclear      =>  3.2
)

eff = Dict(
        # PLANT         EF 
        :Hydro        =>  1,
        :Gas          =>  0.4,
        :Wind         =>  1,
        :Solar        =>  1,
        :Batteries    =>  0.9,
        :Transmission =>   0.98,
        :Nuclear      =>  0.4
)

emis = Dict(
        # PLANT         EM
        :Hydro        =>  0,
        :Gas          =>  0.202,
        :Wind         =>  0,
        :Solar        =>  0,
        :Batteries    =>  0,
        :Transmission =>  0,
        :Nuclear      =>  0
)

      return (; REGION, PLANT, REAL_PLANTS, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis, wind_cf, pv_cf)

end # read_input
