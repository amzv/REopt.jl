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
`AbsorptionChiller` results keys:
- `size_kw` # Optimal power capacity size of the absorption chiller system [kW]
- `size_ton` 
- `thermal_to_storage_series_ton` # Thermal production to ColdThermalStorage
- `thermal_to_load_series_ton` # Thermal production to cooling load
- `thermal_consumption_series_mmbtu_per_hour`
- `annual_thermal_consumption_mmbtu`
- `annual_thermal_production_tonhour`
- `electric_consumption_series_kw`
- `annual_electric_consumption_kwh`

"""
function add_absorption_chiller_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
	# Adds the `AbsorptionChiller` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
	# Note: the node number is an empty string if evaluating a single `Site`.	

    r = Dict{String, Any}()

	# @expression(m, ELECCHLtoTES[ts in p.time_steps],
	# 	sum(m[:dvProductionToStorage][b, "ExistingChiller", ts] for b in p.ColdTES)
    # )
	# r["existing_chiller_to_tes_series"] = round.(value.(ELECCHLtoTES), digits=3)

	r["size_kw"] = value(sum(m[:dvSize][t] for t in p.techs.absorption_chiller))
	r["size_ton"] = r["size_kw"] / KWH_THERMAL_PER_TONHOUR
	@expression(m, ABSORPCHLtoTESKW[ts in p.time_steps],
		sum(m[:dvProductionToStorage][b,t,ts] for b in p.s.storage.types.cold, t in p.techs.absorption_chiller))
	r["thermal_to_storage_series_ton"] = round.(value.(ABSORPCHLtoTESKW) ./ KWH_THERMAL_PER_TONHOUR, digits=5)
	@expression(m, ABSORPCHLtoLoadKW[ts in p.time_steps],
		sum(m[:dvThermalProduction][t,ts] for t in p.techs.absorption_chiller)
			- ABSORPCHLtoTESKW[ts]) 
	r["thermal_to_load_series_ton"] = round.(value.(ABSORPCHLtoLoadKW) ./ KWH_THERMAL_PER_TONHOUR, digits=5)
	@expression(m, ABSORPCHLThermalConsumptionSeriesKW[ts in p.time_steps],
		sum(m[:dvThermalProduction][t,ts] / p.thermal_cop[t] for t in p.techs.absorption_chiller))
	r["thermal_consumption_series_mmbtu_per_hour"] = round.(value.(ABSORPCHLThermalConsumptionSeriesKW) ./ KWH_PER_MMBTU, digits=5)
	@expression(m, Year1ABSORPCHLThermalConsumptionKWH,
		p.hours_per_time_step * sum(m[:dvThermalProduction][t,ts] / p.thermal_cop[t]
			for t in p.techs.absorption_chiller, ts in p.time_steps))
	r["annual_thermal_consumption_mmbtu"] = round(value(Year1ABSORPCHLThermalConsumptionKWH) / KWH_PER_MMBTU, digits=5)
	@expression(m, Year1ABSORPCHLThermalProdKWH,
		p.hours_per_time_step * sum(m[:dvThermalProduction][t, ts]
			for t in p.techs.absorption_chiller, ts in p.time_steps))
	r["annual_thermal_production_tonhour"] = round(value(Year1ABSORPCHLThermalProdKWH) / KWH_THERMAL_PER_TONHOUR, digits=5)
    @expression(m, ABSORPCHLElectricConsumptionSeries[ts in p.time_steps],
        sum(m[:dvThermalProduction][t,ts] / p.cop[t] for t in p.techs.absorption_chiller) )
    r["electric_consumption_series_kw"] = round.(value.(ABSORPCHLElectricConsumptionSeries), digits=3)
    @expression(m, Year1ABSORPCHLElectricConsumption,
        p.hours_per_time_step * sum(m[:dvThermalProduction][t,ts] / p.cop[t] 
            for t in p.techs.absorption_chiller, ts in p.time_steps))
    r["annual_electric_consumption_kwh"] = round(value(Year1ABSORPCHLElectricConsumption), digits=3)
    
	d["AbsorptionChiller"] = r
	nothing
end