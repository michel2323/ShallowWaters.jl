function time_integration_debug(S::ModelSetup{T,Tprog}) where {T<:AbstractFloat,Tprog<:AbstractFloat}

    Diag = S.Diag
    Prog = S.Prog

    @unpack u,v,η,sst = Prog
    @unpack u0,v0,η0 = Diag.RungeKutta
    @unpack u1,v1,η1 = Diag.RungeKutta
    @unpack du,dv,dη = Diag.Tendencies
    @unpack du_sum,dv_sum,dη_sum = Diag.Tendencies
    @unpack du_comp,dv_comp,dη_comp = Diag.Tendencies

    @unpack um,vm = Diag.SemiLagrange

    @unpack dynamics,RKo,RKs,tracer_advection = S.parameters
    @unpack time_scheme,compensated = S.parameters
    @unpack RKaΔt,RKbΔt = S.constants
    @unpack Δt_Δ,Δt_Δs = S.constants

    @unpack nt,dtint = S.grid
    @unpack nstep_advcor,nstep_diff,nadvstep,nadvstep_half = S.grid

    # calculate layer thicknesses for initial conditions
    thickness!(Diag.VolumeFluxes.h,η,S.forcing.H)
    Ix!(Diag.VolumeFluxes.h_u,Diag.VolumeFluxes.h)
    Iy!(Diag.VolumeFluxes.h_v,Diag.VolumeFluxes.h)
    Ixy!(Diag.Vorticity.h_q,Diag.VolumeFluxes.h)

    # calculate PV terms for initial conditions
    urhs = convert(Diag.PrognosticVarsRHS.u,u)
    vrhs = convert(Diag.PrognosticVarsRHS.v,v)
    ηrhs = convert(Diag.PrognosticVarsRHS.η,η)

    advection_coriolis!(urhs,vrhs,ηrhs,Diag,S)
    #     @unpack h = Diag.VolumeFluxes
    #     @unpack h_q,dvdx,dudy = Diag.Vorticity
    #     @unpack u²,v²,KEu,KEv = Diag.Bernoulli
    #     @unpack ep,f_q = S.grid

    #     Ixy!(h_q,h)

    #     # off-diagonals of stress tensor ∇(u,v)
    #     ∂x!(dvdx,vrhs)
    #     ∂y!(dudy,urhs)

    #     # non-linear part of the Bernoulli potential
    #     # speed!(u²,v²,urhs,vrhs)
    #     m,n = size(u²)
    #     @boundscheck (m,n) == size(urhs) || throw(BoundsError())

    #     @inbounds for i in eachindex(urhs)
    #         u²[i] = urhs[i]^2
    #     end

    #     m,n = size(v²)
    #     @boundscheck (m,n) == size(vrhs) || throw(BoundsError())

    #     @inbounds for i in eachindex(vrhs)
    #         v²[i] = vrhs[i]^2
    #     end

    #     Ix!(KEu,u²)
    #     Iy!(KEv,v²)

    #     # Potential vorticity update (PV!)
    #     @unpack q,dvdx,dudy,h_q = Diag.Vorticity
    #     @unpack f_q,ep = S.grid

    #     m,n = size(q)
    #     @boundscheck (m,n) == size(f_q) || throw(BoundsError())
    #     @boundscheck (m+2,n+2) == size(dvdx) || throw(BoundsError())
    #     @boundscheck (m+2+ep,n+2) == size(dudy) || throw(BoundsError())
    #     @boundscheck (m,n) == size(h_q) || throw(BoundsError())

    #     @inbounds for j ∈ 1:n
    #         for i ∈ 1:m
    #             q[i,j] = (f_q[i,j] + dvdx[i+1,j+1] - dudy[i+1+ep,j+1]) / h_q[i,j]
    #         end
    #     end

    #     @unpack q = Diag.Vorticity          # now load what just has been calculated

    #     # Linear combinations of the potential vorticity q
    #     if S.parameters.adv_scheme == "Sadourny"
    #         @unpack q_u,q_v = Diag.Vorticity
    #         Iy!(q_u,q)
    #         Ix!(q_v,q)
    #     elseif S.parameters.adv_scheme == "ArakawaHsu"
    #         @unpack qα,qβ,qγ,qδ = Diag.ArakawaHsu
    #         AHα!(qα,q)
    #         AHβ!(qβ,q)
    #         AHγ!(qγ,q)
    #         AHδ!(qδ,q)
    #     end

    # ### end of inlined advection_coriolis #################

    PVadvection!(Diag,S)
    #     if S.parameters.adv_scheme == "Sadourny"
    #         @unpack U,V = Diag.VolumeFluxes
    #         @unpack V_u,U_v = Diag.Vorticity
    #         @unpack q_u,q_v,qhv,qhu,ep = Diag.Vorticity

    #         Ixy!(V_u,V)
    #         Ixy!(U_v,U)

    #         m,n = size(qhv)
    #         @boundscheck (m+2-ep,n) == size(q_u) || throw(BoundsError())
    #         @boundscheck (m+2-ep,n) == size(V_u) || throw(BoundsError())

    #         @inbounds for j ∈ 1:n
    #             for i ∈ 1:m
    #                 qhv[i,j] = q_u[i+1-ep,j] * V_u[i+1-ep,j]
    #             end
    #         end

    #         m,n = size(qhu)
    #         @boundscheck (m,n+2) == size(q_v) || throw(BoundsError())
    #         @boundscheck (m,n+2) == size(U_v) || throw(BoundsError())

    #         @inbounds for j ∈ 1:n
    #             for i ∈ 1:m
    #                 qhu[i,j] = q_v[i,j+1] * U_v[i,j+1]
    #             end
    #         end
    #     elseif S.parameters.adv_scheme == "ArakawaHsu"
    #         @unpack U,V = Diag.VolumeFluxes
    #         @unpack qhv,qhu,ep = Diag.Vorticity
    #         @unpack qα,qβ,qγ,qδ = Diag.ArakawaHsu
        
    #         # Linear combinations of q and V=hv to yield qhv
    #         m,n = size(qhv)
    #         @inbounds for j ∈ 1:n
    #             for i ∈ 1:m
    #                 qhv[i,j] = qα[1-ep+i,j]*V[2-ep+i,j+1] + qβ[1-ep+i,j]*V[1-ep+i,j+1] + qγ[1-ep+i,j]*V[1-ep+i,j] + qδ[1-ep+i,j]*V[2-ep+i,j]
    #             end
    #         end
        
    #         # Linear combinations of q and U=hu to yield qhu
    #         m,n = size(qhu)
    #         @inbounds for j ∈ 1:n
    #             for i ∈ 1:m
    #                 qhu[i,j] = qα[i,j]*U[i,j+1] + qβ[i+1,j]*U[i+1,j+1] + qγ[i+1,j+1]*U[i+1,j+2] + qδ[i,j+1]*U[i,j+2]
    #             end
    #         end
    #     end
    # ### end of inlined PVadvection!

    # propagate initial conditions
    copyto!(u0,u)
    copyto!(v0,v)
    copyto!(η0,η)

    # store initial conditions of sst for relaxation
    copyto!(Diag.SemiLagrange.sst_ref,sst)

    # adding causes bug in Enzyme, don't really need these functions
    # (or at least it doesn't seem like I do)
    # feedback, output initialisation and storing initial conditions
    # feedback = feedback_init(S)
    # netCDFfiles = NcFiles(feedback,S)
    # output_nc!(0,netCDFfiles,Prog,Diag,S)

    nans_detected = false
    t = 0           # model time
    for i = 1:nt

        # ghost point copy for boundary conditions
        ghost_points!(u,v,η,S)
        copyto!(u1,u)
        copyto!(v1,v)
        copyto!(η1,η)

        if time_scheme == "RK"   # classic RK4,3 or 2

            if compensated
                fill!(du_sum,zero(Tprog))
                fill!(dv_sum,zero(Tprog))
                fill!(dη_sum,zero(Tprog))
            end

            for rki = 1:RKo
                if rki > 1
                    ghost_points!(u1,v1,η1,S)
                end

                # type conversion for mixed precision
                u1rhs = convert(Diag.PrognosticVarsRHS.u,u1)
                v1rhs = convert(Diag.PrognosticVarsRHS.v,v1)
                η1rhs = convert(Diag.PrognosticVarsRHS.η,η1)

                rhs!(u1rhs,v1rhs,η1rhs,Diag,S,t)          # momentum only
                continuity!(u1rhs,v1rhs,η1rhs,Diag,S,t)   # continuity equation 

                if rki < RKo
                    caxb!(u1,u,RKbΔt[rki],du)   #u1 .= u .+ RKb[rki]*Δt*du
                    caxb!(v1,v,RKbΔt[rki],dv)   #v1 .= v .+ RKb[rki]*Δt*dv
                    caxb!(η1,η,RKbΔt[rki],dη)   #η1 .= η .+ RKb[rki]*Δt*dη
                end

                if compensated      # accumulate tendencies
                    axb!(du_sum,RKaΔt[rki],du)   
                    axb!(dv_sum,RKaΔt[rki],dv)
                    axb!(dη_sum,RKaΔt[rki],dη)
                else    # sum RK-substeps on the go
                    axb!(u0,RKaΔt[rki],du)          #u0 .+= RKa[rki]*Δt*du
                    axb!(v0,RKaΔt[rki],dv)          #v0 .+= RKa[rki]*Δt*dv
                    axb!(η0,RKaΔt[rki],dη)          #η0 .+= RKa[rki]*Δt*dη
                end
            end

            if compensated
                # add compensation term to total tendency
                axb!(du_sum,-1,du_comp)             
                axb!(dv_sum,-1,dv_comp)
                axb!(dη_sum,-1,dη_comp)

                axb!(u0,1,du_sum)   # update prognostic variable with total tendency
                axb!(v0,1,dv_sum)
                axb!(η0,1,dη_sum)
                
                dambmc!(du_comp,u0,u,du_sum)    # compute new compensation
                dambmc!(dv_comp,v0,v,dv_sum)
                dambmc!(dη_comp,η0,η,dη_sum)
            end

        elseif time_scheme == "SSPRK2"  # s-stage 2nd order SSPRK

            for rki = 1:RKs
                if rki > 1
                    ghost_points_η!(η1,S)
                end

                # type conversion for mixed precision
                u1rhs = convert(Diag.PrognosticVarsRHS.u,u1)
                v1rhs = convert(Diag.PrognosticVarsRHS.v,v1)
                η1rhs = convert(Diag.PrognosticVarsRHS.η,η1)

                rhs!(u1rhs,v1rhs,η1rhs,Diag,S,t)        # momentum only

                # the update step
                axb!(u1,Δt_Δs,du)       # u1 = u1 + Δt/(s-1)*RHS(u1)
                axb!(v1,Δt_Δs,dv)

                # semi-implicit for continuity equation, use new u1,v1 to calcualte dη
                ghost_points_uv!(u1,v1,S)
                u1rhs = convert(Diag.PrognosticVarsRHS.u,u1)
                v1rhs = convert(Diag.PrognosticVarsRHS.v,v1)
                continuity!(u1rhs,v1rhs,η1rhs,Diag,S,t)
                axb!(η1,Δt_Δs,dη)       # η1 = η1 + Δt/(s-1)*RHS(u1)
            end

            a = 1/RKs
            b = (RKs-1)/RKs
            cxayb!(u0,a,u,b,u1)
            cxayb!(v0,a,v,b,v1)
            cxayb!(η0,a,η,b,η1)
        
        elseif time_scheme == "SSPRK3"  # s-stage 3rd order SSPRK

            @unpack s,kn,mn,kna,knb,Δt_Δnc,Δt_Δn = S.constants.SSPRK3c

            # if compensated
            #     fill!(du_sum,zero(Tprog))
            #     fill!(dv_sum,zero(Tprog))
            #     fill!(dη_sum,zero(Tprog))
            # end

            for rki = 2:s+1       # number of stages (from 2:s+1 to match Ketcheson et al 2014)
                if rki > 2
                    ghost_points_η!(η1,S)
                end

                # type conversion for mixed precision
                u1rhs = convert(Diag.PrognosticVarsRHS.u,u1)
                v1rhs = convert(Diag.PrognosticVarsRHS.v,v1)
                η1rhs = convert(Diag.PrognosticVarsRHS.η,η1)

                rhs!(u1rhs,v1rhs,η1rhs,Diag,S,t)

                if rki == kn    # special case combining more previous stages  
                    dxaybzc!(u1,kna,u1,knb,u0,Δt_Δnc,du)
                    dxaybzc!(v1,kna,v1,knb,v0,Δt_Δnc,dv)
                else                                # normal update case
                    axb!(u1,Δt_Δn,du)   
                    axb!(v1,Δt_Δn,dv)

                    # if compensated
                    #     axb!(du_sum,Δt_Δn,du)   
                    #     axb!(dv_sum,Δt_Δn,dv)
                    # end
                end

                # semi-implicit for continuity equation, use new u1,v1 to calcualte dη
                ghost_points_uv!(u1,v1,S)
                u1rhs = convert(Diag.PrognosticVarsRHS.u,u1)
                v1rhs = convert(Diag.PrognosticVarsRHS.v,v1)
                continuity!(u1rhs,v1rhs,η1rhs,Diag,S,t)

                if rki == kn
                    dxaybzc!(η1,kna,η1,knb,η0,Δt_Δnc,dη)
                else
                    axb!(η1,Δt_Δn,dη)
                    # if compensated
                    #     axb!(dη_sum,Δt_Δn,dη)
                    # end
                end

                # special stage that is needed later for the kn-th stage, store in u0,v0,η0 therefore
                # or for the last step, as u0,v0,η0 is used as the last step's result of any RK scheme.
                if rki == mn || rki == s+1
                    copyto!(u0,u1)
                    copyto!(v0,v1)
                    ghost_points_η!(η1,S)
                    copyto!(η0,η1)
                end
            end
            
        elseif time_scheme == "4SSPRK3"   # 4-stage SSPRK3
        
            for rki = 1:4
                if rki > 1
                    ghost_points!(u1,v1,η1,S)
                end

                # type conversion for mixed precision
                u1rhs = convert(Diag.PrognosticVarsRHS.u,u1)
                v1rhs = convert(Diag.PrognosticVarsRHS.v,v1)
                η1rhs = convert(Diag.PrognosticVarsRHS.η,η1)

                rhs!(u1rhs,v1rhs,η1rhs,Diag,S,t)

                caxb!(u0,u1,Δt_Δ,du)        # store Euler update into u0,v0
                caxb!(v0,v1,Δt_Δ,dv)
                cxab!(u1,1/2,u1,u0)         # average u0,u1 and store in u1
                cxab!(v1,1/2,v1,v0)         # same

                # semi-implicit for continuity equation, use u1,v1 to calcualte dη
                ghost_points_uv!(u1,v1,S)
                u1rhs = convert(Diag.PrognosticVarsRHS.u,u1)
                v1rhs = convert(Diag.PrognosticVarsRHS.v,v1)
                continuity!(u1rhs,v1rhs,η1rhs,Diag,S,t)
                
                caxb!(η0,η1,Δt_Δ,dη)    # store Euler update into η0
                cxab!(η1,1/2,η1,η0)         # average η0,η1 and store in η1

                if rki == 3
                    cxayb!(u1,2/3,u,1/3,u1)
                    cxayb!(v1,2/3,v,1/3,v1)
                    cxayb!(η1,2/3,η,1/3,η1)
                elseif rki == 4
                    copyto!(u0,u1)
                    copyto!(v0,v1)
                    copyto!(η0,η1)
                end
            end
        end

        ghost_points!(u0,v0,η0,S)

        # type conversion for mixed precision
        u0rhs = convert(Diag.PrognosticVarsRHS.u,u0)
        v0rhs = convert(Diag.PrognosticVarsRHS.v,v0)
        η0rhs = convert(Diag.PrognosticVarsRHS.η,η0)

        # ADVECTION and CORIOLIS TERMS
        # although included in the tendency of every RK substep,
        # only update every nstep_advcor steps if nstep_advcor > 0
        if dynamics == "nonlinear" && nstep_advcor > 0 && (i % nstep_advcor) == 0
            UVfluxes!(u0rhs,v0rhs,η0rhs,Diag,S)
            advection_coriolis!(u0rhs,v0rhs,η0rhs,Diag,S)
        end

        # DIFFUSIVE TERMS - SEMI-IMPLICIT EULER
        # use u0 = u^(n+1) to evaluate tendencies, add to u0 = u^n + rhs
        # evaluate only every nstep_diff time steps
        if (i % nstep_diff) == 0
            bottom_drag!(u0rhs,v0rhs,η0rhs,Diag,S)
            diffusion!(u0rhs,v0rhs,Diag,S)
            add_drag_diff_tendencies!(u0,v0,Diag,S)
            ghost_points_uv!(u0,v0,S)
        end

        t += dtint

        # TRACER ADVECTION
        u0rhs = convert(Diag.PrognosticVarsRHS.u,u0)  # copy back as add_drag_diff_tendencies changed u0,v0
        v0rhs = convert(Diag.PrognosticVarsRHS.v,v0)
        tracer!(i,u0rhs,v0rhs,Prog,Diag,S)

        # # feedback and output
        # feedback.i = i
        # feedback!(Prog,feedback,S)
        # output_nc!(i,netCDFfiles,Prog,Diag,S)       # uses u0,v0,η0

        # if feedback.nans_detected
        #     break
        # end

        # Copy back from substeps
        copyto!(u,u0)
        copyto!(v,v0)
        copyto!(η,η0)
    end

    # # finalise feedback and output
    # feedback_end!(feedback)
    # output_close!(netCDFfiles,feedback,S)

    # if S.parameters.return_time
    #     return feedback.tend - feedback.t0
    # else
    #     return PrognosticVars{Tprog}(remove_halo(u,v,η,sst,S)...)
    # end

    return nothing

end