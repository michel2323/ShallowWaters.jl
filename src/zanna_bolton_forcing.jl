"""
This function will compute an additional forcing term S that will (hopefully) act
as the eddy parameterization. I'm doing this by 
(1) Adding a new structure that will preallocate all of the operators I need (called ZB_momentum)
(2) Computing the main operators that appear in the new term: ζ, D, Dhat. ζ is the relative vorticity,
D is the shear deformation of the flow field (both of these live on cell corners), and Dhat is the stretch
deformation of the flow field (this lives on the cell centers). The computation of these operators was 
extensively checked for accuracy by MK and SW
(3) Using ζ, D, and Dhat, then compute the individual pieces of S that appear, comments
below explain on which grid they live and so on

There is also an option to apply a filter to S. The first few inline functions relate to this 
operation. The application of the filter (or convolutional kernal) is done in three stages: 
(1) applying the filter only to the internal points
(2) applying the filter to points on the boundary, not including corners
(3) applying the filter to points on the corners
"""

@inline function Gconvolve(array)
    return (array[1, 1] + 2*array[1, 2] + array[1, 3] + 2*array[2, 1] + 4*array[2, 2] + 2*array[2, 3] + array[3, 1] + 2*array[3, 2] + array[3, 3]) / 16
end
@inline function Gconvolve12all(array)
    return (array[1, 1] + 2*array[1, 2] + array[1, 3] + 2*array[2, 1] + 4*array[2, 2] + 2*array[2, 3]) / 12
end
@inline function Gconvolve23all(array)
    return (2*array[1, 1] + 4*array[1, 2] + 2*array[1, 3] + array[2, 1] + 2*array[2, 2] + array[2, 3]) / 12
end
@inline function Gconvolveall12(array)
    return (array[1, 1] + 2*array[1, 2] + 2*array[2, 1] + 4*array[2, 2] + array[3, 1] + 2*array[3, 2]) / 12
end
@inline function Gconvolveall23(array)
    return (2*array[1, 1] + array[1, 2] + 4*array[2, 1] + 2*array[2, 2] + 2*array[3, 1] + array[3, 2]) / 12
end

