using Enzyme
using ForwardDiff
using Parameters
using ShallowWaters

abstract type AbstractDifferentiation end

struct Passive <: AbstractDifferentiation end
struct Forward <: AbstractDifferentiation end
struct Reverse <: AbstractDifferentiation end

function ShallowWaters.run_model(::Type{T}, ::Passive; kwargs...) where {T<:AbstractFloat}

    P = Parameter(T=T;kwargs...)
    @unpack Tprog = P

    G = ShallowWaters.Grid{T,Tprog}(P)
    C = ShallowWaters.Constants{T,Tprog}(P,G)
    F = ShallowWaters.Forcing{T}(P,G)
    S = ShallowWaters.ModelSetup{T,Tprog}(P,G,C,F)

    Prog = ShallowWaters.initial_conditions(Tprog,S)
    Diag = ShallowWaters.preallocate(T,Tprog,G)

    Prog = ShallowWaters.time_integration(Prog,Diag,S)
    return Prog
end

function ShallowWaters.run_model(::Type{T_}, ::Forward; kwargs...) where {T_<:AbstractFloat}
    T = ForwardDiff.Dual{Nothing, T_, 1}

    P = Parameter(T=T;kwargs...)
    @unpack Tprog = P

    G = ShallowWaters.Grid{T,Tprog}(P)
    C = ShallowWaters.Constants{T,Tprog}(P,G)
    F = ShallowWaters.Forcing{T}(P,G)
    S = ShallowWaters.ModelSetup{T,Tprog}(P,G,C,F)

    Prog = ShallowWaters.initial_conditions(Tprog,S)
    Diag = ShallowWaters.preallocate(T,Tprog,G)

    Prog = ShallowWaters.time_integration(Prog,Diag,S)
    return Prog
end

Prog = ShallowWaters.run_model(Float64, Passive(); Ndays=2)
Prog = ShallowWaters.run_model(Float64, Forward(); Ndays=2)

