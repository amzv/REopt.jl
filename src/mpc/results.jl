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
MPC Scenarios will return a results Dict with the following keys: 
- `ElectricStorage`
- `HotThermalStorage`
- `ColdThermalStorage` 
- `ElectricTariff`
- `ElectricUtility`
- `PV`
- `Generator`
"""
function mpc_results(m::JuMP.AbstractModel, p::MPCInputs; _n="")
	tstart = time()
    d = Dict{String, Any}()

    add_electric_load_results(m, p, d; _n)

    for b in p.s.storage.types.elec
        if p.s.storage.attr[b].size_kwh > 0
            add_electric_storage_results(m, p, d, b; _n)
        end
    end

    for b in p.s.storage.types.hot
        if p.s.storage.attr[b].size_kwh > 0
            add_hot_storage_results(m, p, d, b; _n)
        end
    end

    for b in p.s.storage.types.cold
        if p.s.storage.attr[b].size_kwh > 0
            add_cold_storage_results(m, p, d, b; _n)
        end
    end

    add_electric_tariff_results(m, p, d; _n)
    add_electric_utility_results(m, p, d; _n)

	if !isempty(p.techs.pv)
        add_pv_results(m, p, d; _n)
	end

	if !isempty(p.techs.gen)
        add_generator_results(m, p, d; _n)
	end

    d["Costs"] = value(m[Symbol("Costs"*_n)])
	
	time_elapsed = time() - tstart
	@info "Results processing took $(round(time_elapsed, digits=3)) seconds."
	
	# if !isempty(p.s.electric_utility.outage_durations) && isempty(_n)  # outages not included in multinode model
    #     tstart = time()
	# 	add_outage_results(m, p, d)
    #     time_elapsed = time() - tstart
    #     @info "Outage results processing took $(round(time_elapsed, digits=3)) seconds."
	# end
	return d
end
