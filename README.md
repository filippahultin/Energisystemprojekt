# Energysystem project
To students in MVE347, Chalmers.

Code to get you started on the energisystem project.

# Installation
Install and run Julia. Enter the package manager mode by typing ]. Then copy/paste/type this at the prompt:

```(@v1.7) pkg> dev https://github.com/hannaekfalth/energisystemprojekt.git```

A folder named energisystemprojekt will be created localy at the current working directory (type pwd() to see where that is) containing the sorce code etc.

I also recomend that you use a package called Revise, to avoid having to restart julia every time you make a change in your code. (See https://timholy.github.io/Revise.jl/stable/ for dokumentation). In the package manager mode type:

```(@v1.7) pkg> add Revise```

# Usage
Start by activating Revise by typing  
```julia> using Revise```

Then, to use the energisystemprojekt package, type:
```julia> using energisystemprojekt```

You can now use what is exported by the package (see line 9 in energisystemprojekt.jl). To run the model, type:
```julia> runmodel()```

# Developing the model
To 

# Stuck?
If you get stuck, dont hesitate to use the discussion forum in Canvas called "software issues", and We'll help you out. 
