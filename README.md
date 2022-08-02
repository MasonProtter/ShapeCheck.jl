# ShapeCheck.jl

This provides a nice(?) syntax for **runtime** shape checking of function outputs given their inputs. This should work for any type `T` which has methods for `size(::T, n)`. The shapes being checked here in this package can *not* be dispatched on. 


Consider this shapechecked implementation of a `remove_last` function: 
``` julia
using ShapeCheck

@shapechecked function remove_last(x :: AbstractVector[n]) :: AbstractVector[n-1]
	x[1:end-1]
end
```

The use of square brackets in the type signature of the above function are essentially assertions about the shapes
of the dimensions of the inputs and outputs. It says that `x` must be an `AbstractVector`, and that if 
`n = size(x, 1)`, then the output of the function must have `size(result, 1) == n - 1`. 

This way, the hidden logic error in our function gets caught:
``` julia
julia> using OffsetArrays

julia> let v = OffsetVector([:a, :b, :c, :d, :e], -2:2)
           remove_last(v)
       end
ERROR: DimensionMismatch("Dimension 1 of result does not match n - 1 = 4, got 1.")
Stacktrace:
 [1] remove_last(x::OffsetVector{Symbol, Vector{Symbol}})
   @ Main [...]/ShapeCheck/src/ShapeCheck.jl:37
 [2] top-level scope
   @ REPL[15]:2
```
Without the shapecheck, this function would have silently returned just `[:d]`. Instead, what we should have written is
``` julia
@shapechecked function remove_last(x :: AbstractVector[n]) :: AbstractVector[n-1]
	x[begin:end-1]
end
```
if we want to be able to handle general `AbstractVector`s correctly. 

ShapeCheck.jl performs these checks at runtime, so they are not truly zero cost (unless your shapes are constant propagated). 
### Syntax Examples

Suppose you only care about the 2nd dimension of an array, you can always just 'name' a dim `_` and it'll be thrown out.
If you don't care about a inner dim, just use `_` to ignore it: 
``` julia
const AA = AbstractArray

@shapechecked function vertical_slice(x::AA[_, n], i) :: AA[n]
    x[:, i]
end
```
Dimensions to the *right* of the last one listed are ignored by default.


You can demand that multiple dimensions of arguments match
``` julia
@shapechecked function my_vcat(x::AA[a, b], y::AA[c, b]) :: AA[a + c, b]
    vcat(x, y)
end
```

and you can even demand that they are some function of another argument
``` julia
@shapechecked function foo(x::Vector[a], y::Vector[min(a, 3)]) :: Number
    s = 0.0
    for i ∈ 1:min(a, 3)
        s += x[i] * y[i]
    end
    s
end
```
