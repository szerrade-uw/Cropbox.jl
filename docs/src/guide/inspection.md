!!! warning "Warning"
    This page is incomplete. Please check the Reference page for information regarding functions.

# Inspection

There are two inspective functions in Cropbox that allow us to look at systems more closely. For information regarding syntax, please check the [reference](@ref Inspection1).
* [`look()`](@ref look)
* [`dive()`](@ref dive)

## [`look()`](@id look)

`look()` provides a convenient way of accessing variables within a system.

```
look(s, :a)
```

!!! note "Note"
    There is a macro version of this function, `@look`, which allows you to access a variable without using a symbol.
    
    ```
    @look S
    @look S a
    @look S, a
    ```
    
    Both `@look S.a` and `@look S a` are identical to `look(S, :a)`.

## [`dive()`](@id dive)

