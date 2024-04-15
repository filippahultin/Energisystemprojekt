# Energy system project
To students in MVE347, Chalmers. 

You can find the project assignment here:
[MVE347_energisystemprojekt_2023.pdf](https://github.com/hannaekfalth/energisystemprojekt/files/11342976/MVE347_energisystemprojekt_2023.pdf)

This repo contains some code to get you started on the energy system project. 

## Installation
[Install and run Julia](https://julialang.org/downloads/). Then, in the julia REPL, enter the package manager mode by typing ] and copy/paste/type this at the prompt:

```dev https://github.com/hannaekfalth/energisystemprojekt.git```

A folder named energisystemprojekt will be created localy, containing the source code (src) etc. It is in these files you should work with your model. In package mode, write ```status``` to see where the energisystemprojekt i stored.

I also recomend that you use a package called [Revise](https://timholy.github.io/Revise.jl/stable/), to avoid having to restart julia every time you make a change in your code. In the package manager mode type:

```add Revise```

To solve the linear program you build, you will need to use a solver. There are several different options, both commercial and open source solvers. We recommend you to use Gurobi, which has a free license available for students. You download the software here: [Gurobi Download](https://www.gurobi.com/downloads/gurobi-optimizer-eula/). You need to register first. Note that you should click the box *Academic* when you register. You download the license here: [Gurobi licence](https://www.gurobi.com/downloads/end-user-license-agreement-academic/).

## Usage
Start by activating Revise by typing:

```using Revise```

Then, to use the energisystemprojekt package, type:

```using energisystemprojekt```

You can now use what is exported by the package (see line 9 in energisystemprojekt.jl). To run the model, type:

```runmodel()```

### Developing the model
To develop your model you write the code in .jl files in the src folder within the energisystemprojekt folder. And, if you are using Revise, the code changes will be activated immidiately. No need to restart julia or re-compile the energisystemprojekt package.  

