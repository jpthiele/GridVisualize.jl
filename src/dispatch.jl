
"""
$(SIGNATURES)

Heuristically check if Plotter is VTKView
"""
isvtkview(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:StaticFrame)

"""
$(SIGNATURES)

Heuristically check if Plotter is PyPlot
"""
ispyplot(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:Gcf)

"""
$(SIGNATURES)

Heuristically check if  Plotter is Plots
"""
isplots(Plotter)= (typeof(Plotter)==Module) && isdefined(Plotter,:gr)


"""
$(SIGNATURES)

Heuristically check if Plotter is Makie/WGLMakie
"""
ismakie(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:AbstractPlotting)

"""
$(SIGNATURES)

Heuristically check if Plotter is MeshCat
"""
ismeshcat(Plotter)= (typeof(Plotter)==Module)&&isdefined(Plotter,:Visualizer)

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type PyPlotType  end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type MakieType   end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type PlotsType   end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type VTKViewType end

"""
$(TYPEDEF)

Abstract type for dispatching on plotter
"""
abstract type MeshCatType end

"""
$(SIGNATURES)
    
Heuristically detect type of plotter, returns the corresponding abstract type fro plotting.
"""
function plottertype(Plotter::Union{Module,Nothing})
    if ismakie(Plotter)
        return MakieType
    elseif isplots(Plotter)
        return PlotsType
    elseif ispyplot(Plotter)
        return PyPlotType
    elseif isvtkview(Plotter)
        return VTKViewType
    elseif ismeshcat(Plotter)
        return MeshCatType
    end
    Nothing
end


"""
$(TYPEDEF)

A SubVisualizer is just a dictionary which contains plotting information,
including type of the plotter and its position in the plot.
"""
const SubVisualizer=Union{Dict{Symbol,Any},Nothing}

#
# Update subplot context from dict
#
function _update_context!(ctx::SubVisualizer,kwargs)
    for (k,v) in kwargs
        ctx[Symbol(k)]=v
    end
    ctx
end

"""
$(TYPEDEF)

GridVisualizer struct
"""
struct GridVisualizer
    Plotter::Union{Module,Nothing}
    subplots::Array{SubVisualizer,2}
    context::SubVisualizer
    GridVisualizer(Plotter::Union{Module,Nothing}, layout::Tuple, default::SubVisualizer)=new(Plotter,
                                                                                            [copy(default) for I in CartesianIndices(layout)],
                                                                                              copy(default))
end

"""
````
    GridVisualizer(; Plotter=nothing , kwargs...)
````

Create a  grid visualizer

Plotter: defaults to `nothing` and can be `PyPlot`, `Plots`, `VTKView`, `Makie`.
This pattern to pass the backend as a module to a plot function allows to circumvent
to create heavy default package dependencies.


Depending on the `layout` keyword argument, a 2D grid of subplots is created.
Further `...plot!` commands then plot into one of these subplots:

```julia
vis=GridVisualizer(Plotter=PyPlot, layout=(2,2)
...plot!(vis[1,2], ...)
```

A `...plot`  command just implicitely creates a plot context:

```julia
gridplot(grid, Plotter=PyPlot) 
```

is equivalent to

```julia
vis=GridVisualizer(Plotter=PyPlot, layout=(1,1))
gridplot!(vis,grid) 
```

Please note that the return values of all plot commands are specific to the Plotter.

Depending on the backend, interactive mode switch between "gallery view" showing all plots at
onece and "focused view" showing only one plot is possible.


Keyword arguments: see [`available_kwargs`](@ref)

"""
function GridVisualizer(;Plotter::Union{Module,Nothing}=nothing, kwargs...)
    default_ctx=Dict{Symbol,Any}( k => v[1] for (k,v) in default_plot_kwargs())
    _update_context!(default_ctx,kwargs)
    layout=default_ctx[:layout]
    if isnothing(Plotter)
        default_ctx=nothing
    end
    p=GridVisualizer(Plotter,layout,default_ctx)
    if !isnothing(Plotter)
        p.context[:Plotter]=Plotter
        for I in CartesianIndices(layout)
            ctx=p.subplots[I]
            i=Tuple(I)
            ctx[:subplot]=i
            ctx[:iplot]=layout[2]*(i[1]-1)+i[2]
            ctx[:Plotter]=Plotter
            ctx[:GridVisualizer]=p
        end
        initialize!(p,plottertype(Plotter))
    end
    p
end


"""
$(SIGNATURES)

Return the layout of a GridVisualizer
"""
Base.size(p::GridVisualizer)=size(p.subplots)

"""
$(SIGNATURES)

Return a SubVisualizer
"""
Base.getindex(p::GridVisualizer,i,j)=p.subplots[i,j]


