module PointsOfInterest

using AutoHashEquals, Base.Dates, IntervalSets

export POI

import Base: ∈, push!, delete!, empty!

@auto_hash_equals struct Video
    name::String
    time::DateTime
end

struct Metadata
    pois::Vector{String}
    files::Vector{Video}
end

const sides = (:left, :right)

@auto_hash_equals struct Point
    file::Int
    time::Millisecond

    function Point(md::Metadata, file::String, time::Millisecond)
        i = findfirst(x -> x.name == file, md.files)
        @assert i ≠ 0 "file not found in metadata"
        @assert time ≥ Millisecond(0) "negative times not allowed"
        new(i, time)
    end
end

Base.isless(p1::Point, p2::Point) = p1.file == p2.file ? p1.time < p2.time : p1.file < p2.file

@auto_hash_equals mutable struct POI
    name::Int
    interval::ClosedInterval{Point}
    comment::String

    function POI(md::Metadata, name::String, interval::ClosedInterval{Point}, comment::String)
        i = findfirst(md.pois, name)
        @assert i ≠ 0 "POI not found in metadata"
        @assert !isempty(interval) "interval is non-existent"
        new(i, interval, comment)
    end
end

POI(md::Metadata, name::String, start::Tuple{String, Millisecond}, stop::Tuple{String, Millisecond}, comment::String) = POI(md, name, Point(md, start...), Point(md, stop...), comment)


# POI(md::Metadata, name::String, label::String, start_file::String, start_time::Millisecond, stop_file::String, stop_time::Millisecond, comment::String) = POI(name, label, Point(md, start_file, start_time), Point(md, stop_file, stop_time), comment)


struct Log
    md::Metadata

    pois::Vector{POI}
end

Log(md::Metadata) = Log(md, POI[])

# findfirst

# findfirst(a::Log, x::Rep) = findfirst(a.reps, x)

# in

∈(x::POI, a::Log) = x ∈ a.pois

∈(x::Video, a::Log) = x ∈ a.files

# pushes

function push!(a::Log, x::Video)
    x ∈ a && return a
    i = findfirst(v -> v.time > x.time, a.md.files)
    insert!(a.md.files, i, x)
    for p in a.pois
        left = p.interval.left
        if left.file ≥ i
            right = p.interval.right
            p.interval = Point(left.file + 1, left.time)..Point(right.file + 1, right.time)
        end
    end
    return a
end

function push!(a::Log, x::POI)
    x ∉ a && push!(a.pois, x)
    return a
end

# deletes

function delete!(a::Log, x::POI)
    i = findfirst(a.pois, x)
    i ≠ 0 && deleteat!(a.pois, i)
    return a
end

function delete!(a::Log, x::Video)
    i = findfirst(a.md.files, x)
    i == 0 && return a
    deleteat!(a.md.files, i)
    filter!(p -> p.interval.left.file == i || p.interval.right.file == i, a.pois)
    for p in a.pois
        left = p.interval.left
        if left.file > i
            right = p.interval.right
            p.interval = Point(left.file - 1, left.time)..Point(right.file - 1, right.time)
        end
    end
    return a
end


# replace

function replace!(a::Log, o::POI, n::POI)
    o == n && return a
    n ∈ a && delete!(a, o)
    i = findfirst(a.pois, o)
    @assert i ≠ 0 "old POI not found"
    a.pois[i] = n
    return a
end

# empty

function empty!(a::Log, ::Type{POI})
    empty!(a.pois)
    return a
end


# pop

pop(md::Metadata, x::Point) = (md.files[x.file], x.time)

pop(md::Metadata, x::ClosedInterval{Point}) = (pop(md, x.left), pop(md, x.right))

pop(md::Metadata, x::POI) = (md.pois[x.name], pop(md, x.interval), x.comment)

# combine

function combine_mds(logs::Log...)
    pois = String[]
    videos = Video[]
    for log in logs
        union!(pois, log.md.pois)
        union!(videos, log.md.files)
    end
    sort!(videos, by = v -> v.time)
    return Metadata(pois, videos)
end

function combine(logs::Log...)
    md = combine_mds(logs)
    a = Log(md)
    for log in logs, p in log.pois
        push!(a, POI(md, pop(log.md, p)))
    end
    return a
end


end # module
