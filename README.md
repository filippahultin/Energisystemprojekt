# Energy system project
To students in MVE347, Chalmers. Code to get you started on the energy system project. 

MVE347_Energy system project

You can find the project assignment here:
[MVE347_Energy system project](https://github.com/hannaekfalth/energisystemprojekt/files/8358315/Energisystemprojekt-MMM.pdf)

## Installation
[Install and run Julia](https://julialang.org/downloads/). Then, in the julia REPL, enter the package manager mode by typing ] and copy/paste/type this at the prompt:

```(@v1.7) pkg> dev https://github.com/hannaekfalth/energisystemprojekt.git```

A folder named energisystemprojekt will be created localy at the current working directory (type pwd() to see where that is) containing the sorce code etc.

I also recomend that you use a package called [Revise](https://timholy.github.io/Revise.jl/stable/), to avoid having to restart julia every time you make a change in your code. In the package manager mode type:

```(@v1.7) pkg> add Revise```

To solve the linear program you build, you will need to use a solver. There are several different options, both commercial and open source solvers. We recommend you to use Gurobi, which has a free license available for students. You download the software here: [Gurobi Download](https://www.gurobi.com/downloads/gurobi-optimizer-eula/). You need to register first. Note that you should click the box *Academic* when you register. You download the license here: [Gurobi licence](https://www.gurobi.com/downloads/end-user-license-agreement-academic/).

## Usage
Start by activating Revise by typing:

```julia> using Revise```

Then, to use the energisystemprojekt package, type:

```julia> using energisystemprojekt```

You can now use what is exported by the package (see line 9 in energisystemprojekt.jl). To run the model, type:

```julia> runmodel()```

### Developing the model
To develop your model you write the code in .jl files in the src folder within the energisystemprojekt folder. And, if you are using Revise, the code changes will be activated immidiately. No need to restart julia or re-compile the energisystemprojekt package.  

## Stuck?
If you get stuck, dont hesitate to use the discussion forum in Canvas called "software issues", and we'll help you out. 
