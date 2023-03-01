# Using an Existing Cropbox Model

This tutorial will teach you how to use an existing Cropbox model. For this tutorial, we will be importing and utilizing a Cropbox model from a julia package called SimpleCrop.

## Installing a Cropbox Model

Often times, the Cropbox model that you want to use will be part of a Julia package.

If the package you want to install is under the official [Julia package registry](@https://github.com/JuliaRegistries/General), you can simply install the package using the following command.

```
using Pkg
Pkg.add("SimpleCrop")
```

You can also install any Julia package using a GitHub link.

```
using Pkg
Pkg.add("https://github.com/cropbox/SimpleCrop.jl")
```

## Importing a Cropbox Model

To start using a Julia package containing your desired model, you must first load the package into your environment.

This can be done by using this simple command.

```@example Cropbox
using SimpleCrop
```

## Inspecting the Model

