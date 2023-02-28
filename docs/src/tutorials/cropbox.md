# Getting Started with Cropbox

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

To actually start using Cropbox, make sure to include the following command.

```
using Cropbox
```

## Making a System

This section will teach you how to make a `System`, one of the fundamental building blocks of making a model in Cropbox. 

In Cropbox, a system can be made by using a simple macro, `@system`.

```
using Cropbox
```

```
@system S
```

We have just created a system called `S`. In its current state, `S` is an empty system with no variables. Our next step is to define the variables that will represent our system.


### Defining variables


## Making a Configuration

## 



