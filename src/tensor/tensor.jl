export Tensor,
       inds,
       ind,
       store

"""
Tensor{StoreT,IndsT}

A plain old tensor (with order independent
interface and no assumption of labels)
"""
struct Tensor{ElT,N,StoreT<:TensorStorage,IndsT} <: AbstractArray{ElT,N}
  store::StoreT
  inds::IndsT
  # The resulting Tensor is a view into the input data
  function Tensor(store::StoreT,inds::IndsT) where {StoreT<:TensorStorage{ElT},IndsT} where {ElT}
    new{ElT,length(IndsT),StoreT,IndsT}(store,inds)
  end
end

store(T::Tensor) = T.store
inds(T::Tensor) = T.inds
ind(T::Tensor,j::Integer) = inds(T)[j]

#
# Generic Tensor functions
#

# The size is obtained from the indices
dims(T::Tensor) = dims(inds(T))
dim(T::Tensor) = dim(inds(T))
Base.size(T::Tensor) = dims(T)

Base.copy(T::Tensor) = Tensor(copy(store(T)),copy(inds(T)))

Base.complex(T::Tensor) = Tensor(complex(store(T)),copy(inds(T)))

Random.randn!(T::Tensor) = (randn!(store(T)); return T)

# TODO: For BlockSparse, this needs to include the offsets
function Base.similar(::Type{<:Tensor{ElT,N,StoreT}},dims) where {ElT,N,StoreT}
  return Tensor(similar(StoreT,dim(dims)),dims)
end
# TODO: make sure these are implemented correctly
#Base.similar(T::Type{<:Tensor},::Type{S}) where {S} = Tensor(similar(store(T),S),inds(T))
#Base.similar(T::Type{<:Tensor},::Type{S},dims) where {S} = Tensor(similar(store(T),S),dims)

Base.similar(T::Tensor) = Tensor(similar(store(T)),copy(inds(T)))
Base.similar(T::Tensor,dims) = Tensor(similar(store(T),dim(dims)),dims)
# To handle method ambiguity with AbstractArray
Base.similar(T::Tensor,dims::Dims) = Tensor(similar(store(T),dim(dims)),dims)
Base.similar(T::Tensor,::Type{S}) where {S<:Number} = Tensor(similar(store(T),S),copy(inds(T)))
Base.similar(T::Tensor,::Type{S},dims) where {S<:Number} = Tensor(similar(store(T),S,dim(dims)),dims)
# To handle method ambiguity with AbstractArray
Base.similar(T::Tensor,::Type{S},dims::Dims) where {S<:Number} = Tensor(similar(store(T),S,dim(dims)),dims)

#function Base.convert(::Type{Tensor{<:Number,N,StoreR,Inds}},
#                      T::Tensor{<:Number,N,<:Any,Inds}) where {N,Inds,StoreR}
#  return Tensor(convert(StoreR,store(T)),copy(inds(T)))
#end

function Base.zeros(::Type{<:Tensor{ElT,N,StoreT}},inds) where {ElT,N,StoreT}
  return Tensor(zeros(StoreT,dim(inds)),inds)
end

# This is to fix a method ambiguity with a Base array function
function Base.zeros(::Type{<:Tensor{ElT,N,StoreT}},inds::Dims{N}) where {ElT,N,StoreT}
  return Tensor(zeros(StoreT,dim(inds)),inds)
end

function Base.promote_rule(::Type{<:Tensor{ElT1,N1,StoreT1}},
                           ::Type{<:Tensor{ElT2,N2,StoreT2}}) where {ElT1,ElT2,
                                                                     N1,N2,
                                                                     StoreT1,StoreT2}
  return Tensor{promote_type(ElT1,ElT2),N3,promote_type(StoreT1,StoreT2)} where {N3}
end

function Base.promote_rule(::Type{Tensor{ElT1,N,StoreT1,Inds}},
                           ::Type{Tensor{ElT2,N,StoreT2,Inds}}) where {ElT1,ElT2,N,
                                                                       StoreT1,StoreT2,Inds}
  return Tensor{promote_type(ElT1,ElT2),N,promote_type(StoreT1,StoreT2),Inds}
end

#function Base.promote_rule(::Type{<:Tensor{ElT,<:Any,StoreT,<:Any}},::Type{IndsR}) where {N,ElT,StoreT,IndsR}
#  return Tensor{ElT,length(IndsR),StoreT,IndsR}
#end

# Convert the tensor type to the closest dense
# type
function dense(::Type{<:Tensor{ElT,N,StoreT,IndsT}}) where {ElT,N,StoreT,IndsT}
  return Tensor{ElT,N,dense(StoreT),dense(IndsT)}
end

function StaticArrays.similar_type(::Type{<:Tensor{ElT,<:Any,StoreT,<:Any}},indsR) where {N,ElT,StoreT}
  return Tensor{ElT,length(indsR),StoreT,typeof(indsR)}
end

Base.BroadcastStyle(::Type{T}) where {T<:Tensor} = Broadcast.ArrayStyle{T}()

function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{T}},
                      ::Type{<:Any}) where {T<:Tensor}
  A = find_tensor(bc)
  return similar(A)
end

# This is used for overloading broadcast
"`A = find_tensor(As)` returns the first Tensor among the arguments."
find_tensor(bc::Base.Broadcast.Broadcasted) = find_tensor(bc.args)
find_tensor(args::Tuple) = find_tensor(find_tensor(args[1]), Base.tail(args))
find_tensor(x) = x
find_tensor(a::Tensor, rest) = a
find_tensor(::Any, rest) = find_tensor(rest)

# TODO: implement some generic fallbacks for necessary parts of the API?
#Base.getindex(A::TensorT, i::Int) where {TensorT<:Tensor} = error("getindex not yet implemented for Tensor type $TensorT")

