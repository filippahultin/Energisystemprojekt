# energisystemprojekt
 Model structure to students in MVE347, Chalmers
 
 
Two suggestions on how to use this model structure:

1. Copy the URL (you find it under the green button "Code" in the top right corner) and then write dev and then the URL in the package manager mode in the Julia REPL. Like this: (@v1.7) pkg> dev URL
   - You can then write "julia> using energisystemprojekt" to use this package, and you change/develop the code in the files which you find in your .julia folder on your computer.  
2. Generate a new package localy on you computer by writing (@v1.7) pkg> generate energisystemprojekt
   - Then copy the files in this repository and paste it in to the package you just created
   - Then add your package by writing (@v1.7) pkg> add energisystemprojekt
   - You can then write "julia> using energisystemprojekt" to use this package, and you change/develop the code in the files which you find where you generated the package.  
