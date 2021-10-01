## Get unary and binary functions

function is_unary(f::Function, t::Type = Number)
    f ∈ [+, -, *, /, ^] && return false
    for m in methods(f, (t, ))
        m.nargs - 1 > 1 && return false
    end
    return true
end

function is_binary(f::Function, t::Type = Number)
    f ∈ [+, -, *, /, ^] && return true
    !is_unary(f, t)
end

function ariety(f::Function, t::Type = Number)
    is_unary(f, t) && return 1
    is_binary(f, t) && return 2
    return 0
end

function sort_ops(f::Vector{Function})
    U = Function[]
    B = Function[]
    for fi in f
        is_unary(fi) ? push!(U, fi) : push!(B, fi)
    end
    return U, B
end

## Create linear independent basis

count_operation(x::Number, op::Function, nested::Bool = true) = 0
count_operation(x::Sym, op::Function, nested::Bool = true) = 0
count_operation(x::Num, op::Function, nested::Bool = true) = count_operation(value(x), op, nested)

function count_operation(x, op::Function, nested::Bool = true)
    if operation(x)== op
        if is_unary(op)
            # Handles sin, cos and stuff
            nested && return 1 + count_operation(arguments(x), op)
            return 1
        else
            # Handles +, *
            nested && length(arguments(x))-1 + count_operation(arguments(x), op)
            return length(arguments(x))-1
        end
    elseif nested
        return count_operation(arguments(x), op, nested)
    end
    return 0
end

function count_operation(x, ops::AbstractArray, nested::Bool = true)
    return sum([count_operation(x, op, nested) for op in ops])
end

function count_operation(x::AbstractArray, op::Function, nested::Bool = true)
    sum([count_operation(xi, op, nested) for xi in x])
end

function count_operation(x::AbstractArray, ops::AbstractArray, nested::Bool = true)
    counter = 0
    @inbounds for xi in x, op in ops
        counter += count_operation(xi, op, nested)
    end
    counter
end

function split_term!(x::AbstractArray, o, ops::AbstractArray = [+])
    if istree(o)
        n_ops = count_operation(o, ops, false)
        c_ops = 0
        @views begin
            if n_ops == 0
                x[begin]= o
            else
                counter_ = 1
                for oi in arguments(o)
                    c_ops = count_operation(oi, ops, false)
                    split_term!(x[counter_:counter_+c_ops], oi, ops)
                    counter_ += c_ops + 1
                end
            end
        end
    else
        x[begin] = o
    end
    return
end

split_term!(x::AbstractArray,o::Num, ops::AbstractArray = [+]) = split_term!(x, value(o), ops)

remove_constant_factor(x::Num) = remove_constant_factor(value(x))
remove_constant_factor(x::Number) = one(x)

function remove_constant_factor(x)
    # Return, if the function is nested
    istree(x) || return x
    # Count the number of operations
    n_ops = count_operation(x, [*], false)+1
    # Create a new array
    ops = Array{Any}(undef, n_ops)
    @views split_term!(ops, x, [*])
    filter!(x->!isa(x, Number), ops)
    return Num(prod(ops))
end

function remove_constant_factor(o::AbstractArray)
    oi = Array{Any}(undef, size(o))
    for i in eachindex(o)
        oi[i] = remove_constant_factor(o[i])
    end
    return Num.(oi)
end

function create_linear_independent_eqs(ops::AbstractVector, simplify_eqs::Bool = false)
    o = simplify.(ops)
    o = remove_constant_factor(o)
    n_ops = [count_operation(oi, +, false) for oi in o]
    n_x = sum(n_ops) + length(o)
    u_o = Array{Any}(undef, n_x)
    ind_lo, ind_up = 0, 0
    for i in eachindex(o)
        ind_lo = i > 1 ? sum(n_ops[1:i-1]) + i : 1
        ind_up = sum(n_ops[1:i]) + i

        @views split_term!(u_o[ind_lo:ind_up], o[i], [+])
    end
    u_o = remove_constant_factor(u_o)
    unique!(u_o)
    return simplify_eqs ? simplify.(Num.(u_o)) : Num.(u_o)
end
