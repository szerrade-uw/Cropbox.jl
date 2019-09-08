using MacroTools
import MacroTools: @q, flatten, striplines

struct VarInfo{S<:Union{Symbol,Nothing}}
    name::Symbol
    alias::Vector{Symbol}
    args::Vector
    body#::Union{Expr,Symbol,Nothing}
    state::S
    type::Union{Symbol,Expr,Nothing}
    tags::Dict{Symbol,Any}
    line::Union{Expr,Symbol}
end

import Base: show
show(io::IO, i::VarInfo) = begin
    println(io, "name: $(i.name)")
    println(io, "alias: $(i.alias)")
    println(io, "func ($(repr(i.args))) = $(repr(i.body))")
    println(io, "state: $(repr(i.state))")
    println(io, "type: $(repr(i.type))")
    for (k, v) in i.tags
        println(io, "tag $k = $(repr(v))")
    end
    println(io, "line: $(i.line)")
end

VarInfo(line::Union{Expr,Symbol}) = begin
    # name[(args..)][: alias | [alias...]] [=> body] ~ [state][::type][(tags..)]
    @capture(line, decl_ ~ deco_)
    @capture(deco, state_::type_(tags__) | ::type_(tags__) | state_(tags__) | state_::type_ | ::type_ | state_)
    @capture(decl, (def1_ => body_) | def1_)
    @capture(def1, (def2_: [alias__]) | (def2_: alias__) | def2_)
    @capture(def2, name_(args__) | name_)
    args = isnothing(args) ? [] : args
    alias = isnothing(alias) ? [] : alias
    state = isnothing(state) ? nothing : Symbol(uppercasefirst(string(state)))
    type = @capture(type, [elemtype_]) ? :(Vector{$elemtype}) : type
    tags = parsetags(tags, type, state, args)
    VarInfo{typeof(state)}(name, alias, args, body, state, type, tags, line)
end

parsetags(::Nothing, type, state, args) = parsetags([], type, state, args)
parsetags(tags::Vector, type, state, args) = begin
    d = Dict{Symbol,Any}()
    for t in tags
        if @capture(t, k_=v_)
            if @capture(k, kn_::kt_)
                d[kn] = v
                d[Symbol("_type_", kn)] = kt
            else
                d[k] = v
            end
        elseif @capture(t, @u_str(v_))
            d[:unit] = :@u_str($v)
        else
            d[t] = true
        end
    end
    haskey(d, :parameter) && (d[:static] = true; push!(args, :config))
    !haskey(d, :unit) && (d[:unit] = nothing)
    (state in (:Accumulate, :Capture)) && !haskey(d, :time) && (d[:time] = :(context.clock.tick))
    !isnothing(type) && (d[:_type] = type)
    d
end

names(i::VarInfo) = [i.name, i.alias...]

####

abstract type Step end
struct PreStep <: Step end
struct MainStep <: Step end
struct PostStep <: Step end

suffix(::PreStep) = "_pre"
suffix(::MainStep) = "_main"
suffix(::PostStep) = "_post"

struct VarNode
    info::VarInfo
    step::Step #TODO: rename to VarStep?
end

####

const self = :($(esc(:self)))
const C = :($(esc(:Cropbox)))

genfield(i::VarInfo{Symbol}) = genfield(:($C.$(i.state)), i.name, i.alias)
genfield(i::VarInfo{Nothing}) = genfield(esc(i.type), i.name, i.alias)
genfield(S, var, alias) = @q begin
    $var::$S
    $(@q begin $([:($a::$S) for a in alias]...) end)
end

