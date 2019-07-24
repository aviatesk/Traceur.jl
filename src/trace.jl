using Vinyl: @overdub, @hook
using InteractiveUtils

struct Trace
  seen::Set
  stack::Vector{Call}
  warn
  maxdepth::Int
end

function Trace(w; maxdepth=typemax(Int))
  Trace(Set(), Vector{Call}(), w, maxdepth)
end

struct TraceurCtx
  metadata::Trace
end

isprimitive(f) = f isa Core.Builtin || f isa Core.IntrinsicFunction

const ignored_methods = Set([@which((1,2)[1])])
const ignored_functions = Set([getproperty, setproperty!])

dispatch_type(f, args...) = typeof.((f, args))

should_analyse(tra::Trace, C::DynamicCall) = begin
  f = C.f
  T = dispatch_type(f, C.a)

  f ∉ ignored_functions && T ∉ tra.seen && !isprimitive(f) && method(C) ∉ ignored_methods && method(C).module ∉ (Core, Core.Compiler)
end

@hook ctx::TraceurCtx (fcall::Any)(fargs...) = begin
  tra = ctx.metadata
  C = DynamicCall(fcall, fargs...)

  if should_analyse(tra, C)
    push!(tra.seen, dispatch_type(fcall, fargs))
    analyse((a...) -> tra.warn(Warning(a...)), C)
  end
end

trace(w, fcall, fargs...; kwargs...) = begin
  @overdub TraceurCtx(Trace(w; kwargs...)) fcall(fargs...)
end

function warntrace(fcall, fargs...; modules=[], kwargs...)
  trace(warning_printer(modules), fcall, fargs...; kwargs...)
end

"""
    warnings(f; kwargs...)::Vector{Traceur.Warnings}

Collect all warnings generated by Traceur's analysis of the execution of the
no-arg function `f` and return them.

Possible keyword arguments:
- `maxdepth=typemax(Int)` constrols how far Traceur recurses through the call stack.
- If `modules` is nonempty, only warnings for methods defined in one of the modules specified will be printed.
"""
function warnings(f; modules=[], kwargs...)
  warnings = Warning[]
  trace(w -> push!(warnings, w), f; kwargs...)
  if !isempty(modules)
    filter!(x -> getmod(x) in modules, warnings)
  end
  return warnings
end

"""
    @trace(functioncall(args...), maxdepth=2, modules=[])

Analyse `functioncall(args...)` for common performance problems and print them to
the terminal.

Optional arguments:
- `maxdepth` constrols how far Traceur recurses through the call stack.
- If `modules` is nonempty, only warnings for methods defined in one of the modules specified will be printed.
"""
macro trace(ex, args...)
  fcall = ex.args[1]
  fargs = ex.args[2:end]
  quote
    warntrace($(esc(fcall)), $(map(esc, fargs)...); $(map(esc, args)...))
  end
end
