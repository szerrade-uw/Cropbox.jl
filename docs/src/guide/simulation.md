```@setup Cropbox
using Cropbox
```

!!! warning "Warning"
    This page is incomplete. Please check the Reference page for information regarding functions.

# Simulation

There are four different functions in Cropbox for model simulation. For information regarding syntax, please check the [reference](@ref Simulation1).
* [`instance()`](@ref instance)
* [`simulate()`](@ref simulate)
* [`evaluate()`](@ref evaluate)
* [`calibrate()`](@ref calibrate)

!!! tip "Tip"
    When running any of these functions, do not forget to include `Controller` as a mixin for the system.

## [`instance()`](@id instance)

The `instance()` function is the core of all simulative functions. To run any kind of simulation of a system, the system must first be instantiated. The `instance()` function simply makes an instance of a system with an initial condition specified by a configuration and additional options.

**Example**
```@example Cropbox
@system S(Controller) begin
    a ~ advance
end

s = instance(S)
```

After creating an instance of a system, we can simulate the system manually, using the `update!()` function (don't forget to assign a name to the instance).

```@example Cropbox
update!(s)
```
```@example Cropbox
update!(s)
```

## [`simulate()`](@id simulate)

`simulate()` runs a simulation by creating an instance of a specified system and updating it a specified number of times in order to generate an output in the form of a DataFrame.

**Example**
```@example Cropbox
@system S(Controller) begin
    a => 1 ~ preserve(parameter)
    b(a) => 2a ~ track
end

d = simulate(S; stop=5)
```

!!! tip "Tip"
    When using the `simulate()` function, it is recommended to always include an argument for the `stop` keyword unless you only want to see the initial calculations.

Don't forget that we can insert `Config` objects to 

## [`evaluate()`](@id evaluate)

The `evaluate()` function has two different [methods](https://docs.julialang.org/en/v1/manual/methods/) for comparing datasets.

```
evaluate(S, obs; <keyword arguments>) -> Number | Tuple
```

This method compares the output of simulation results for the given system `S` and observation data `obs` with a choice of evaluation metric.

**Example**
```@example Cropbox
@system S begin
end
```

```
evaluate(obs, est; <keyword arguments>) -> Number | Tuple
```

This method compares observation data `obs` and estimation data `est` with a choice of evaluation metric. This method compares two DataFrames, meaning that if you have an DataFrame output of a previous simulation, you do not need run another simulation.

**Example**
```@example Cropbox
@system S begin
end
```

## [`calibrate()`](@id calibrate)

```
calibrate(S, obs; <keyword arguments>) -> Config | OrderedDict
```

Cropbox includes a calibrate() function that helps determine parameter values based on a provided dataset. Internally, this process relies on [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl) for global optimization methods.

The `calibrate()` function returns a Config object that we can directly use in model simulations. 