equation(f; static=false) = begin
    fdef = splitdef(f)
    name = Meta.quot(fdef[:name])
    key(x::Symbol) = x
    key(x::Expr) = x.args[1]
    args = key.(fdef[:args]) |> Tuple{Vararg{Symbol}}
    kwargs = key.(fdef[:kwargs]) |> Tuple{Vararg{Symbol}}
    pair(x::Symbol) = nothing
    pair(x::Expr) = x.args[1] => x.args[2]
    default = filter(!isnothing, [pair.(fdef[:args]); pair.(fdef[:kwargs])]) |> Vector{Pair{Symbol,Any}}
    # ensure default values are evaled (i.e. `nothing` instead of `:nothing`)
    default = :(Dict{Symbol,Any}(k => $(esc(:eval))(v) for (k, v) in $default))
    body = Meta.quot(fdef[:body])
    func = @q function $(esc(gensym(fdef[:name])))($(esc.(fdef[:args])...); $(esc.(fdef[:kwargs])...)) $(esc(fdef[:body])) end
    :($C.Equation($func, $name, $args, $kwargs, $default, $body; static=$static))
end

macro equation(f)
    e = equation(f)
    #FIXME: redundant call of splitdef() in equation()
    name = splitdef(f)[:name]
    :($(esc(name)) = $e)
end

genoverride(name, default) = @q get(_kwargs, $(Meta.quot(name)), $default)

gendecl(n::VarNode) = (n.step == MainStep()) ? gendecl(n.info) : nothing
gendecl(i::VarInfo{Symbol}) = begin
    static = get(i.tags, :static, false)
    if isnothing(i.body)
        if isempty(i.args)
            # use externally defined equation
            e = esc(i.name)
        elseif length(i.args) == 1
            # shorthand syntax for single value arg without key
            a = i.args[1]
            if @capture(a, k_=v_)
                # `f(a="b") ~ ...` expands to `f(a="b") => a ~ ...`
                f = @q function $(i.name)($k=$v) $k end
            elseif typeof(a) <: Symbol
                # `f(a) ~ ...` expands to `f(a) => a ~ ...`
                f = @q function $(i.name)($a) $a end
            else
                # `f("a") ~ ...` expands to `f(x="a") => x ~ ...`
                f = @q function $(i.name)(x=$a) x end
            end
            e = equation(f; static=static)
        else
            @error "Function not provided: $(i.name)"
        end
    else
        f = @q function $(i.name)($(Tuple(i.args)...)) $(i.body) end
        e = equation(f; static=static)
    end
    name = Meta.quot(i.name)
    alias = Tuple(i.alias)
    value = haskey(i.tags, :override) ? genoverride(i.name, missing) : geninit(i)
    stargs = [:($(esc(k))=$(esc(v))) for (k, v) in i.tags]
    decl = :($C.$(i.state)(; _name=$name, _alias=$alias, _value=$value, $(stargs...)))
    gendecl(decl, i.name, i.alias)
end
gendecl(i::VarInfo{Nothing}) = begin
    #@assert isempty(i.args) "Non-Var `$(i.name)` cannot have arguments: $(i.args)"
    if haskey(i.tags, :override)
        decl = genoverride(i.name, esc(i.body))
    elseif !isnothing(i.body)
        decl = esc(i.body)
    else
        decl = :($(esc(i.type))())
    end
    if haskey(i.tags, :expose)
        decl = :($(esc(i.name)) = $decl)
    end
    gendecl(decl, i.name, i.alias)
end
gendecl(decl, var, alias) = @q begin
    $self.$var = $decl
    $(@q begin $([:($self.$a = $self.$var) for a in alias]...) end)
    $(esc(var)) = $self.$var
    $(@q begin $([:($(esc(a)) = $var) for a in alias]...) end)
end

gensource(infos) = begin
    l = [i.line for i in infos]
    striplines(flatten(@q begin $(l...) end))
end

genfieldnamesunique(infos) = Tuple(i.name for i in infos)

