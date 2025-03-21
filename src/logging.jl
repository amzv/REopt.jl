# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************

"""
    REoptLogger

- Instantiates a global logger of type REoptLogger which can log to console for logging events >= `@info` and to a dictionary for events >= `@warn`. 
    Dictionary collects information in the following format:
    - Warn
        - Keys for file names with warnings
            - Values of messages associated with those warnings
    - Error
        - Keys for file names with errors
            - Values of messages associated with those errors

- The logger is instantiated in REopt.Scenario, REopt.REoptInputs functions and a few instances of REopt.run_reopt functions

- Messages are appended to the results dictionary using the following layout:
    - warnings (array of Tuples)
        - 1st element: Folder, file and line of error
        - 2nd element: Warning text
    - errors (array of Tuples)
        - 1st element: Folder, file and line of error
        - 2nd element: Error text with stacktrace if uncaught error

- Logger dictionary is flushed at every new REopt run by checking if logger type is REoptLogger
"""
struct REoptLogger <: Logging.AbstractLogger
    d::Dict
    io::IO
end

REoptLogger() = REoptLogger(Dict(), stderr)

Logging.min_enabled_level(logger::REoptLogger) = Logging.Info

function Logging.shouldlog(logger::REoptLogger, level, _module, group, id)
    return true
 end

Logging.catch_exceptions(logger::REoptLogger) = true

function Logging.handle_message(logger::REoptLogger, lvl, msg, _mod, group, id, file, line; kwargs...)

    msglines = split(chomp(convert(String, string(msg))::String), '\n')
    msg1, rest = Iterators.peel(msglines)

    col = nothing
    if string(lvl)=="Error"
        col = :red
    elseif string(lvl)=="Warn"
        col = :light_yellow
    elseif string(lvl)=="Info"
        col = :cyan
    else
        col = :default
    end

    printstyled(logger.io, "┌ ", _mod, " | ", lvl, ": "; bold=true, color=col)
    printstyled(logger.io, msg1, "\n")
    for msg in rest
        println(logger.io, "│ ", msg)
    end
    for (key, val) in kwargs
        key === :maxlog && continue
        println(logger.io, "│   ", key, " = ", val)
    end
    println(logger.io, "└ @ ", _mod, " ", file, ":", line)

    if string(lvl) in ["Warn","Error"]
        if string(lvl) ∉ keys(logger.d) # key doesnt exists
            logger.d[string(lvl)] = Dict()
        end

        # Does the key for file exist?
        if Sys.iswindows() #windows
            splitter = "\\"
        else # unix/mac
            splitter = "/"
        end
        
        splt = split(file, splitter)
        f = join([splt[end-1], splt[end], line], "_")

        if f ∉ keys(logger.d[string(lvl)]) #file name doesnt exists
            logger.d[string(lvl)][f] = Any[]
        end

        push!(logger.d[string(lvl)][f], msg)
    end
end

"""
    handle_errors(e::E, stacktrace::V) where {
		E <: Exception,
		V <: Vector
	}

Creates a results dictionary in case of an error from REopt.jl with Warnings and Errors from logREopt.d. The unhandled error+stacktrace is returned to the user.
"""
function handle_errors(e::E, stacktrace::V) where {
	E <: Exception,
	V <: Vector
	}

	results = Dict(
		"Messages"=>Dict(),
		"status"=>"error"
	)

	results["Messages"] = logger_to_dict()

	push!(results["Messages"]["errors"], (string(e),string.(stacktrace)))
	return results
end

"""
    handle_errors()

Creates a results dictionary in case of a handled error from REopt.jl with Warnings and Errors from logREopt.d, which is returned to the user.
"""
function handle_errors()

	results = Dict(
		"Messages"=>Dict(),
		"status"=>"error"
	)

	results["Messages"] = logger_to_dict()

	return results
end

"""
	logger_to_dict()

The purpose of this function is to extract warnings and errors from REopt logger and package them in a dictionary which can be returned to the user as-is.
"""
function logger_to_dict()

	d = Dict()
	d["warnings"] = []
	d["errors"] = []

	if "Warn" in keys(logREopt.d)
		for (keys,values) in logREopt.d["Warn"]
			push!(d["warnings"], (keys, values))
		end
	end

	if "Error" in keys(logREopt.d)
		for (keys,values) in logREopt.d["Error"]
			push!(d["errors"], (keys, values))
		end
	end

	return d
end

"""
	instantiate_logger()

Instantiate a global logger of type REoptLogger and set it to global logger for downstream processing.
"""
function instantiate_logger()

	if !isa(global_logger(), REoptLogger)
		global logREopt = REoptLogger()
		global_logger(logREopt)
		@debug "Created custom REopt Logger"
	else
		@debug "Already REoptLogger"
        logREopt.d["Warn"] = Dict()
        logREopt.d["Error"] = Dict()
	end
end