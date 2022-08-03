module ShapeCheck

using ExprTools, MLStyle

export @shapechecked

macro shapechecked(fdef)
    d = splitdef(fdef)
    get!(d, :args, [])
    get!(d, :kwargs, [])
    get!(d, :rtype, :Any)
    get!(d, :body, Expr(:block))

    new_args, arg_names, shape_decls, shape_names = extract_shape_info(d[:args])
    new_kwargs, kwarg_names, _, _ = extract_shape_info!(d[:kwargs], shape_decls, shape_names)
    @gensym result
    
    shape_asserts, new_rtype = @match d[:rtype] begin
        :($T[$(out_shapes...)]) => (Expr(:block,
                                         (:($size($result, $i) == $shape
                                            || $throw($DimensionMismatch(
                                                "Dimension $($i) of result does not match $($(string(shape))) = $(string($shape)), got $($size($result, $i)).")))
                                          for (i, shape) ∈ enumerate(out_shapes) if shape != :_)...), T)
        T => (nothing, T)
    end
    new_body = quote
        $(Expr(:block, shape_decls...))
        # Doing this in a `call(...)` block in order to capture any possible early `return`s. I re-provide the arguments
        # instead of closing over them because of https://github.com/JuliaLang/julia/issues/15276
        $result = $call(($(arg_names...),; $(kwarg_names...),) -> $(d[:body]), $(arg_names...); $(kwarg_names...))
        $shape_asserts
        $result
    end
    d[:args] = new_args
    d[:kwargs] = new_kwargs
    d[:body] = new_body
    d[:rtype] = new_rtype
    combinedef(d) |> esc
end

call(f, args...; kwargs...) = f(args...; kwargs...)

function process_shapes!(x, shapes, shape_decls, shape_names)
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
end

extract_shape_info(args) = extract_shape_info!(args, Expr[], Symbol[])
function extract_shape_info!(args, shape_decls, shape_names)
    v = map(args) do arg
        #Note: if someone gives an argument a default value, e.g. `f(x=1) = x + 1`, then
        #      that shows up as `Expr(:kw, :x, 1)` in the AST.
        arg = @match arg begin
            #Here we take some care to deal with any function arguments named :_, since
            # we don't want to accidentally use them as an r-value.
            :( :: $T) || :(_ :: $T)=> :($(gensym(:_)) :: $T)
            Expr(:kw, :( :: $T), y) || Expr(:kw, :(_ :: $T), y) => Expr(:kw, :($(gensym(:_)) :: $T), y)
            Expr(:kw, :_, y) => Expr(:kw, gensym(:_), y)
            :_ => gensym(:_)
            x => x
        end
        @match arg begin
            :($x :: $T[$(shapes...)]) => begin
                process_shapes!(x, shapes, shape_decls, shape_names)
                (:($x :: $T), x)
            end
            Expr(:kw, :($x :: $T[$(shapes...)]), val) => begin
                process_shapes!(x, shapes, shape_decls, shape_names)
                (Expr(:kw, :($x :: $T), val), x)
            end
            Expr(:kw, x, val) => (Expr(:kw, x, val), x)
            x => (x, x)
        end
    end
    args_typed = map(x -> x[1], v)
    arg_names  = map(x -> x[2], v)
    args_typed, arg_names, shape_decls, shape_names
end

end # module
