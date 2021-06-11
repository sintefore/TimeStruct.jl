struct WithPrev{I}
	itr::I
end

withprev(iter) = WithPrev(iter)
Base.length(w::WithPrev) = length(w.itr)
Base.size(w::WithPrev) = size(w.itr)

function Base.iterate(w::WithPrev)
	n = iterate(w.itr)
	n === nothing && return n
	return (nothing, n[1]), (n[1],n[2])
end

function Base.iterate(w::WithPrev, state)
	n = iterate(w.itr,state[2])
	n === nothing && return n
	(isfirst(n[1]) ? nothing : state[1],n[1]), (n[1],n[2])
end