"""
$(SIGNATURES)

Return the type of a plotter.
"""
plottertype(p::GridVisualizer)=plottertype(p.Plotter)

#
# Default context information with help info.
#
default_plot_kwargs()=OrderedDict{Symbol,Pair{Any,String}}(
    :colorlevels => Pair(51,"Number of color levels for contour plot"),
    :isolines => Pair(11,"Number of isolines in contour plot"),
    :linewidth => Pair(2,"1D plot or isoline linewidth"),
    :linestyle => Pair(:solid,"1D Plot linestyle: one of [:solid, :dash, :dot, :dashdot, :dashdotdot]"),
    :markevery => Pair(5,"1D plot marker stride"),
    :markersize => Pair(5,"1D plot marker size"),
    :markershape => Pair(:none,"1D plot marker shape: one of [:none, :circle, :star5, :diamond, :hexagon, :cross, :xcross, :utriangle, :dtriangle, :rtriangle, :ltriangle, :pentagon, :+, :x]"),
    :color => Pair((0.0,0.0,0.0),"1D plot line color"),
    :cellwise => Pair(false,"1D plots cellwise can be slow)"),
    :label => Pair("","1D plot label"),
    :legend => Pair(:best,"Plot legend (position): one of [:none, :best, :lt, :ct, :rt, :lc, :rc, :lb, :cb, :rb]"),    
    :colorbar => Pair(true,"2/3D plot colorbar"),
    :aspect => Pair(1.0,"Aspect ratio modification"),
    :show => Pair(false,"Show plot immediately"),
    :reveal => Pair(false,"Show plot immediately (same as :show)"),
    :clear => Pair(true,"Clear plot before new plot."),
    :colormap => Pair(:viridis,"Contour plot colormap (any from [ColorSchemes.jl](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/#Pre-defined-schemes))"),
    :xlimits => Pair((1,-1),"x limits"),
    :ylimits => Pair((1,-1),"y limits"),
    :zlimits => Pair((1,-1),"z limits"),
    :flimits => Pair((1,-1),"function limits"),
    :layout => Pair((1,1),"Layout of plots in window"),
    :subplot => Pair((1,1),"Actual subplot"),
    :alpha => Pair(0.1,"Surface alpha value"),
    :interior => Pair(true,"Plot interior of grid"),
    :outline => Pair(true,"Plot outline of domain"),
    :xplane => Pair(prevfloat(Inf),"xplane for 3D visualization"),
    :yplane => Pair(prevfloat(Inf),"yplane for 3D visualization"),
    :zplane => Pair(prevfloat(Inf),"zplane for 3D visualization"),
    :flevel => Pair(prevfloat(Inf),"isolevel for 3D visualization"),
    :azim => Pair(-60,"Azimuth angle for 3D visualization (in degrees)"),
    :elev => Pair(30,"Elevation angle for 3D visualization (in degrees)"),
    :perspectiveness => Pair(0.25,"A number between 0 and 1, where 0 is orthographic, and 1 full perspective"),
    :title => Pair("","Plot title"),
    :fontsize => Pair(20,"Fontsize of titles. All others are relative to it"),
    :scene3d  => Pair("Axis3","Type of Makie 3D scene. Alternaitve to `Axis3` is `LScene`"),
    :elevation => Pair(0.0,"Height factor for elevation of 2D plot"),
    :resolution => Pair((500,500),"Plot xy resolution"),
    :framepos => Pair(1,"Subplot position in frame (VTKView)"),
    :fignumber => Pair(1,"Figure number (PyPlot)")
)

#
# Print default dict for interpolation into docstrings
#
function _myprint(dict)
    lines_out=IOBuffer()
    for (k,v) in dict
        println(lines_out,"  - `$(k)`: $(v[2]). Default: `$(v[1])`\n")
    end
    String(take!(lines_out))
end

"""
$(SIGNATURES)

Available kwargs for all methods of this package.

$(_myprint(default_plot_kwargs()))
"""
available_kwargs()=println(_myprint(default_plot_kwargs()))



"""
````
gridplot!(visualizer[i,j], grid, kwargs...)
gridplot!(visualizer, grid, kwargs...)
````

Plot grid into subplot in the visualizer. If `[i,j]` is omitted, `[1,1]` is assumed.

Keyword arguments: see [`available_kwargs`](@ref)
"""
function gridplot!(ctx::SubVisualizer,grid::ExtendableGrid; kwargs...)
    _update_context!(ctx,kwargs)
    gridplot!(ctx,plottertype(ctx[:Plotter]),Val{dim_space(grid)},grid)
end

gridplot!(p::GridVisualizer,grid::ExtendableGrid, kwargs...)= gridplot!(p[1,1],grid; kwargs...)


