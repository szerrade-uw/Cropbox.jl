```@setup Cropbox
using Cropbox
using CSV
using DataFrames
using Dates
using TimeZones
```
# Lotka-Volterra Equations

In this tutorial, we will create a model that simulates population dynamics between prey and predator using the Lotka-Volterra equations. The Lotka-Volterra equations are as follows:

```math
\begin{align}
\frac{dN}{dt} &= bN - aNP \\
\frac{dP}{dt} &= caNP - mP \\
\end{align}
```
\

Here is a list of variables used in the system:

| Symbol | Value | Units | Description |
| :---: | :---: | :---: | :--- |
| t | - | $\mathrm{yr}$ | Time unit used in the model |
| N | - | - | Prey population as number of individuals (state variable) |
| P | - | - | Predator population as number of individuals (state variable) |
| b | - | $\mathrm{yr^{-1}}$ | Per capital birth rate that defines the intrinsic growth rate of prey population |
| a | - | $\mathrm{yr^{-1}}$ | Attack rate or predation rate |
| c | - | - | Conversion efficiency of an eaten prey into new predator; predator's reproduction efficiency per prey consumed) |
| m | - | $\mathrm{yr^{-1}}$ | Mortality rate of predator population |
\

Let us begin by creating a [system](@ref System) called `LotkaVolterra`. Since this is a system that we want to simulate later on, we must include [`Controller`](@ref Controller) as a [mixin](@ref Mixin).

```
@system LotkaVolterra(Controller)
```
\

We will first declare a time variable with a yearly unit, which we will use for plotting the model simulations later on. Recall that `context.clock.time` is a variable that keeps track of the progression of time in hourly units. We are simply declaring a variable to keep track of the time in years.

```
@system LotkaVolterra(Controller) begin
    t(context.clock.time) ~ track(u"yr")
end
```
\

Next, we will declare the parameters in the equations as `preserve` variables. `preserve` variables are variables that remain constant throughout a simulation.

```
@system LotkaVolterra(Controller) begin
    t(context.clock.time) ~ track(u"yr")

    b: prey_birth_rate            ~ preserve(parameter, u"yr^-1")
    a: predation_rate             ~ preserve(parameter, u"yr^-1")
    c: predator_reproduction_rate ~ preserve(parameter)
    m: predator_mortality_rate    ~ preserve(parameter, u"yr^-1")
end
```
\

Now let us declare the prey and predator populations as variables. The Lotka-Volterra equations describe rates of change for the two populations. As we want to track the actual number of the two populations, we will declare the two populations as `accumulate` variables, which are simply Euler integrations of the two population rates. Note that a variable can be used as its own depending variable.

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
\

By default, `accumulate` variables initialize at a value of zero. In our current model, that would result in two populations remaining at zero indefinitely. To address this, we will define the initial values for the two `accumulate` variables using the `init` tag. We can specify a particular value, or we can also create and reference new parameters representing the two initial populations. We will go with the latter option as it allows us to flexibly change the initial populations with a configuration.

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
\

**Configuration**

With the system now defined, we will create a `Config` object to fill or adjust the parameters.

First, we will change the `step` variable in the `Clock` system to `1u"d"`, which will make the system update at a daily interval. Recall that `Clock` is a system that is referenced in all systems by default. You can run the model with any timestep.

```@example Cropbox
lvc = @config (:Clock => step => 1u"d")
```
\

Next, we will configure the parameters in the `LotkaVolterra` system that we defined. Note that we can easily combine confgurations by providing multiple elements.

```@example Cropbox
lvc = @config (lvc,
    :LotkaVolterra => (;
        b = 0.6,
        a = 0.02,
        c = 0.5,
        m = 0.5,
        N0 = 20,
        P0 = 30
    )
)
```
\

**Visualization**

Let us visualize the `LotkaVolterra` system with the configuration that we just created, using the `visualize()` function. The `visualize()` function both runs a simulation and plots the resulting DataFrame.

```@example Cropbox
visualize(LotkaVolterra, :t, [:N, :P]; config = lvc, stop = 100u"yr", kind = :line)
```

## Density-Dependent Lotka-Volterra Equations

Now let's try to make a density-dependent version of the original Lotka-Volterra model which incorporates a new term in the prey population rate. The new variable *K* represents the carrying capacity of the prey population.

```math
\begin{align}
\frac{dN}{dt} &= bN-\frac{b}{K}N^2-aNP \\
\frac{dP}{dt} &= caNP-mP \\
\end{align}
```

We will call this new system `LotkaVolterraDD`.

```
@system LotkaVolterraDD(Controller)
```
\

Since we already defined the `LotkaVolterra` system, which already has most of the variables we require, we can use `LotkaVolterra` as a mixin for `LotkaVolterraDD`. This makes our task a lot simpler, as all that remains is to declare the variable `K` for carrying capacity and redeclare the variable `N` for prey population. The variable `N` in the new system will automatically overwrite the `N` from `LotkaVolterra`. 

```@example Cropbox
@system LotkaVolterraDD(LotkaVolterra, Controller) begin
    N(N, P, K, b, a): prey_population => begin
        b*N - b/K*N^2 - a*N*P
    end ~ accumulate(init = N0)
    
    K: carrying_capacity ~ preserve(parameter)
end
```
\

**Configuration**

Much like the new system, the new configuration can be created by reusing the old configuration. All we need to do is configure the new variable `K`.

```@example Cropbox
lvddc = @config(lvc, (:LotkaVolterraDD => K => 1000))
```
\

**Visualization**

Once again, let us visualize the system using the `visualize()` function.

```@example Cropbox
visualize(LotkaVolterraDD, :t, [:N, :P]; config = lvddc, stop = 100u"yr", kind = :line)
```

**Calibration**

