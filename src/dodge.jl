struct Enumerator{E<:Enum}
    enum::Type{E}
    instances::OrderedDict{Symbol, E}
    function Enumerator(e::Type{E}) where {E<:Enum}
        inst = OrderedDict{Symbol, E}(Symbol(i) => i for i in instances(e))
        new{E}(e, inst)
    end
end

Base.getproperty(en::Enumerator, s::Symbol) = getindex(getfield(en, :instances), s)
Base.propertynames(en::Enumerator) = Tuple(keys(getfield(en, :instances)))

@enum Position superimpose dodge stack

const position = Enumerator(Position)

used_attributes(P::PlotFunc, p::Position, args...) =
    Tuple(union((:width, :space), used_attributes(P, args...)))

function convert_arguments(P::PlotFunc, p::Position, args...;
    width = automatic, space = 0.2, kwargs...)
    plotspec = to_plotspec(P, convert_arguments(P, args...; kwargs...))
    ptype = plottype(plotspec)
    new_args, new_kwargs = plotspec.args, plotspec.kwargs
    @assert typeof(new_args) != typeof(args)
    final_plotspec = convert_arguments(ptype, p, new_args...;
        width = width, space = space)
    to_plotspec(ptype, final_plotspec; new_kwargs...)
end

function adjust_to_x(x, x′, y′)
    x === x′ && return y′
    d = Dict(zip(x′, y′))
    [get(d, el, NaN) for el in x]
end

series2matrix(x, xs, ys) = hcat((adjust_to_x(x, x′, y′) for (x′, y′) in zip(xs, ys))...)

function convert_arguments(P::PlotFunc, p::Position, pl::PlotList; width = automatic, space = 0.2)
    xs_input = (ps[1] for ps in pl)
    ys_input = (ps[2] for ps in pl)
    n = length(pl)
    ft = automatic
    if p === superimpose
        w = width
        xs, ys = xs_input, ys_input
    else
        x1 = first(xs_input)
        x = all(t -> t === x1, xs_input) ? x1 : vcat(xs_input...)
        unique_x = unique(sort(x))
        barwidth = width === automatic ? minimum(diff(unique_x))*(1-space) : width
        if p === dodge
            w = barwidth/n
            xs = (x .+ i*w .- w*(n+1)/2 for (i, x) in enumerate(xs_input))
            ys = ys_input
        else
            w = barwidth
            xs = xs_input
            y0, y1 = compute_stacked(series2matrix(x, xs_input, ys_input))
            y = y1 .- y0
            ft = y0
            ys = (adjust_to_x(x′, x, y[:, i]) for (i, x′) in enumerate(xs))
            fts = [adjust_to_x(x′, x, ft[:, i]) for (i, x′) in enumerate(xs)]
        end
    end
    plts = PlotSpec[]
    for (i, (x′, y′)) in enumerate(zip(xs, ys))
        fillto = ft === automatic ? automatic : fts[i]
        attr = Iterators.filter(p -> last(p) !== automatic, zip([:fillto, :width], [fillto, w]))
        push!(plts, PlotSpec{plottype(pl[i])}(x′, y′; attr..., pl[i].kwargs...))
    end

    PlotSpec{MultiplePlot}(PlotList(plts...))
end

convert_arguments(P::PlotFunc, p::Position, y::AbstractMatrix; kwargs...) =
    convert_arguments(P, p, 1:size(y, 1), y; kwargs...)

function convert_arguments(P::PlotFunc, p::Position, x::AbstractVector, y::AbstractMatrix;
    width = automatic, space = 0.2)

    n = size(y, 2)
    plots = PlotSpec[]
    for i in 1:n
        push!(plots, PlotSpec{P}(x, y[:, i]))
    end
    convert_arguments(MultiplePlot, p, PlotList(plots...); width = width, space = space)
end

function compute_stacked(y::AbstractMatrix)
    nr, nc = size(y)
    y1 = zeros(nr, nc)
    y0 = copy(y)
    y0[.!isfinite.(y0)] .= 0
    for r = 1:nr
        y_pos = y_neg = 0.0
        for c = 1:nc
            el = y0[r, c]
            if el >= 0
                y1[r, c] = y_pos
                y0[r, c] = y_pos += el
            else
                y1[r, c] = y_neg
                y0[r, c] = y_neg += el
            end
        end
    end
    y0, y1
end