function ZB_momentum(u, v, S, Diag)

    @unpack γ₀, zb_filtered, N  = S.parameters
    @unpack ζ, ζsq, D, Dsq, Dhat, Dhatsq, Dhatq = Diag.ZBVars
    @unpack ζD, ζDT, ζDhat, ζsqT, trace = Diag.ZBVars
    @unpack ζpDT = Diag.ZBVars
    @unpack dudx, dudy, dvdx, dvdy = Diag.ZBVars

    @unpack dζDdx, dζDhatdy, dtracedx = Diag.ZBVars
    @unpack dζDhatdx, dζDdy, dtracedy = Diag.ZBVars
    @unpack S_u, S_v = Diag.ZBVars
    @unpack Δ, scale, f₀ = S.grid

    @unpack G = Diag.ZBVars
    @unpack ζD_filtered, ζDhat_filtered, trace_filtered = Diag.ZBVars

    @unpack halo, haloη, ep, nux, nuy, nvx, nvy = S.grid

    κ_BC = - γ₀ * Δ^2

    ∂x!(dudx, u)
    ∂y!(dudy, u)

    ∂x!(dvdx, v)
    ∂y!(dvdy, v)

    mq,nq = size(ζ)
    mTh,nTh = size(Dhat)
    mT,nT = size(trace)

    ##### CHECK #########
    @boundscheck (mq+2,nq+2) == size(dvdx) || throw(BoundsError())
    @boundscheck (mTh+1,nTh+1) == size(dvdx) || throw(BoundsError())
    @boundscheck (mq+2+ep,nq+2) == size(dudy) || throw(BoundsError())
    
    # Relative vorticity and shear deformation, cell corners
    @inbounds for j ∈ 1:nq
        for k ∈ 1:mq
            ζ[k,j] = dvdx[k+1,j+1] - dudy[k+1,j+1]
            D[k,j] = dudy[k+1,j+1] + dvdx[k+1,j+1]
        end
    end

    # Stretch deformation, cell centers (with halo)
    @inbounds for j ∈ 1:nTh
        for k ∈ 1:mTh
            Dhat[k,j] = dudx[k,j+1] - dvdy[k+1,j]
        end
    end
    
    ζsq .= κ_BC .* ζ.^2
    Dsq .= D.^2
    Dhatsq .= Dhat.^2

    # Trace computation (second term in forcing term), only keeping ζ^2 and no other terms
    # Ixy!(ξpDT, ξsq + Dsq)
    Ixy!(ζsqT, ζsq)

    # Computing ζ ⋅ D and placing on cell centers
    ζD .= κ_BC .* (ζ .* D)
    Ixy!(ζDT, ζD)

    # Computing ζ ⋅ Dhat, cell corners
    Ixy!(Dhatq, Dhat)
    for j ∈ 1:nq
        for k ∈ 1:mq 
            ζDhat[k,j] = κ_BC * ζ[k,j] * Dhatq[k,j]
        end
    end
    # for kj in eachindex(ζDhat,ζ,Dhatq) 
    #     ζDhat[kj] = κ_BC * ζ[kj] * Dhatq[kj]
    # end

    if zb_filtered

        for i = 1:N

            for j ∈ 2:nT-1 
                for k ∈ 2:mT-1 
                    ζsqT[k,j] = Gconvolve(@view ζsqT[k-1:k+1,j-1:j+1])
                    ζDT[k,j] = Gconvolve(@view ζDT[k-1:k+1,j-1:j+1])
                end
            end

            for h ∈ 2:nT-1
                ζsqT[1,h] = Gconvolve23all(@view ζsqT[1:2,h-1:h+1])
                ζsqT[mT,h] = Gconvolve12all(@view ζsqT[mT-1:mT,h-1:h+1])
                ζDT[1,h] = Gconvolve23all(@view ζDT[1:2,h-1:h+1])
                ζDT[mT,h] = Gconvolve12all(@view ζDT[mT-1:mT,h-1:h+1])
            end

            for v ∈ 2:mT-1
                ζsqT[v,1] = Gconvolveall23(ζsqT[v-1:v+1,1:2])
                ζsqT[v,nT] = Gconvolveall12(ζsqT[v-1:v+1,nT-1:nT])
                ζDT[v,1] = Gconvolveall23(ζDT[v-1:v+1,1:2])
                ζDT[v,nT] = Gconvolveall12(ζDT[v-1:v+1,nT-1:nT])
            end

            ζsqT[1,1] = (4*ζsqT[1,1] + 2*ζsqT[1,2] + 2*ζsqT[2,1] + ζsqT[2,2])/8
            ζsqT[1,nT] = (2*ζsqT[1,nT-1] + 4*ζsqT[1,nT] + ζsqT[2,nT-1] + 2*ζsqT[2,nT])/8
            ζsqT[mT,1] = (2*ζsqT[mT-1,1] + ζsqT[mT-1,2] + 4*ζsqT[mT,1] + 2*ζsqT[mT,2])/8
            ζsqT[mT,nT] = (ζsqT[mT-1,nT-1] + 2*ζsqT[mT-1,nT] + 2*ζsqT[mT,nT-1] + 4*ζsqT[mT,nT])/8

            ζDT[1,1] = (4*ζDT[1,1] + 2*ζDT[1,2] + 2*ζDT[2,1] + ζDT[2,2])/8
            ζDT[1,nT] = (2*ζDT[1,nT-1] + 4*ζDT[1,nT] + ζDT[2,nT-1] + 2*ζDT[2,nT])/8
            ζDT[mT,1] = (2*ζDT[mT-1,1] + ζDT[mT-1,2] + 4*ζDT[mT,1] + 2*ζDT[mT,2])/8
            ζDT[mT,nT] = (ζDT[mT-1,nT-1] + 2*ζDT[mT-1,nT] + 2*ζDT[mT,nT-1] + 4*ζDT[mT,nT])/8

            for j ∈ 2:nq-1
                for k ∈ 2:mq-1
                    ζDhat[k,j] = Gconvolve(@view ζDhat[k-1:k+1,j-1:j+1])
                end
            end

            for h ∈ 2:nq-1
                ζDhat[1,h] = Gconvolve23all(ζDhat[1:2,h-1:h+1])
                ζDhat[mq,h] = Gconvolve12all(ζDhat[mq-1:mq,h-1:h+1])
            end

            for v ∈ 2:mq-1
                ζDhat[v,1] = Gconvolveall23(ζDhat[v-1:v+1,1:2])
                ζDhat[v,nq] = Gconvolveall12(ζDhat[v-1:v+1,nq-1:nq])
            end

            ζDhat[1,1] = (4*ζDhat[1,1] + 2*ζDhat[1,2] + 2*ζDhat[2,1] + ζDhat[2,2])/8
            ζDhat[1,nq] = (2*ζDhat[1,nq-1] + 4*ζDhat[1,nq] + ζDhat[2,nq-1] + 2*ζDhat[2,nq])/8
            ζDhat[mq,1] = (2*ζDhat[mq-1,1] + ζDhat[mq-1,2] + 4*ζDhat[mq,1] + 2*ζDhat[mq,2])/8
            ζDhat[mq,nq] = (ζDhat[mq-1,nq-1] + 2*ζDhat[mq-1,nq] + 2*ζDhat[mq,nq-1] + 4*ζDhat[mq,nq])/8

            trace_filtered .= ζsqT
            ζD_filtered .= ζDT
            ζDhat_filtered .= ζDhat

        end

        ∂x!(dζDdx, ζD_filtered)
        ∂y!(dζDhatdy, ζDhat_filtered)
        ∂x!(dtracedx, trace_filtered)
    
        ∂x!(dζDhatdx, ζDhat_filtered)
        ∂y!(dζDdy, ζD_filtered)
        ∂y!(dtracedy, trace_filtered)

    else

        ∂x!(dζDdx, ζDT)
        ∂y!(dζDhatdy, ζDhat)
        ∂x!(dtracedx, ζsqT)
    
        ∂x!(dζDhatdx, ζDhat)
        ∂y!(dζDdy, ζDT)
        ∂y!(dtracedy, ζsqT)

    end

    s = Δ^2 * scale
    # for kj in eachindex(S_u,dζDdx,temp,dtracedx)
    for j ∈ 1:nuy
        for k ∈ 1:nux
            S_u[k,j] = (-dζDdx[k,j] + dζDhatdy[k+1,j] + dtracedx[k,j]) / s
        end
    end

    # for kj in eachindex(S_v,dζDdy,dtracedy)
    for j ∈ 1:nvy
        for k ∈ 1:nvx
            S_v[k,j] = (dζDhatdx[k,j+1] + dζDdy[k,j] + dtracedy[k,j]) / s
        end
    end

