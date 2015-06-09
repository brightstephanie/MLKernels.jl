#===================================================================================================
  Kernel Functions Module
===================================================================================================#

module MLKernels

import Base: show, eltype, convert, promote #, call

export
    # Functions
    ismercer,
    iscondposdef,
    kernel,
    kernelmatrix,
    center_kernelmatrix!,
    center_kernelmatrix,
    nystrom,

    # Kernel Types
    Kernel,
        SimpleKernel,
            StandardKernel,
                SquaredDistanceKernel,
                    ExponentialKernel,
                    RationalQuadraticKernel,
                    PowerKernel,
                    LogKernel,
                    MaternKernel,
                ScalarProductKernel,
                    PolynomialKernel,
                    SigmoidKernel,
            ARD,
        CompositeKernel,
            KernelProduct,
            KernelSum

include("meta.jl")
include("auxfunctions.jl")
include("kernels.jl")
include("kernelmatrix.jl")
#include("kernelmatrixapprox.jl")

end # MLKernels
