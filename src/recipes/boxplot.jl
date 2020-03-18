using AbstractPlotting: extrema_nan

notch_width(q2, q4, N) = 1.58 * (q4-q2)/sqrt(N)

pair_up(dict, key) = (key => dict[key])

#=
Taken from https://github.com/JuliaPlots/StatPlots.jl/blob/master/src/boxplot.jl#L7
The StatPlots.jl package is licensed under the MIT "Expat" License:
    Copyright (c) 2016: Thomas Breloff.
=#
@recipe(BoxPlot, x, y) do scene
    t = Theme(
        color = theme(scene, :color),
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        notch = false,
        range = 1.5,
        outliers = true,
        whisker_width = :match,
        width = 0.8,
        marker = :circle,
        strokecolor = :white,
        strokewidth = 1.0,
        mediancolor = automatic,
        show_median = true,
        markersize = automatic,
        outlierstrokecolor = :black,
        outlierstrokewidth = 1.0,
        medianlinewidth = automatic,
        whiskercolor = :black,
        whiskerlinewidth = 1.0,
        orientation = :vertical,
    )
    get!(t, :outliercolor, t[:color])
    t
end

conversion_trait(x::Type{<:BoxPlot}) = SampleBased()

_cycle(v::AbstractVector, idx::Integer) = v[mod1(idx, length(v))]
_cycle(v, idx::Integer) = v

_flip_xy(p::Point2f0) = reverse(p)
_flip_xy(r::Rect{2, T}) where T = Rect{2, T}(reverse(r.origin), reverse(r.widths))

function AbstractPlotting.plot!(plot::BoxPlot)
    args = @extract plot (width, range, outliers, whisker_width, notch, orientation)

    signals = lift(plot[1], plot[2], args...) do x, y, bw, range, outliers, whisker_width, notch, orientation
        glabels = sort(collect(unique(x)))
        warning = false
        outlier_points = Point2f0[]
        if !(whisker_width == :match || whisker_width >= 0)
            error("whisker_width must be :match or a positive number. Found: $whisker_width")
        end
        ww = whisker_width == :match ? bw : whisker_width
        boxes = FRect2D[]
        notched_boxes = Vector{Point2f0}[]
        t_segments = Point2f0[]
        medians = Point2f0[]
        for (i, glabel) in enumerate(glabels)
            # filter y
            values = y[filter(i -> _cycle(x, i) == glabel, 1:length(y))]
            # compute quantiles
            q1, q2, q3, q4, q5 = quantile(values, LinRange(0, 1, 5))
            # notch
            n = notch_width(q2, q4, length(values))
            # warn on inverted notches?
            if notch && !warning && ( (q2>(q3-n)) || (q4<(q3+n)) )
                @warn("Boxplot's notch went outside hinges. Set notch to false.")
                warning = true # Show the warning only one time
            end

            # make the shape
            center = glabel
            hw = 0.5 * _cycle(bw, i) # Box width
            HW = 0.5 * _cycle(ww, i) # Whisker width
            l, m, r = center - hw, center, center + hw
            lw, rw = center - HW, center + HW

            # internal nodes for notches
            L, R = center - 0.5 * hw, center + 0.5 * hw

            # outliers
            if Float64(range) != 0.0  # if the range is 0.0, the whiskers will extend to the data
                limit = range*(q4-q2)
                inside = Float64[]
                for value in values
                    if (value < (q2 - limit)) || (value > (q4 + limit))
                        if outliers
                            push!(outlier_points, (center, value))
                        end
                    else
                        push!(inside, value)
                    end
                end
                # change q1 and q5 to show outliers
                # using maximum and minimum values inside the limits
                q1, q5 = extrema_nan(inside)
            end
            # Whiskers
            push!(t_segments, (m, q2), (m, q1), (lw, q1), (rw, q1))# lower T
            push!(t_segments, (m, q4), (m, q5), (rw, q5), (lw, q5))# upper T
            # Box
            if notch
                push!(notched_boxes, map(Point2f0, [(l,q2),(r,q2),(r, q2 + n/2),(R, q3), (r, q4-n/2) , (r, q4), (l, q4), (l, q4-n/2), (L, q3), (l, q2+n/2), (l,q2)]))
                # push!(boxes, FRect(l, q4, hw, n)) # lower box
                push!(medians, (L, q3), (R, q3))
            else
                push!(boxes, FRect(l, q2, 2hw, (q4 - q2)))
                push!(medians, (l, q3), (r, q3))
            end
        end

        final_boxes = notch ? notched_boxes : boxes

        # for horizontal boxplots just flip all components
        if orientation == :horizontal
            final_boxes = _flip_xy.(final_boxes)
            outlier_points = _flip_xy.(outlier_points)
            medians = _flip_xy.(medians)
            t_segments = _flip_xy.(t_segments)
        elseif orientation != :vertical
            error("Invalid orientation $orientation. Valid options: :horizontal or :vertical.")
        end

        return final_boxes, outlier_points, medians, t_segments
    end

    boxes = @lift($signals[1])
    outliers = @lift($signals[2])
    medians = @lift($signals[3])
    t_segments = @lift($signals[4])

    scatter!(
        plot,
        color = plot[:outliercolor],
        strokecolor = plot[:outlierstrokecolor],
        marker = plot[:marker],
        markersize = lift((w, ms)-> ms === automatic ? w * 0.1 : ms, width, plot.markersize),
        strokewidth = plot[:outlierstrokewidth],
        outliers,
    )
    linesegments!(
        plot,
        color = plot[:whiskercolor],
        linewidth = plot[:whiskerlinewidth],
        t_segments,
    )
    poly!(
        plot,
        color = plot[:color],
        colorrange = plot[:colorrange],
        colormap = plot[:colormap],
        strokecolor = plot[:strokecolor],
        strokewidth = plot[:strokewidth],
        boxes,
    )
    linesegments!(
        plot,
        color = lift((mc,sc) -> mc === automatic ? sc : mc, plot.mediancolor, plot.strokecolor),
        linewidth = lift((lw,sw) -> lw === automatic ? sw : lw, plot.medianlinewidth, plot.strokewidth),
        visible = plot[:show_median],
        medians,
    )
end
