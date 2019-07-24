const should_not_warn = Set{Function}()

"""
    @should_not_warn function foo(x)
      ...
    end

Add `foo` to the list of functions in which no warnings may occur (checkd by `@check`).
"""
macro should_not_warn(expr)
  quote
    fun = $(esc(expr))
    push!(should_not_warn, fun)
    fun
  end
end

"""
    check(f::Function)

Run Traceur on `f`, and throw an error if any warnings occur inside functions
tagged with `@should_not_warn`.
"""
function check(fcall, fargs...; nowarn=Any[], kwargs...)
  warningscnt = 0
  warningprinter = warning_printer()
  result = trace(fcall, fargs...; kwargs...) do warning
    f = warning.call.f
    if f in should_not_warn || f in nowarn
      message = "$(warning.message) (called from $(f))"
      warning = Warning(warning.call, warning.line, message)
      warningprinter(warning)
      warningscnt += 1
    end
  end
  @assert warningscnt === 0 "$(warningscnt) warnings occured inside functions tagged with `@should_not_warn`"
  result
end

"""
    @check fun(args...) nowarn=[] maxdepth=typemax(Int)

Run Traceur on `fun`, and throw an error if any warnings occur inside functions
tagged with `@should_not_warn` or specified in `nowarn`.
"""
macro check(ex, args...)
  fcall = ex.args[1]
  fargs = ex.args[2:end]
  quote
    check($(esc(fcall)), $(map(esc, fargs)...); $(map(esc, args)...))
  end
end
