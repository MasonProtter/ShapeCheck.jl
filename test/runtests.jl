using Test, ShapeCheck, OffsetArrays

@shapechecked function bad_remove_last(x :: AbstractVector[n]) :: AbstractVector[n-1]
	x[1:end-1]
end

@test_throws DimensionMismatch bad_remove_last(OffsetVector([:a, :b, :c, :d, :e], -2:2))

const AA = AbstractArray
@shapechecked function horizontal_slice(x::AA[_, n], i) :: AA[n]
    x[i, :]
end

@test horizontal_slice([:a :b :c
                        :d :e :f], 2) == [:d, :e, :f]

@shapechecked function my_vcat(x::AA[a, b], y::AA[c, b]) :: AA[a + c, b]
    vcat(x, y)
end

@test my_vcat([1 2; 3 4], [5 6]) == [1 2
                                     3 4
                                     5 6]

@shapechecked function foo(x::Vector[a], y::Vector[min(a, 3)]) :: Number
    s = 0.0
    for i ∈ 1:min(a, 3)
        s += x[i] * y[i]
    end
    s
end

@test foo([1, 2], [3, 4]) == 11
@test foo([1:10;], [1, 1, 1]) == 6