genstruct(name, infos, incl) = begin
    S = esc(name)
    nodes = sortednodes(infos)
    fields = genfield.(infos)
    decls = gendecl.(nodes)
    source = gensource(infos)
    system = @q begin
        mutable struct $name <: $C.System
            $(fields...)
            function $name(; _kwargs...)
                $self = new()
                $(decls...)
                #$C.init!($self)
                $self
            end
        end
        $C.source(::Val{Symbol($S)}) = $(Meta.quot(source))
        $C.mixins(::Type{$S}) = Tuple($(esc(:eval)).($incl))
        $C.fieldnamesunique(::Type{$S}) = $(genfieldnamesunique(infos))
        #HACK: redefine them to avoid world age problem
        #@generated $C.collectible(::Type{$S}) = $C.filteredfields(Union{$C.System, Vector{$C.System}, $C.Produce}, $S)
        #@generated $C.updatable(::Type{$S}) = $C.filteredvars($S)
        $C.updatestatic!($(esc(:_system))::$S) = $(genupdate(nodes))
        $S
    end
    flatten(system)
end

#TODO: maybe need to prevent naming clash by assigning UUID for each System
source(s::System) = source(typeof(s))
source(S::Type{<:System}) = source(Symbol(S))
source(s::Symbol) = source(Val(s))
source(::Val{:System}) = @q begin
    self => self ~ ::Cropbox.System
    context ~ ::Cropbox.Context(override, expose)
end
mixins(::Type{<:System}) = [System]
mixins(s::System) = mixins(typeof(s))

fieldnamesunique(::Type{<:System}) = ()
filtervar(type::Type, ::Type{S}) where {S<:System} = begin
    l = collect(zip(fieldnames(S), fieldtypes(S)))
    F = fieldnamesunique(S)
    filter!(p -> p[1] in F, l)
    filter!(p -> p[2] <: type, l)
end
filteredfields(type::Type, ::Type{S}) where {S<:System} = begin
    l = filtervar(type, S)
    map(p -> p[1], l) |> Tuple{Vararg{Symbol}}
end
filteredvars(::Type{S}) where {S<:System} = begin
    l = filtervar(Var, S)
    d = Symbol[]
    for (n, T) in l
        push!(d, n)
    end
    Tuple(d)
end
#@generated collectible(::Type{S}) where {S<:System} = filteredfields(Union{System, Vector{System}, Var{<:Produce}}, S)
#@generated updatable(::Type{S}) where {S<:System} = filteredvars(S)
@generated updatestatic!(::System) = nothing

parsehead(head) = begin
    @capture(head, name_(mixins__) | name_)
    mixins = isnothing(mixins) ? [] : mixins
    incl = [:System]
    for m in mixins
        push!(incl, m)
    end
    (name, incl)
end

import DataStructures: OrderedDict, OrderedSet
gensystem(head, body) = gensystem(parsehead(head)..., body)
gensystem(name, incl, body) = genstruct(name, geninfos(body, incl), incl)
geninfos(body, incl) = begin
    con(b) = OrderedDict(i.name => i for i in VarInfo.(striplines(b).args))
    add!(d, b) = merge!(d, con(b))
    d = OrderedDict{Symbol,VarInfo}()
    for m in incl
        add!(d, source(m))
    end
    add!(d, body)
    collect(values(d))
end
sortinfos(infos) = begin
    M = Dict{Symbol,VarInfo}()
    for v in infos
        M[v.name] = v
        for a in v.alias
            M[a] = v
        end
    end
    d = Dependency{VarInfo}(M)
    add!(d, infos)
    sort(d)
end
invertices!(d::Dependency{VarInfo}, v::VarInfo; _...) = map(a -> vertex!(d, a), extract(v; equation=false, tag=true))

macro system(head, body)
    gensystem(head, body)
end

macro infos(head, body)
    geninfos(body, parsehead(head)[2])
end

export @equation, @system

####

extract(i::VarInfo; equation=true, tag=true) = begin
    parse(v::Expr) = parse(v.args[1])
    parse(v::Symbol) = v
    parse(v) = nothing
    pick(a) = @capture(a, k_=v_) ? parse(v) : parse(a)
    pack(A) = filter(!isnothing, pick.(A)) |> Tuple
    eq = equation ? pack(i.args) : ()
    @show eq
    #HACK: exclude internal tags (i.e. _type)
    tags = filter(p -> !startswith(String(p[1]), "_"), i.tags)
    @show tags
    par = tag ? pack(values(tags)) : ()
    @show par
    Set([eq..., par...]) |> collect
