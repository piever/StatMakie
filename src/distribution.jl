# pick a nice default x range given a distribution
function default_range(dist::Distribution, alpha = 0.0001)
    minval = isfinite(minimum(dist)) ? minimum(dist) : quantile(dist, alpha)
    maxval = isfinite(maximum(dist)) ? maximum(dist) : quantile(dist, 1-alpha)
    minval..maxval
end

isdiscrete(::Distribution) = false
isdiscrete(::Distribution{<:VariateForm, <:Discrete}) = true

support(dist::Distribution) = default_range(dist)
support(dist::Distribution{<:VariateForm, <:Discrete}) = UnitRange(endpoints(default_range(dist))...)

convert_arguments(P::PlotFunc, dist::Distribution) = convert_arguments(P, support(dist), dist)

function convert_arguments(P::PlotFunc, x::Union{Interval, AbstractVector}, dist::Distribution)
    default_ptype = isdiscrete(dist) ? ScatterLines : Lines
    ptype = plottype(P, default_ptype)
    ptype => convert_arguments(ptype, x, x -> pdf(dist, x))
end
#-----------------------------------------------------------------------------
# qqplots (M. K. Borregaard implementation from StatPlots)

@recipe(QQNorm) do scene
    Theme()
end

@recipe(QQPlot) do scene
    Theme()
end

plot!(scene::SceneLike, ::Type{<:QQNorm}, attributes::Attributes, p) = plot!(scene, QQPlot, attributes, Normal, p)
plot!(scene::SceneLike, ::Type{<:QQPlot}, attributes::Attributes, p...) = plot!(scene, attributes, qqbuild(loc(p...)...))

# function default
plottype(::QQPair) = Scatter

function plot!(scene::SceneLike, P::Type{<:AbstractPlot}, attributes::Attributes, h::QQPair)
    attr = copy(attributes)
    qqline = pop!(attr, :qqline, Observable(:identity)) |> to_value
    if qqline in (:fit, :quantile, :identity, :R)
        xs = [extrema(h.qx)...]
        if qqline == :identity
            ys = xs
        elseif qqline == :fit
            itc, slp = hcat(fill!(similar(h.qx), 1), h.qx) \ h.qy
            ys = slp .* xs .+ itc
        else # if qqline == :quantile || qqline == :R
            quantx, quanty = quantile(h.qx, [0.25, 0.75]), quantile(h.qy, [0.25, 0.75])
            slp = diff(quanty) ./ diff(quantx)
            ys = quanty .+ slp .* (xs .- quantx)
        end
        plot!(scene, LineSegments, attr, xs, ys)
    end
    plot!(scene, P, attr, h.qx, h.qy)
    scene
end

loc(D::Type{T}, x) where T<:Distribution = fit(D, x), x
loc(D, x) = D, x
