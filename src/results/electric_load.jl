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
`ElectricLoad` results keys:
- `load_series_kw` vector of site load in every time step
- `critical_load_series_kw` vector of site critical load in every time step
- `annual_calculated_kwh` sum of the `load_series_kw`
- `offgrid_load_met_series_kw` vector of electric load met by generation techs, for off-grid scenarios only
- `offgrid_load_met_fraction` percentage of total electric load met on an annual basis, for off-grid scenarios only
- `offgrid_annual_oper_res_required_series_kwh` , total operating reserves required (for load and techs) on an annual basis, for off-grid scenarios only
- `offgrid_annual_oper_res_provided_series_kwh` , total operating reserves provided on an annual basis, for off-grid scenarios only

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""
function add_electric_load_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `ElectricLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    r["load_series_kw"] = p.s.electric_load.loads_kw
    r["critical_load_series_kw"] = p.s.electric_load.critical_loads_kw
    r["annual_calculated_kwh"] = round(
        sum(r["load_series_kw"]) / p.s.settings.time_steps_per_hour, digits=2
    )
    
    if p.s.settings.off_grid_flag
        @expression(m, LoadMet[ts in p.time_steps_without_grid], p.s.electric_load.critical_loads_kw[ts] * m[Symbol("dvOffgridLoadServedFraction"*_n)][ts])
        r["offgrid_load_met_series_kw"] =  round.(value.(LoadMet).data, digits=6)
        @expression(m, LoadMetPct, sum(p.s.electric_load.critical_loads_kw[ts] * m[Symbol("dvOffgridLoadServedFraction"*_n)][ts] for ts in p.time_steps_without_grid) /
                sum(p.s.electric_load.critical_loads_kw))
        r["offgrid_load_met_fraction"] = round(value(LoadMetPct), digits=6)
        
        r["offgrid_annual_oper_res_required_series_kwh"] = round.(value.(m[:OpResRequired][ts] for ts in p.time_steps_without_grid), digits=3)
        r["offgrid_annual_oper_res_provided_series_kwh"] = round.(value.(m[:OpResProvided][ts] for ts in p.time_steps_without_grid), digits=3)
    end
    
    d["ElectricLoad"] = r
    nothing
end


function add_electric_load_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    # Adds the `ElectricLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    r["load_series_kw"] = p.s.electric_load.loads_kw
    
    d["ElectricLoad"] = r
    nothing
end