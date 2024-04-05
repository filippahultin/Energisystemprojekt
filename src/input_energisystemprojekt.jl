# I den här filen kan ni stoppa all inputdata. 
# Läs in datan ni fått som ligger på Canvas genom att använda paketen CSV och DataFrames

using CSV, DataFrames

discount(r, lt) = r/(1 - 1/((1+r)^lt))

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


discountrate=0.05


      return (; REGION, PLANT, HOUR, numregions, load, maxcap)

end # read_input
