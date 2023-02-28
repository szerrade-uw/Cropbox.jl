```@setup Cropbox
using Cropbox
```

# [Getting Started with Cropbox](@id cropbox)

This tutorial will cover basic macros and functions of Cropbox.

## Installing Cropbox

[Cropbox.jl](https://github.com/cropbox/Cropbox.jl) is available through Julia package manager.

You can install Cropbox running the following command in the Julia REPL.

```julia
using Pkg
Pkg.add("Cropbox")
```

If you are using a prebuilt docker image with Cropbox included, you can skip this step.

## Package Loading

When using Cropbox, make sure to load the package into the environment by using the following command:

```
using Cropbox
```

## Creating a System

In Cropbox, a model is defined by a single system or a collection of systems.

A system can be made by using a simple Cropbox macro, `@system`.

```
@system S
```

We have just created a system called `S`. In its current state, `S` is an empty system with no variables. Our next step is to define the variables that will represent our system.

### Defining Variables

In Cropbox, 


## Configuring Parameters

## Simulation

## Visualization

## Evaluation



