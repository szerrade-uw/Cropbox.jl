```@setup Cropbox
using Cropbox
using CSV
using DataFrames
using Dates
using TimeZones
```
# Lotka-Volterra

In this tutorial, we will create a model that simulates population dynamics between prey and predator using the Lotka-Volterra equations. The Lotka-Volterra equations are as follows.

```math
\begin{align}
\frac{dN}{dt} &= bN - aNP \\
\frac{dP}{dt} &= caNP - mP \\
\end{align}
```

Here is a list of variables used in the system.

| Symbol | Value | Units | Description |
| :---: | :---: | :---: | :--- |
| t | - | $\mathrm{yr}$ | Time unit used in the model |
| N | - | - | Prey population as number of individuals (state variable) |
| P | - | - | Predator population as number of individuals (state variable) |
| b | - | $\mathrm{yr^{-1}}$ | Per capital birth rate that defines the intrinsic growth rate of prey population |
| a | - | $\mathrm{yr^{-1}}$ | Attack rate or predation rate |
| c | - | - | Conversion efficiency of an eaten prey into new predator; predator's reproduction efficiency per prey consumed) |
| m | - | $\mathrm{yr^{-1}}$ | Mortality rate of predator population |

Let's begin by creating a system called LotkaVolterra

```
@system LotkaVolterra
```

Let us first start by declaring a time variable with a yearly unit so that we can use it as the x axis of out plot later on. Recall that context.clock.time simply keeps track of the progression of time.

```
@system LotkaVolterra begin
    t(context.clock.time) ~ track(u"yr")
end
```

While declaring `t` is not necessary to simulate the model, having a time variable in year-units will be convenient for plotting purposes later on.

Now we will declare the parameters in the equation as `preserve` variables.

```
@system LotkaVolterra begin
    t(context.clock.time) ~ track(u"yr")

    b: prey_birth_rate            ~ preserve(parameter, u"yr^-1")
    a: predation_rate             ~ preserve(parameter, u"yr^-1")
    c: predator_reproduction_rate ~ preserve(parameter)
    m: predator_mortality_rate    ~ preserve(parameter, u"yr^-1")
end
```

Now that we have the depending variables for the two equations, let us declare variables describing the prey and predator populations at any time t. The two equations above describe a rate of change for the two populations. Because we want to track the actual number of the two populations, we will declare the two populations as `accumulate` variables, which will give us the euler integration of the two population rates. Note that a variable can be used as its own depending variable.

```
@system LotkaVolterra begin
    t(context.clock.time) ~ track(u"yr")

    b: prey_birth_rate            ~ preserve(parameter, u"yr^-1")
    a: predation_rate             ~ preserve(parameter, u"yr^-1")
    c: predator_reproduction_rate ~ preserve(parameter)
    m: predator_mortality_rate    ~ preserve(parameter, u"yr^-1")

    N(N, P, b, a):    prey_population     =>     b*N - a*N*P ~ accumulate
    P(N, P, c, a, m): predator_population => c*a*N*P -   m*P ~ accumulate
end
```

By default, `accumulate` variables begin at a value of 0. In our model, that would mean that the two populations will stay at 0 for eternity. To address this, we have to define initial values representing the starting number of population for the prey and predator.

```@example Cropbox
@system LotkaVolterra(Controller) begin
    t(context.clock.time) ~ track(u"yr")

    b: prey_birth_rate            ~ preserve(parameter, u"yr^-1")
    a: predation_rate             ~ preserve(parameter, u"yr^-1")
    c: predator_reproduction_rate ~ preserve(parameter)
    m: predator_mortality_rate    ~ preserve(parameter, u"yr^-1")

    N0: prey_initial_population     ~ preserve(parameter)
    P0: predator_initial_population ~ preserve(parameter)

    N(N, P, b, a):    prey_population     =>     b*N - a*N*P ~ accumulate(init=N0)
    P(N, P, c, a, m): predator_population => c*a*N*P -   m*P ~ accumulate(init=P0)
end
```

**Configuration**

Now that the model is defined, we have to create a `Config` object to fill or adjust the parameters.

```@example Cropbox
lvc = @config (
    :Clock => (;
        step = 1u"d",
    ),
    :LotkaVolterra => (;
        b = 0.6,
        a = 0.02,
        c = 0.5,
        m = 0.5,
        N0 = 20,
        P0 = 30,
    ),
)
```

Now let us make a density-dependent version of the original Lotka-Volterra model.

For the density dependent version of the model, we will simply make a new system with the original LotkaVolterra model as a mixin. Afterwards, all we have to do is declare the relevant variables in the new system. Because the equation for `N` is different in the LotkaVolterraDD model, we will declare another `N` variable in the new system, but it will override the `N` variable that was in the original `LotkaVolterra` system.

```@example Cropbox
@system LotkaVolterraDD(LotkaVolterra, Controller) begin
    N(N, P, K, b, a): prey_population => begin
        b*N - b/K*N^2 - a*N*P
    end ~ accumulate(init = N0)
    
    K: carrying_capacity ~ preserve(parameter)
end
```

**Configuration**

Just like the new system, we can create a new configuration using adding onto the first configuration.

```@example Cropbox
lvddc = @config(lvc,
    :LotkaVolterraDD => (;
        K = 1000,
    ),
)
```