"""
````
gridplot(grid; Plotter=nothing; kwargs...)
````

Create grid visualizer and plot grid

Keyword arguments: see [`available_kwargs`](@ref)
"""
gridplot(grid::ExtendableGrid; Plotter=nothing, kwargs...)=gridplot!(GridVisualizer(Plotter=Plotter; show=true, kwargs...),grid)


"""
````
scalarplot!(visualizer[i,j], grid, vector; kwargs...)
scalarplot!(visualizer, grid, vector; kwargs...)
scalarplot!(visualizer[i,j], grid, function; kwargs...)
scalarplot!(visualizer[i,j], coord_vector, vector; kwargs...)
scalarplot!(visualizer[i,j], coord_vector, function; kwargs...)
````

Plot node vector on grid as P1 FEM function on the triangulation into subplot in the visualizer. If `[i,j]` is omitted, `[1,1]` is assumed.

If instead of the node vector,  a function is given, it will be evaluated on the grid.

If instead of the grid, a vector of 1D-coordinates is given, a 1D grid is created.

Keyword arguments: see [`available_kwargs`](@ref)
"""
function scalarplot!(ctx::SubVisualizer,grid::ExtendableGrid,func; kwargs...)
    _update_context!(ctx,Dict(:clear=>true,:show=>false,:reveal=>false))
    _update_context!(ctx,kwargs)
    scalarplot!(ctx,plottertype(ctx[:Plotter]),Val{dim_space(grid)},grid,func)
end

scalarplot!(p::GridVisualizer,grid::ExtendableGrid, func; kwargs...) = scalarplot!(p[1,1],grid,func; kwargs...)
scalarplot!(ctx::SubVisualizer,grid::ExtendableGrid,func::Function; kwargs...)=scalarplot!(ctx,grid,map(func,grid);kwargs...)
scalarplot!(ctx::SubVisualizer,X::AbstractVector,func; kwargs...)=scalarplot!(ctx,simplexgrid(X),func;kwargs...)
scalarplot!(ctx::GridVisualizer,X::AbstractVector,func; kwargs...)=scalarplot!(ctx,simplexgrid(X),func;kwargs...)


"""
````
scalarplot(grid,vector)
scalarplot(grid,function)
scalarplot(coord_vector,vector)
scalarplot(coord_vector,function)
````

Plot node vector on grid as P1 FEM function on the triangulation.

If instead of the node vector,  a function is given, it will be evaluated on the grid.

If instead of the grid, a vector of 1D-coordinates is given, a 1D grid is created.

Keyword arguments: see [`available_kwargs`](@ref)
"""
scalarplot(grid::ExtendableGrid,func ;Plotter=nothing,kwargs...) = scalarplot!(GridVisualizer(Plotter=Plotter;kwargs...),grid,func,show=true)
scalarplot(X::AbstractVector,func ;kwargs...)=scalarplot(simplexgrid(X),func;kwargs...)

"""
$(SIGNATURES)

Finish and show plot. Same as setting `:reveal=true` or `:show=true` in last plot statment
for a context.
"""
reveal(visualizer::GridVisualizer)=reveal(visualizer, plottertype(visualizer.Plotter))

"""
$(SIGNATURES)

Save last plotted figure from visualizer to disk.
"""
save(fname,visualizer::GridVisualizer)=save(fname,p, plottertype(p.Plotter))

"""
$(SIGNATURES)

Save scene returned from [`reveal`](@ref), [`scalarplot`](@ref) or [`gridplot`](@ref)  to disk.
"""
save(fname,scene;Plotter::Union{Module,Nothing}=nothing)=save(fname,scene, Plotter, plottertype(Plotter))



#
# Dummy methods to allow Plotter=nothing
#
_update_context!(::Nothing,kwargs)=nothing
Base.copy(::Nothing)=nothing

gridplot!(ctx::Nothing,grid::ExtendableGrid;kwargs...)=nothing
gridplot!(ctx, ::Type{Nothing}, ::Type{Val{1}}, grid)=nothing
gridplot!(ctx, ::Type{Nothing}, ::Type{Val{2}}, grid)=nothing
gridplot!(ctx, ::Type{Nothing}, ::Type{Val{3}}, grid)=nothing

scalarplot!(ctx::Nothing,grid::ExtendableGrid,func;kwargs...)=nothing
scalarplot!(ctx, ::Type{Nothing}, ::Type{Val{1}},grid,func)=nothing
scalarplot!(ctx, ::Type{Nothing}, ::Type{Val{2}},grid,func)=nothing
scalarplot!(ctx, ::Type{Nothing}, ::Type{Val{3}},grid,func)=nothing

save(fname,scene,Plotter,::Type{Nothing})=nothing
displayable(ctx,Any)=nothing
reveal(p,::Type{Nothing})=nothing

