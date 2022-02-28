struct ModelSetup{T<:Real,Tprog<:Real}
    parameters::Parameter
    grid::Grid{T,Tprog}
    constants::Constants{T,Tprog}
    forcing::Forcing{T}
end