end

####

prev(n::VarNode) = begin
    if n.step == MainStep()
        VarNode(n.info, PreStep())
    elseif n.step == PostStep()
        VarNode(n.info, MainStep())
    elseif n.step == PreStep()
        error("Pre-step node can't have a previous node: $n")
    end
end

sortednodes(infos) = begin
    M = Dict{Symbol,VarInfo}()
    for v in infos
        M[v.name] = v
        for a in v.alias
            M[a] = v
        end
    end
    d = Dependency{VarNode}(M)
    add!(d, infos)
    sort(d)
end

node!(d::Dependency{VarNode}, v::VarInfo, t::Step) = vertex!(d, VarNode(v, t))
prenode!(d::Dependency{VarNode}, v) = node!(d, v, PreStep())
mainnode!(d::Dependency{VarNode}, v) = node!(d, v, MainStep())
postnode!(d::Dependency{VarNode}, v) = node!(d, v, PostStep())
node!(d::Dependency{VarNode}, v::VarInfo) = begin
    if v.state == :Solve
        @show "innodes: Var{<:Solve} = $v"
        prenode!(d, v)
    else
        mainnode!(d, v)
    end
end
invertices!(d::Dependency{VarNode}, v::VarInfo; kwargs...) = begin
    @show "innodes $v"
    A = extract(v; kwargs...)
    @show "extracted = $A"
    f(a::Symbol) = f(d.M[a])
    f(v0::VarInfo) = begin
        @show v0
        if v0 == v
            @show "cyclic! prenode $v"
            prenode!(d, v0)
        else
            node!(d, v0)
        end
    end
    f.(A)
end
add!(d::Dependency{VarNode}, v::VarInfo) = begin
    @show "add! $v"
    if v.state in (:Accumulate, :Capture)
        n0 = mainnode!(d, v)
        n1 = postnode!(d, v)
        link!(d, n0, n1)
        # Accumulate MainStep needs `time` update, but equation args should be excluded due to cyclic dependency
        inlink!(d, v, n0; equation=false)
        inlink!(d, v, n1)
    elseif v.state == :Solve
        n0 = prenode!(d, v)
        n1 = mainnode!(d, v)
        link!(d, n0, n1)
        inlink!(d, v, n1)
    elseif v.state == :Flag
        n0 = prenode!(d, v)
        n1 = postnode!(d, v)
        inlink!(d, v, n1)
    elseif v.state == :Produce
        n0 = mainnode!(d, v)
        n1 = postnode!(d, v)
        inlink!(d, v, n0)
        inlink!(d, v, n1)
    elseif !isnothing(v.state)
        n = mainnode!(d, v)
        inlink!(d, v, n)
    end
end

####

#=
# _predator_population_var / pre
predator_population = _predator_population_state.value
P = predator_population

# _predator_reproduction_rate_var / main
#v# = let
    0.75
