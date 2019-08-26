abstract type Equation{V} end

value(e::Equation) = missing
getargs(e::Equation) = ()
getkwargs(e::Equation) = ()
default(e::Equation) = Dict{Symbol,Any}()

struct StaticEquation{V} <: Equation{V}
    value::V
    name::Symbol
end

value(e::StaticEquation) = e.value
getdargs(e::StaticEquation) = ()
getdkwargs(e::StaticEquation) = ()

import DataStructures: OrderedDict
struct DynamicEquation{V,F<:Function} <: Equation{V}
    func::F
    name::Symbol
    args::Tuple{Vararg{Symbol}}
    kwargs::Tuple{Vararg{Symbol}}
    default::Dict{Symbol,Any}
    dargs::OrderedDict{Symbol,Any}
    dkwargs::Dict{Symbol,Any}
end

call(e::DynamicEquation, args, kwargs) = e.func(args...; kwargs...)
getargs(e::DynamicEquation) = e.args
getkwargs(e::DynamicEquation) = e.kwargs
default(e::DynamicEquation) = e.default
getdargs(e::DynamicEquation) = e.dargs
getdkwargs(e::DynamicEquation) = e.dkwargs

Equation(value, name) = StaticEquation(value, name)
Equation(func, name, args, kwargs, default, V::Type=Any) = begin
    if length(args) == 0 && length(kwargs) == 0
        StaticEquation(func(), name)
    else
        # ensure default values are evaled (i.e. `nothing` instead of `:nothing`)
        d = Dict{Symbol,Any}(k => eval(v) for (k, v) in default)
        F = typeof(func)
        DynamicEquation{V,F}(func, name, args, kwargs, d, OrderedDict{Symbol,Any}(), Dict{Symbol,Any}())
    end
end
