# I den här filen kan ni stoppa all inputdata. 
# Läs in datan ni fått som ligger på Canvas genom att använda paketen CSV och DataFrames

using CSV, DataFrames


r = 0.05  # discountrate = r
discount(lt) = r/(1 - 1/((1+r)^lt))

function read_input()
println("\nReading Input Data...")
folder = dirname(@__FILE__)

filepath = joinpath(folder, "TimeSeries.csv")

#Sets
REGION = [:DE, :SE, :DK]
PLANT = [:Hydro, :Gas, :Wind, :Solar, :Batteries, :Transmission, :Nuclear] # Add all plants
HOUR = 1:8760

#Parameters
numregions = length(REGION)
numhours = length(HOUR)

timeseries = CSV.read(filepath, DataFrame)
wind_cf = AxisArray(ones(numregions, numhours), REGION, HOUR)
load = AxisArray(zeros(numregions, numhours), REGION, HOUR)
inflow = AxisArray(zeros(numhours), HOUR)

inflow[:] = timeseries[:, "Hydro_inflow"]
 
    for r in REGION
        wind_cf[r, :]=timeseries[:, "Wind_"*"$r"]                                                        # 0-1, share of installed cap
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
        :Transmission   myinf          myinf           myinf
        :Nuclear        myinf          myinf           myinf
        ]

maxcap = AxisArray(maxcaptable[:,2:end]'.*1000, REGION, PLANT) # MW

lifet = Dict(                                                            # years
        # PLANT         LT      
        :Hydro        =>   80   
        :Gas          =>   30   
        :Wind         =>   25
        :Solar        =>   25
        :Batteries    =>   10
        :Transmission =>   50
        :Nuclear      =>  50
)

disc = map(discount, lifet) # AC/IC, how much to discount for each plant

inv_cos = Dict(                                                             # MW
        # PLANT         IC      
        :Hydro        =>  0   
        :Gas          =>  550   
        :Wind         =>  1100
        :Solar        =>  600
        :Batteries    =>  150
        :Transmission =>  2500
        :Nuclear      =>  7700
)

run_cos = Dict(                                                             # MW
        # PLANT         RC      
        :Hydro        =>  0.1   
        :Gas          =>  2   
        :Wind         =>  0.1
        :Solar        =>  0.1
        :Batteries    =>  0.1
        :Transmission =>   0
        :Nuclear      =>  4
)

fu_cos = Dict(                                                             # MW
        # PLANT         FC      
        :Hydro        =>  0
        :Gas          =>  22
        :Wind         =>  0
        :Solar        =>  0
        :Batteries    =>  0
        :Transmission =>   0
        :Nuclear      =>  3.2
)

eff = Dict(                                                             # MW
        # PLANT         EF 
        :Hydro        =>  1
        :Gas          =>  0.4
        :Wind         =>  1
        :Solar        =>  1
        :Batteries    =>  0.9
        :Transmission =>   0.98
        :Nuclear      =>  0.4
)

emis = Dict(                                                             # MW
        # PLANT         EM
        :Hydro        =>  0
        :Gas          =>  0.202
        :Wind         =>  0
        :Solar        =>  0
        :Batteries    =>  0
        :Transmission =>  0
        :Nuclear      =>  0
)

      return (; REGION, PLANT, HOUR, numregions, load, maxcap, inflow, disc, inv_cos, run_cos, fu_cos, eff, emis)

end # read_input
