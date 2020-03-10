import Unitful: Unitful, Units, Quantity, uconvert, ustrip, @u_str
export @u_str

unitfy(::Nothing, u) = nothing
unitfy(::Nothing, ::Nothing) = nothing
unitfy(v, ::Nothing) = v
unitfy(v::Number, u::Units) = Quantity(v, u)
unitfy(v::Array, u::Units) = Quantity.(v, u)
unitfy(v::Tuple, u::Units) = Quantity.(v, u)
unitfy(v::Quantity, u::Units) = uconvert(u, v)
unitfy(v::Array{<:Quantity}, u::Units) = uconvert.(u, v)

deunitfy(v) = v
deunitfy(v::Quantity) = ustrip(v)
deunitfy(v::Array) = deunitfy.(v)
deunitfy(v::Tuple) = deunitfy.(v)
deunitfy(v, u) = deunitfy(unitfy(v, u))