end

# from a prior, different version of computing the S operators 

# @unpack D_n, D_nT, D_q = Diag.ZBVars

# ∂x!(dudx, u)
# ∂y!(dudy, u)

# ∂x!(dvdx, v)
# ∂y!(dvdy, v)

# mq,nq = size(ζ)
# mTh,nTh = size(Dhat)
# mT,nT = size(trace)

# @boundscheck (mq+2,nq+2) == size(dvdx) || throw(BoundsError())
# @boundscheck (mTh+1,nTh+1) == size(dvdx) || throw(BoundsError())
# @boundscheck (mq+2+ep,nq+2) == size(dudy) || throw(BoundsError())

# # Relative vorticity and shear deformation, cell corners
# @inbounds for j ∈ 1:nq
#     for k ∈ 1:mq
#         ζ[k,j] = dvdx[k+1,j+1] - dudy[k+1,j+1]
#     end
# end

# # Shear deformation, cell corners with halo (131,131)
# m_temp,n_temp = size(D_n)
# @inbounds for j ∈ 1:n_temp
#     for i ∈ 1:m_temp
#         D_n[i,j] = dudy[i+ep,j] + dvdx[i,j]
#     end
# end

# # Move to cell centers with halo (130,130)
# Ixy!(D_nT, D_n)

# # Stretch deformation, cell centers (with halo) (130,130)
# @inbounds for j ∈ 1:nTh
#     for k ∈ 1:mTh
#         Dhat[k,j] = dudx[k,j+1] - dvdy[k+1,j]
#     end
# end

# ξsq .= ζ.^2 

# # Last interpolation of D, moving to corners without halo
# Ixy!(D_q, D_nT)

# # Move ζ^2 to cell centers (128,128)
# Ixy!(ξsqT, ξsq)

# # Computing ζ ⋅ D and placing on cell centers 
# Ixy!(ξD, ζ .* D_q)

# # Computing ζ ⋅ Dhat, cell corners 
# Ixy!(Dhatq, Dhat)
# @inbounds for j ∈ 1:nq
#     for k ∈ 1:mq 
#         ξDhat[k,j] = ζ[k,j] * Dhatq[k,j]
#     end
# end

# # Computing final derivatives of everything
# ∂x!(dξDdx, ξD)
# ∂y!(dξDhatdy, ξDhat)
# ∂x!(dtracedx, ξsqT)

# ∂x!(dξDhatdx, ξDhat)
# ∂y!(dξDdy, ξD)
# ∂y!(dtracedy, ξsqT)

# temp = (dξDhatdy[2:end-1,:])
# s = Δ^2 * scale
# @inbounds for j ∈ 1:nuy
#     for k ∈ 1:nux
#         S_u[k,j] = κ_BC * (-dξDdx[k,j] + temp[k,j] + dtracedx[k,j]) / s
#     end
# end

# temp2 = dξDhatdx[:,2:end-1]
# @inbounds for j ∈ 1:nvy
#     for k ∈ 1:nvx
#         S_v[k,j] = κ_BC * (temp2[k,j] + dξDdy[k,j] + dtracedy[k,j]) / s
#     end
# end

# from prior attempt to implement a different version of κ_BC, will still have a tunable parameter
# made a mistake, this is largely for numerical stability and not for actually 
# correcting how much energy is injected into the model 
# @inbounds for j ∈ 1:nT 
#     for k ∈ 1:mT
#         γ[k,j] = γ₀ * (1 + (sqrt(trace[k,j])/abs(f₀)))^(-1)
#     end
# end
# Ix!(γ_u,γ)
# Iy!(γ_v,γ)

### for adding additional trace terms 
# @inbounds for j ∈ 1:nT 
#     for k ∈ 1:mT
#         trace[k,j] = ξpDT[k,j] + Dhatsq[k+1,j+1]
#     end
# end