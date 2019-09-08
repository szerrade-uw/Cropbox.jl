#HACK: Any seems to be faster than Function
struct Queue
    pre::Vector{Any}
    post::Vector{Any}
    pending::Bool
    prepending::Vector{Any}
    postpending::Vector{Any}
end

Queue() = Queue(Any[], Any[], false, Any[], Any[])

current(q::Queue, ::PrePriority) = (q.pending ? q.prepending : q.pre)
current(q::Queue, ::PostPriority) = (q.pending ? q.postpending : q.post)

queue!(q::Queue, f::Function, p::PrePriority) = queue!(current(q, p), f)
queue!(q::Queue, f::Function, p::PostPriority) = queue!(current(q, p), f)
queue!(q::Vector, f::Function) = push!(q, f)

flush!(q::Queue, ::PrePriority) = flush!(current(q, p))
flush!(q::Queue, ::PostPriority) = flush!(current(q, p))
flush!(q::Vector) = (foreach(f -> f(), q); empty!(q))

preflush!(q::Queue) = flush!(q, PrePriority())
postflush!(q::Queue) = flush!(q, PostPriority())

startpending(q::Queue) = (q.pending = true)
stoppending(q::Queue; merge=false) = begin
    q.pending = false
    if merge
        append!(q.pre, q.prepending)
        append!(q.post, q.postpending)
    end
    empty!(q.prepending)
    empty!(q.postpending)
end
