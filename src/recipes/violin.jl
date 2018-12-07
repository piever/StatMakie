@recipe(Violin, x, y) do scene
    Theme(;
        default_theme(scene, Poly)...,
        side = :both,
        width = 0.8,
        mediancolor = :white,
        show_median = false
    )
end

function plot!(plot::Violin)
    width, side = plot[:width], plot[:side]

    signals = lift(plot[1], plot[2], width, side) do x, y, bw, vside
        gt = lazymap(GroupIdxsIterator(x)) do (key, idxs)
            v = view(y, idxs)
            (x = key, kde = kde(v), median = median(v))
        end
        meshes = GeometryTypes.GLPlainMesh[]
        lines = Pair{Point2f0, Point2f0}[]
        for row in gt
            min, max = extrema_nan(row.kde.density)
            xl = reverse(row.x .- row.kde.density .* (0.5*bw/max))
            xr = row.x .+ row.kde.density .* (0.5*bw/max)
            yl = reverse(row.kde.x)
            yr = row.kde.x

            x_coord = vside == :left ? xl : vside == :right ? xr : vcat(xr, xl)
            y_coord = vside == :left ? yl : vside == :right ? yr : vcat(yr, yl)
            mesh = GeometryTypes.GLPlainMesh(Point2f0.(x_coord, y_coord))
            push!(meshes, mesh)
            median_left = Point2f0(vside == :right ? row.x : row.x-(0.5*bw), row.median)
            median_right = Point2f0(vside == :left ? row.x : row.x+(0.5*bw), row.median)
            push!(lines, median_left => median_right)
        end
        return meshes, lines
    end
    mesh!(plot, lift(first, signals), color = plot[:color], visible = plot[:visible])
    linesegments!(plot, lift(last, signals), color = plot[:mediancolor], visible = plot[:show_median])
end
