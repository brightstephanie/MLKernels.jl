#==========================================================================
  Kernel Functions
==========================================================================#

call{T<:AbstractFloat}(κ::Kernel{T}, x::T, y::T) = kernel(κ, x, y)
call{T<:AbstractFloat}(κ::Kernel{T}, x::Vector{T}, y::Vector{T}) = kernel(κ, x, y)
call{T<:AbstractFloat}(κ::Kernel{T}, x::Matrix{T}, y::Matrix{T}) = kernel(κ, x, y)

kernel{T<:AbstractFloat}(κ::BaseKernel{T}, x::T, y::T) = pairwise(κ, x, y)
kernel{T<:AbstractFloat}(κ::BaseKernel{T}, x::Vector{T}, y::Vector{T}) = pairwise(κ, x, y)

kernel{T<:AbstractFloat}(κ::ARD{T}, x::T, y::T) = pairwise(κ.k, x, y, κ.w[1])
kernel{T<:AbstractFloat}(κ::ARD{T}, x::Vector{T}, y::Vector{T}) = pairwise(κ.k, x, y, κ.w)

kernel{T<:AbstractFloat}(κ::CompositeKernel{T}, x::T, y::T) = phi(κ, pairwise(κ.k, x, y))
kernel{T<:AbstractFloat}(κ::CompositeKernel{T}, x::Vector{T}, y::Vector{T}) = phi(κ, pairwise(κ.k, x, y))

kernel{T<:AbstractFloat}(ψ::KernelSum{T}, x::T, y::T) = sum(ψ.a, sym(map(κ -> kernel(κ,x,y), ψ.k)))
kernel{T<:AbstractFloat}(ψ::KernelSum{T}, x::Vector{T}, y::Vector{T}) = sum(ψ.a, sym(map(κ -> kernel(κ,x,y), ψ.k)))

kernel{T<:AbstractFloat}(ψ::KernelProduct{T}, x::T, y::T) = sum(ψ.a, sym(map(κ -> kernel(κ,x,y), ψ.k)))
kernel{T<:AbstractFloat}(ψ::KernelProduct{T}, x::Vector{T}, y::Vector{T}) = prod(ψ.a, prod(map(κ -> kernel(κ,x,y), ψ.k)))


#==========================================================================
  Kernel Matrix Transformation
==========================================================================#

# Centralize a kernel matrix K
function center_kernelmatrix!{T<:AbstractFloat}(K::Matrix{T})
    (n = size(K, 1)) == size(K, 2) || error("Kernel matrix must be square")
    row_mean = sum(K, 1)
    element_mean = sum(row_mean) / (convert(T, n)^2)
    BLAS.scal!(n, one(T)/convert(T,n), row_mean, 1)
    ((K .- row_mean) .- row_mean') .+ element_mean
end
center_kernelmatrix{T<:AbstractFloat}(K::Matrix{T}) = center_kernelmatrix!(copy(K))


#==========================================================================
  Generic Kernel Matrix Functions
==========================================================================#

function kernelmatrix{T<:AbstractFloat}(κ::Kernel{T}, X::Matrix{T}, is_trans::Bool = false, store_upper::Bool = true, symmetrize::Bool = true)
    kernelmatrix!(init_pairwise(X, is_trans), κ, X, is_trans, store_upper, symmetrize)
end
kernelmatrix{T<:AbstractFloat}(κ::Kernel{T}, X::Matrix{T}; is_trans::Bool = false, store_upper::Bool = true, symmetrize::Bool = true) = kernelmatrix(κ, X, is_trans, store_upper, symmetrize)


function kernelmatrix{T<:AbstractFloat}(κ::Kernel{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    kernelmatrix!(init_pairwise(X, Y, is_trans), κ, X, Y, is_trans)
end
kernelmatrix{T<:AbstractFloat}(κ::Kernel{T}, X::Matrix{T}, Y::Matrix{T}; is_trans::Bool = false) = kernelmatrix(κ, X, Y, is_trans)


#==========================================================================
  Base Kernel Matrix Functions
==========================================================================#

function kernelmatrix!{T<:AbstractFloat}(K::Matrix{T}, κ::BaseKernel{T}, X::Matrix{T}, is_trans::Bool, store_upper::Bool, symmetrize::Bool)
    pairwise!(K, κ, X, is_trans, store_upper)
    symmetrize ? (store_upper ? syml!(K) : symu!(K)) : K
end

function kernelmatrix!{T<:AbstractFloat}(K::Matrix{T}, κ::BaseKernel{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool)
    pairwise!(K, κ, X, Y, is_trans)
end


#==========================================================================
  Composite Kernel Matrix Functions
==========================================================================#


function kernelmatrix!{T<:AbstractFloat}(K::Matrix{T}, κ::CompositeKernel{T}, X::Matrix{T}, is_trans::Bool, store_upper::Bool, symmetrize::Bool)
    pairwise!(K, κ.k, X, is_trans, store_upper)
    phi_square_matrix!(κ, K, store_upper)
    symmetrize ? (store_upper ? syml!(K) : symu!(K)) : K
end

function kernelmatrix!{T<:AbstractFloat}(K::Matrix{T}, κ::CompositeKernel{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool)
    pairwise!(K, κ.k, X, Y, is_trans)
    phi_matrix!(κ, K)
end


#==========================================================================
  Combination Kernel Matrix Functions
==========================================================================#

for (kernel_object, matrix_op, array_op, identity) in (
        (:KernelProduct, :matrix_prod!, :scale!,     :1),
        (:KernelSum,     :matrix_sum!,  :translate!, :0)
    )
    @eval begin

        function kernelmatrix!{T<:AbstractFloat}(K::Matrix{T}, κ::$kernel_object{T}, X::Matrix{T}, is_trans::Bool, store_upper::Bool, symmetrize::Bool)
            c = length(κ.k)
            kernelmatrix!(K, κ.k[1], X, is_trans, store_upper, false)
            if c > 1
                K_factor = similar(K)
                for i = 2:c
                    ($matrix_op)(K, kernelmatrix!(K_factor, κ.k[i], X, is_trans, store_upper, false), store_upper, false)
                end
            end
            K = symmetrize ? (store_upper ? syml!(K) : symu!(K)) : K
            κ.a == $identity ? K : ($array_op)(κ.a, K)
        end

        function kernelmatrix!{T<:AbstractFloat}(K::Matrix{T}, κ::$kernel_object{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool)
            c = length(κ.k)
            kernelmatrix!(K, κ.k[1], X, Y, is_trans)
            if c > 1
                K_factor = similar(K)
                for i = 2:c
                    ($matrix_op)(K, kernelmatrix!(K_factor, κ.k[i], X, Y, is_trans))
                end
            end
            κ.a == $identity ? K : ($array_op)(κ.a, K)
        end

    end
end