end
predator_reproductaion_rate = let s=_predator_reproduction_rate_var.state
    store!(_predator_reproduction_rate_state, #v#)
    s.value
end
d = predator_reproduction_rate

# _timestep_var / main
#v# = let t=resolve(s, "context.clock.tick")
    0.01t
end
timestep = let s=_timestep_var.state
    store!(s, #v#) # track
    s.value
end
t = timestep

# _predator_population_var / main
predator_population = let s=_predator_population_state
    t = value(s.time.tick)
    t0 = s.tick
    if ismissing(t0)
        v = value(s.init)
    else
        v = s.value + s.rate * (t - t0)
    end
    store!(s, v)
    s.value
end

# _predator_population_var / post
#v# = let
  d*b*H*P - c*P
end
let s=_predator_population_state
    t = value(s.time.tick)
    r = unitfy(#v#, rateunit(s))
    f = () -> (s.tick = t; s.rate = r)
    p = priority(s)
    i = o.order #FIXME: should no longer be needed?
    queue!(order, f, p, i)
end

=#

geninit(v::VarInfo) = begin
    if get(v.tags, :parameter, false)
        @q let self=$(esc(:self)), config=$(esc(:config))
            v = option(config, self, $(names(v)))
            isnothing(v) ? $(geninit(v, Val(v.state))) : v
        end
    else
        geninit(v, Val(v.state))
    end
end
geninit(v::VarInfo, ::Val) = @q $C.unitfy($(genfunc(v)), $C.value($(esc(v.tags[:unit]))))
geninit(v::VarInfo, ::Val{:Advance}) = missing
geninit(v::VarInfo, ::Val{:Drive}) = @q $C.value($(genfunc(v))[$(esc(get(v.tags, :key, v.name)))])
geninit(v::VarInfo, ::Val{:Call}) = missing
geninit(v::VarInfo, ::Val{:Accumulate}) = @q $C.unitfy($C.value($(esc(get(v.tags, :init, 0)))), $C.value($(esc(v.tags[:unit]))))
geninit(v::VarInfo, ::Val{:Capture}) = @q $C.unitfy(0, $C.value($(esc(v.tags[:unit]))))
geninit(v::VarInfo, ::Val{:Flag}) = false
geninit(v::VarInfo, ::Val{:Produce}) = nothing
geninit(v::VarInfo, ::Val{:Solve}) = nothing
####

genupdate(nodes) = begin
    @q begin
        _context = _system.context
        $([genupdateinit(n) for n in nodes]...)
        $([genupdate(n) for n in nodes]...)
        nothing
    end
end

symstate(v::VarInfo) = Symbol("_state_$(v.name)")
symlabel(v::VarInfo, t::Step) = @q @label $(Symbol(v.name, suffix(t)))

genupdateinit(n::VarNode) = begin
    v = n.info
    s = symstate(v)
    @q $s = _system.$(v.name)
end

genupdate(n::VarNode) = genupdate(n.info, n.step)
genupdate(v::VarInfo, t::Step) = @q begin
    $(symlabel(v, t))
    $(v.name) = $(genupdate(v, Val(v.state), t))
    $([:($a = $(v.name)) for a in v.alias]...)
end
genupdate(v::VarInfo, t::PostStep) = @q begin
    $(symlabel(v, t))
    #FIXME: remove order index in queue!
    $C.queue!(_context.order, $(genupdate(v, Val(v.state), t)), $C.priority($(v.state)), 0)
end

genvalue(v::VarInfo) = :($C.value($(symstate(v))))
genstore(v::VarInfo) = begin
    @q let s = $(symstate(v))
        f = $(genfunc(v))
        $C.store!(s, f)
        #TODO: make store! return value
        $C.value(s)
    end
end

genupdate(v::VarInfo, ::Val{nothing}, ::MainStep) = nothing

genupdate(v::VarInfo, ::Val, ::PreStep) = genvalue(v)
genupdate(v::VarInfo, ::Val, ::MainStep) = genstore(v)
genupdate(v::VarInfo, ::Val, ::PostStep) = nothing

genupdate(v::VarInfo, ::Val{:Advance}, ::MainStep) = begin
    @q let s = $(symstate(v))
        $C.advance!(s)
    end
end

genupdate(v::VarInfo, ::Val{:Preserve}, ::MainStep) = begin
    s = symstate(v)
    :(ismissing($s.value) && $(genstore(v)))
end

genupdate(v::VarInfo, ::Val{:Drive}, ::MainStep) = begin
    @q let s = $(symstate(v))
        f = $(genfunc(v))
        v = $C.value(f[s.key])
        $C.store!(s, v)
        #TODO: make store! return value
        $C.value(s)
    end # value() for Var
end

genupdate(v::VarInfo, ::Val{:Call}, ::MainStep) = begin
    @q let s = $(symstate(v))
        f = $(genfunc(v))
        #FIXME: need to patch function arguments here
        #s.value = (a...; k...) -> $C.unitfy(f()(a...; k...), $C.unit(s))
        (; k...) -> $C.unitfy(f()(a...; k...), $C.unit(s))
    end
end

genupdate(v::VarInfo, ::Val{:Accumulate}, ::MainStep) = begin
    @q let s = $(symstate(v))
        t = $C.value(s.time.tick) # $C.value($(v.tags[:time]))
        t0 = s.tick
        if ismissing(t0)
            a = $C.value(s.init) # $C.value($(v.tags[:init]))
        else
            a = s.value + s.rate * (t - t0)
        end
        $C.store!(s, a)
        #TODO: make store! return value
        $C.value(s)
    end
end
genupdate(v::VarInfo, ::Val{:Accumulate}, ::PostStep) = begin
    @q let s = $(symstate(v))
        t = $C.value(s.time.tick) # $C.value($(v.tags[:time]))
        f = $(genfunc(v))
        r = $C.unitfy(f, $C.rateunit(s))
        () -> (@show t,r; s.tick = t; s.rate = r)
    end
end

genupdate(v::VarInfo, ::Val{:Capture}, ::MainStep) = begin
    @q let s = $(symstate(v))
        t = $C.value(s.time.tick) # $C.value($(v.tags[:time]))
        t0 = s.tick
        if !ismissing(t0)
            d = s.rate * (t - t0)
        end
        $C.store!(s, d)
    end
end
genupdate(v::VarInfo, ::Val{:Capture}, ::PostStep) = begin
    @q let s = $(symstate(v))
        t = $C.value(s.time.tick) # $C.value($(v.tags[:time]))
        f = $(genfunc(v))
        r = $C.unitfy(f, $C.rateunit(s))
        () -> (s.tick = t; s.rate = r)
    end
end

genupdate(v::VarInfo, ::Val{:Flag}, ::MainStep) = nothing
genupdate(v::VarInfo, ::Val{:Flag}, ::PostStep) = begin
    @q let s = $(symstate(v))
        f = $(genfunc(v))
        () -> $C.store!(s, f)
    end
end

genupdate(v::VarInfo, ::Val{:Produce}, ::MainStep) = nothing
genupdate(v::VarInfo, ::Val{:Produce}, ::PostStep) = begin
    @q let s = $(symstate(v))
        P = $(genfunc(v))
        #() -> $C.produce(s, p, x)
        !isnothing(P) && function ()
            for p in P
                b = p.type(; context=_context, p.args...)
                append!(s.value, b)
                #FIXME: need to reimplement inform!
                #$C.inform!(c.order, x, b)
            end
        end
    end
end

genupdate(v::VarInfo, ::Val{:Solve}, ::MainStep) = begin
    @q let s = $(symstate(v))
        p = $(genfunc(v))
        #TODO
        @goto $(symlabel(v, PreStep()))
    end
end

#TODO: reimplement Solve
# update!(s::Solve, f::AbstractVar, ::MainStep) = begin
#     #@show "begin solve $s"
#     trigger(x) = (store!(s, x); recite!(s.context.order, f))
#     cost(e) = x -> (trigger(x); e(x) |> ustrip)
#     b = (value(s.lower), value(s.upper))
#     if nothing in b
#         try
#             c = cost(x -> (x - f())^2)
#             v = find_zero(c, value(s))
#         catch e
#             #@show "convergence failed: $e"
#             v = value(s)
#         end
#     else
#         c = cost(x -> (x - f()))
#         v = find_zero(c, b, Roots.AlefeldPotraShi())
#     end
#     #HACK: trigger update with final value
#     trigger(v)
#     recitend!(s.context.order, f)
# end

genfunc(v::VarInfo) = begin
    parse(v) = isa(v, String) ? :($C.value($(esc(:_system)), $v)) : v
    pair(a) = let k, v; @capture(a, k_=v_) ? k => parse(v) : a => parse(a) end
    args = @q begin $([(p = pair(a); :($(esc(p[1])) = $(p[2]))) for a in v.args]...) end
    flatten(@q let $args; $(esc(v.body)) end)
end
