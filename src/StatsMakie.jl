module StatsMakie

using Observables
using AbstractPlotting
import AbstractPlotting: convert_arguments, used_attributes, plot!, combine
using AbstractPlotting: plottype, Plot, PlotFunc, to_value, to_node, to_tuple
using AbstractPlotting: node_pairs, extrema_nan, automatic, default_theme, to_plotspec
using AbstractPlotting: GeometryTypes
using Statistics, KernelDensity
import StatsBase
using Distributions
using IntervalSets
using Tables, IndexedTables
using IndexedTables: AbstractIndexedTable
using IntervalSets: Interval, endpoints
using Loess
using NamedArrays: NamedArray

export Data, Group, Style
export Position

include("scales.jl")
include("group.jl")
include("tables.jl")
include("density.jl")
include("histogram.jl")
include("distribution.jl")
include("corrplot.jl")
include("boxplot.jl")
include("violin.jl")
include("smooth.jl")
include("namedarray.jl")
include("dodge.jl")

end
