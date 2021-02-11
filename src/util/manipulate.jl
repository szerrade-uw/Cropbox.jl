import Interact

@nospecialize

manipulate(f::Function; parameters, config=()) = begin
    P = configure(parameters)
    C = configure(config)
    W = []
    L = []
    for (s, Q) in P
        n = Interact.node(:div, string(s))
        #HACK: use similar style/color (:light_magenta) to Config
        l = Interact.style(n, "font-family" => "monospace", "color" => :darkorchid)
        push!(L, l)
        for (k, V) in Q
            label = string(k)
            v = option(C, s, k)
            kw = ismissing(v) ? (; label) : (; label, value=v)
            #TODO: deunitfy() based on known units from parameters()
            w = Interact.widget(V; kw...)
            #HACK: use similar style/color (:light_blue) to Config
            d = w.layout(w).children[1].dom
            d.props[:style] = Dict("font-family" => "monospace", "width" => "25%")
            d.children[1].children[1].props[:style]["color"] = :royalblue
            push!(W, w)
            push!(L, w)
        end
    end
    K = parameterkeys(P)
    O = [Interact.onchange(w) for w in W]
    c = map(O...) do (W...)
        V = getindex.(W)
        configure(config, parameterzip(K, V))
    end
    output = Interact.@map f(&c)
    z = Interact.Widget{:Cropbox}(Dict(zip(K, W)); output)
    Interact.@layout!(z, Interact.vbox(L..., output))
end

manipulate(args...; parameters, config=(), kwargs...) = manipulate(function (c)
    visualize(args...; config=c, kwargs...)
end; parameters, config)

@specialize

export manipulate
