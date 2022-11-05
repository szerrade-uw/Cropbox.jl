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

The `plot()` function is used to plot two-dimensional graphs.

**Example**

Let's start by making a simple plot by using two vectors of discrete values.

```@example Cropbox
x = [1, 2, 3, 4, 5]
y = [2, 4, 6, 8, 10]

plot(x, y)
```

You can also plot multiple series, by using a vector of vectors.

```@example Cropbox
plot(x, [x, y])
```

We will very often be dealing with DataFrames, which we can also use to plot graphs.

Let's make a simple DataFrame and use its columns to make another plot.

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
