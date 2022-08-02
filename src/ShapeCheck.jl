module ShapeCheck

using ExprTools, MLStyle

export @shapechecked

call(f) = f()

macro shapechecked(fdef)
    d = splitdef(fdef)
    shape_decls = Expr[]
    shape_names = Symbol[]
    new_args = map(get!(d, :args, [])) do arg
        @match arg begin
            :($x :: $T[$(shapes...)]) => begin
                for (i, shape) ∈ enumerate(shapes)
                    if shape == :_
                        nothing
                    elseif shape ∈ shape_names || shape isa Expr
                        # This branch catches cases where either a shape name is repeated, or an expression is used.
                        # For repeated shape names, we assert that the new dim matches the earlier one.
                        # For expressions, we assert that it evaluates to true.
                        # e.g. someone might write f(x::T[a], y::U[a+1])
                        push!(shape_decls, :($isequal($shape, $size($x, $i))
                                             || $throw($DimensionMismatch("Shape $($shape) has mismatched sizes"))))
                    else
                        push!(shape_names, shape)
                        push!(shape_decls, :($shape = $size($x, $i)))
                    end 
                end
                :($x :: $T)
            end
            x => x
        end
    end
    @gensym result
    shape_asserts, new_rtype = @match get!(d, :rtype, [Any]) begin
        :($T[$(out_shapes...)]) => (Expr(:block,
                                         (:($size($result, $i) == $shape
                                            || $throw($DimensionMismatch(
                                                "Dimension $($i) of result does not match $($(string(shape))) \
= $(string($shape)), got $($size($result, $i)).")))
                                          for (i, shape) ∈ enumerate(out_shapes) if shape != :_)...), T)
        T => (nothing, T)
    end
    new_body = quote
        $(Expr(:block, shape_decls...))
        $result = $call() do
            # Doing this in a `call() do` block in order to capture any possible early `return`s.
            $(d[:body])
        end
        $shape_asserts
        $result
    end
    d[:args] = new_args
    d[:body] = new_body
    d[:rtype] = new_rtype
    combinedef(d) |> esc
end

end # module
