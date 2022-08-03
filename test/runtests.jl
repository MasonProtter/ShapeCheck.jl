using Test, ShapeCheck, OffsetArrays


@testset "basic" begin
    @shapechecked function bad_remove_last(x :: AbstractVector[n]) :: AbstractVector[n-1]
	    x[1:end-1]
    end

    @test_throws DimensionMismatch bad_remove_last(OffsetVector([:a, :b, :c, :d, :e], -2:2))

    AA = AbstractArray
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
end

@testset "optional and keyword arguments" begin
    @shapechecked function f(x::Vector[a], y=1)
        x .+ y
    end
    
    @test f([1, 2, 3]) == [2, 3, 4]

    
    @shapechecked function g(x, y::Vector[a]=[1,2,3]; z::Any[a]=[1,1,1]) :: Any[a]
        x .* y .+ z
    end
    
    @test_throws DimensionMismatch g(1; z=[1, 2])
    @test g(1, [1,2,3]) == [2, 3, 4]
    @test g(1; z=[1, 1, 1]) == [2, 3, 4]

    @shapechecked function h(_::Any[a], _) :: Any[1]
        a
    end
    @test h(rand(1000), 2) == 1000
    
end
