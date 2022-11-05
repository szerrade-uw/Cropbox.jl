```@setup Cropbox
using Cropbox
```

!!! warning "Warning"
    This page is incomplete. Please check the Reference page for information regarding functions.

# Visualization

There are three main functions in Cropbox used for visualization. For information regarding syntax, please check the [reference](@ref Visualization1).
* [`plot()`](@ref plot)
* [`visualize()`](@ref visualize)
* [`manipulate()`](@ref manipulate)

## [`plot()`](@id plot)

The `plot()` function is divided into two main uses.

The following three [methods](https://docs.julialang.org/en/v1/manual/methods/) are used to plot a graph from a provided data source, with the graph type based on arguments. All three methods have the same output.

```
plot(df::DataFrame, x, y; <keyword arguments>) -> Plot
plot(X::Vector, Y::Vector; <keyword arguments>) -> Plot
plot(df::DataFrame, x, y, z; <keyword arguments>) -> Plot
```

**Example**
```@example Cropbox
```

The following two [methods](https://docs.julialang.org/en/v1/manual/methods/) are used to plot a graph of horizontal/vertical lines depending on `kind`, which can be one of two arguments: `:hline` or `:vline`. An initial plotting of `hline` requires `xlim` and `vline` requires `ylim`, respectively.

```
plot(v::Number; kind, <keyword arguments>) -> Plot
plot(V::Vector; kind, <keyword arguments>) -> Plot
```

**Example**
```@example Cropbox
```

### `plot!()`

```
plot!(p, <arguments>; <keyword arguments>) -> Plot
```

`plot!()` is an exntension of the `plot()` function used to update an existing `Plot` object `p` by appending a new graph made with `plot()`

**Example**
```@example Cropbox
```

## [`visualize()`](@id visualize)

```
visualize(<arguments>; <keyword arguments>) -> Plot
```

The `visualize()` function is used to make a plot from an output collected by running simulations. It is essentially identical to running the `plot()` function with a DataFrame from the `simulate()` function, and can be seen as a convenient function to run both `plot()` and `simulate()` together.

**Example**
```example Cropbox
```

### `visualize!()`

```
visualize!(p, <arguments>; <keyword arguments>) -> Plot
```

`visualize!()` updates an existing `Plot` object `p` by appending a new graph generated with `visualize()`

**Example**
```example Cropbox
```

## [`manipulate()`](@id manipulate)

The `manipulate` function has two different [methods](https://docs.julialang.org/en/v1/manual/methods/) for creating an interactive plot.

```
manipulate(f::Function; parameters, config=())
```
Create an interactive plot updated by callback f. Only works in Jupyter Notebook.


```
manipulate(args...; parameters, kwargs...)
```
Create an interactive plot by calling manipulate with visualize as a callback.


**Example**
```example Cropbox
@system S begin
end
```
