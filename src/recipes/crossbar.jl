using AbstractPlotting: extrema_nan

"""
    crossbar(x, y, ymin, ymax; kwargs...)

Draw a crossbar. A crossbar represents a range with a (potentially notched) box.
It is most commonly used as part of the boxplot.

# Arguments
- `x`: Position of the box
- `y`: Position of the midline within the box
- `ymin`: Lower limit of the box
- `ymax`: Upper limit of the box

# Keywords
- `orientation=:vertical`: orientation of box (`:vertical` or `:horizontal`)
- `width=0.8`: width of the box
- `notch=false`: draw the notch
- `notchmin=automatic`: Lower limit of the notch
- `notchmax=automatic`: Upper limit of the notch
"""
@recipe(CrossBar, x, y, ymin, ymax) do scene
    t = Theme(
        color = theme(scene, :color),
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        orientation = :vertical,
        # box
        width = 0.8,
        strokecolor = :white,
        strokewidth = 0.0,
        # notch
        notch = false,
        notchmin = automatic,
        notchmax = automatic,
        notchwidth = 0.5,
        # median line
        midline = true,
        midlinecolor = automatic,
        midlinewidth = 1.0,
    )
    t
end

function AbstractPlotting.plot!(plot::CrossBar)
    args = @extract plot (width, notch, notchmin, notchmax, notchwidth, orientation)

    signals = lift(
        plot[1],
        plot[2],
        plot[3],
        plot[4],
        args...,
    ) do x, y, ymin, ymax, bw, notch, nmin, nmax, nw, orientation
        show_notch = nmin !== automatic && nmax !== automatic

        # for horizontal crossbars just flip all components
        fpoint, frect = Point2f0, FRect
        if orientation == :horizontal
            fpoint, frect = _flip_xy ∘ fpoint, _flip_xy ∘ frect
        end

        # make the shape
        hw = bw ./ 2 # half box width
        l, m, r = x .- hw, x, x .+ hw

        if notch && nmin !== automatic && nmax !== automatic
            if any(nmin < ymin || nmax > ymax)
                @warn("Crossbar's notch went outside hinges. Set notch to false.")
            end
            # when notchmin = ymin || notchmax == ymax, fill disappears from
            # half the box. first ∘ StatsBase.rle removes adjacent duplicates.
            boxes =
                GeometryTypes.GLNormalMesh.(first.(StatsBase.rle.(Base.vect.(
                    fpoint.(l, ymin),
                    fpoint.(r, ymin),
                    fpoint.(r, nmin),
                    fpoint.(m .+ nw .* hw, y), # notch right
                    fpoint.(r, nmax),
                    fpoint.(r, ymax),
                    fpoint.(l, ymax),
                    fpoint.(l, nmax),
                    fpoint.(m .- nw .* hw, y), # notch left
                    fpoint.(l, nmin),
                ))))
            midlines = Pair.(fpoint.(m .- nw .* hw, y), fpoint.(m .+ nw .* hw, y))
        else
            boxes = frect.(l, ymin, bw, ymax .- ymin)
            midlines = Pair.(fpoint.(l, y), fpoint.(r, y))
        end

        return [boxes;], [midlines;]
    end
    boxes = @lift($signals[1])
    midlines = @lift($signals[2])

    poly!(
        plot,
        boxes,
        color = plot[:color],
        colorrange = plot[:colorrange],
        colormap = plot[:colormap],
        strokecolor = plot[:strokecolor],
        strokewidth = plot[:strokewidth],
    )
    linesegments!(
        plot,
        color = lift(
            (mc, sc) -> mc === automatic ? sc : mc,
            plot[:midlinecolor],
            plot[:strokecolor],
        ),
        linewidth = plot[:midlinewidth],
        visible = plot[:midline],
        midlines,
    )
end