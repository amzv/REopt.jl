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
    REoptInputs(d::Dict)

Return REoptInputs(s) where s in `Scenario` defined in dict `d`.
"""

function REoptInputs(d::Dict)

	# Keep try catch to support API v3 call to `REoptInputs`
	try
		REoptInputs(Scenario(d))
	catch e
		if isnothing(e) # Error thrown by REopt
			handle_errors()
		else
			handle_errors(e, stacktrace(catch_backtrace()))
		end
	end
end

"""
	run_reopt(m::JuMP.AbstractModel, fp::String)

Solve the model using the `Scenario` defined in JSON file stored at the file path `fp`.
"""
function run_reopt(m::JuMP.AbstractModel, fp::String)

	try
		s = Scenario(JSON.parsefile(fp))
		run_reopt(m, REoptInputs(s))
	catch e
		if isnothing(e) # Error thrown by REopt
			handle_errors()
		else
			handle_errors(e, stacktrace(catch_backtrace()))
		end
	end
end


"""
	run_reopt(m::JuMP.AbstractModel, d::Dict)

Solve the model using the `Scenario` defined in dict `d`.
"""
function run_reopt(m::JuMP.AbstractModel, d::Dict)

	try
		s = Scenario(d)
		run_reopt(m, REoptInputs(s))
	catch e
		if isnothing(e) # Error thrown by REopt
			handle_errors()
		else
			handle_errors(e, stacktrace(catch_backtrace()))
		end
	end
end


"""
	run_reopt(m::JuMP.AbstractModel, s::AbstractScenario)

Solve the model using a `Scenario` or `BAUScenario`.
"""
function run_reopt(m::JuMP.AbstractModel, s::AbstractScenario)
	
	try
		if s.site.CO2_emissions_reduction_min_fraction > 0.0 || s.site.CO2_emissions_reduction_max_fraction < 1.0
			throw(@error("To constrain CO2 emissions reduction min or max percentages, the optimal and business as usual scenarios must be run in parallel. Use a version of run_reopt() that takes an array of two models."))
		end
		run_reopt(m, REoptInputs(s))
	catch e
		if isnothing(e) # Error thrown by REopt
			handle_errors()
		else
			handle_errors(e, stacktrace(catch_backtrace()))
		end
	end
end


"""
    run_reopt(t::Tuple{JuMP.AbstractModel, AbstractScenario})

Method for use with Threads when running BAU in parallel with optimal scenario.
"""
function run_reopt(t::Tuple{JuMP.AbstractModel, AbstractInputs})
	run_reopt(t[1], t[2]; organize_pvs=false)
	# must organize_pvs after adding proforma results
end


"""
    run_reopt(ms::AbstractArray{T, 1}, fp::String) where T <: JuMP.AbstractModel

Solve the `Scenario` and `BAUScenario` in parallel using the first two (empty) models in `ms` and inputs defined in the
JSON file at the filepath `fp`.
"""
function run_reopt(ms::AbstractArray{T, 1}, fp::String) where T <: JuMP.AbstractModel
	d = JSON.parsefile(fp)
    run_reopt(ms, d)
end


"""
    run_reopt(ms::AbstractArray{T, 1}, d::Dict) where T <: JuMP.AbstractModel

Solve the `Scenario` and `BAUScenario` in parallel using the first two (empty) models in `ms` and inputs from `d`.
"""
function run_reopt(ms::AbstractArray{T, 1}, d::Dict) where T <: JuMP.AbstractModel

	try
		s = Scenario(d)
		if s.settings.off_grid_flag
			@warn "Only using first Model and not running BAU case because `off_grid_flag` is true. The BAU scenario is not applicable for off-grid microgrids."
			results = run_reopt(ms[1], s)
			return results
		end
	
		run_reopt(ms, REoptInputs(s))		
	catch e
		if isnothing(e) # Error thrown by REopt
			handle_errors()
		else
			handle_errors(e, stacktrace(catch_backtrace()))
		end
	end
end

"""
    run_reopt(ms::AbstractArray{T, 1}, p::REoptInputs) where T <: JuMP.AbstractModel

Solve the `Scenario` and `BAUScenario` in parallel using the first two (empty) models in `ms` and inputs from `p`.
"""
function run_reopt(ms::AbstractArray{T, 1}, p::REoptInputs) where T <: JuMP.AbstractModel

	try
		bau_inputs = BAUInputs(p)
		inputs = ((ms[1], bau_inputs), (ms[2], p))
		rs = Any[0, 0]
		Threads.@threads for i = 1:2
			rs[i] = run_reopt(inputs[i])
		end
		if typeof(rs[1]) <: Dict && typeof(rs[2]) <: Dict
			# TODO when a model is infeasible the JuMP.Model is returned from run_reopt (and not the results Dict)
			results_dict = combine_results(p, rs[1], rs[2], bau_inputs.s)
			results_dict["Financial"] = merge(results_dict["Financial"], proforma_results(p, results_dict))
			if !isempty(p.techs.pv)
				organize_multiple_pv_results(p, results_dict)
			end
			return results_dict
		else
			return rs
		end
	catch e
		if isnothing(e) # Error thrown by REopt
			handle_errors()
		else
			handle_errors(e, stacktrace(catch_backtrace()))
		end
	end
end


"""
	build_reopt!(m::JuMP.AbstractModel, fp::String)

Add variables and constraints for REopt model. 
`fp` is used to load in JSON file to construct REoptInputs.
"""
function build_reopt!(m::JuMP.AbstractModel, fp::String)
	s = Scenario(JSON.parsefile(fp))
	build_reopt!(m, REoptInputs(s))
	nothing
end


"""
	build_reopt!(m::JuMP.AbstractModel, p::REoptInputs)
Add variables and constraints for REopt model.
"""
function build_reopt!(m::JuMP.AbstractModel, p::REoptInputs)

	add_variables!(m, p)

	for ts in p.time_steps_without_grid

		for tier in 1:p.s.electric_tariff.n_energy_tiers
			fix(m[:dvGridPurchase][ts, tier] , 0.0, force=true)
		end

		for t in p.s.storage.types.elec
			fix(m[:dvGridToStorage][t, ts], 0.0, force=true)
		end

        if !isempty(p.s.electric_tariff.export_bins)
            for t in p.techs.elec, u in p.export_bins_by_tech[t]
                fix(m[:dvProductionToGrid][t, u, ts], 0.0, force=true)
            end
        end
	end

	for b in p.s.storage.types.all
		if p.s.storage.attr[b].max_kw == 0 || p.s.storage.attr[b].max_kwh == 0
			@constraint(m, [ts in p.time_steps], m[:dvStoredEnergy][b, ts] == 0)
			@constraint(m, m[:dvStorageEnergy][b] == 0)
			@constraint(m, [ts in p.time_steps], m[:dvDischargeFromStorage][b, ts] == 0)
			if b in p.s.storage.types.elec
				@constraint(m, m[:dvStoragePower][b] == 0)
				@constraint(m, [ts in p.time_steps], m[:dvGridToStorage][b, ts] == 0)
				@constraint(m, [t in p.techs.elec, ts in p.time_steps_with_grid],
						m[:dvProductionToStorage][b, t, ts] == 0)
			end
		else
			add_storage_size_constraints(m, p, b)
			add_general_storage_dispatch_constraints(m, p, b)
			if b in p.s.storage.types.elec
				add_elec_storage_dispatch_constraints(m, p, b)
			elseif b in p.s.storage.types.hot
				add_hot_thermal_storage_dispatch_constraints(m, p, b)
			elseif b in p.s.storage.types.cold
				add_cold_thermal_storage_dispatch_constraints(m, p, b)
			else
				throw(@error("Invalid storage does not fall in a thermal or electrical set"))
			end
		end
	end

	if any(max_kw->max_kw > 0, (p.s.storage.attr[b].max_kw for b in p.s.storage.types.elec))
		add_storage_sum_constraints(m, p)
	end

	add_production_constraints(m, p)

    m[:TotalTechCapCosts] = 0.0
    m[:TotalPerUnitProdOMCosts] = 0.0
    m[:TotalPerUnitHourOMCosts] = 0.0
    m[:TotalFuelCosts] = 0.0
    m[:TotalProductionIncentive] = 0
	m[:dvComfortLimitViolationCost] = 0.0
	m[:TotalCHPStandbyCharges] = 0
	m[:OffgridOtherCapexAfterDepr] = 0.0
    m[:GHPCapCosts] = 0.0
    m[:GHPOMCosts] = 0.0   

	if !isempty(p.techs.all)
		add_tech_size_constraints(m, p)
        
        if !isempty(p.techs.no_curtail)
            add_no_curtail_constraints(m, p)
        end
	
        if !isempty(p.techs.gen)
            add_gen_constraints(m, p)
            m[:TotalPerUnitProdOMCosts] += m[:TotalGenPerUnitProdOMCosts]
            m[:TotalFuelCosts] += m[:TotalGenFuelCosts]
        end

        if !isempty(p.techs.chp)
            add_chp_constraints(m, p)
            m[:TotalPerUnitProdOMCosts] += m[:TotalCHPPerUnitProdOMCosts]
            m[:TotalFuelCosts] += m[:TotalCHPFuelCosts]        
            m[:TotalPerUnitHourOMCosts] += m[:TotalHourlyCHPOMCosts]

			if p.s.chp.standby_rate_per_kw_per_month > 1.0e-7
				m[:TotalCHPStandbyCharges] += sum(p.s.financial.pwf_e * 12 * p.s.chp.standby_rate_per_kw_per_month * m[:dvSize][t] for t in p.techs.chp)
			end

			m[:TotalTechCapCosts] += sum(p.s.chp.supplementary_firing_capital_cost_per_kw * m[:dvSupplementaryFiringSize][t] for t in p.techs.chp)
        end

        if !isempty(p.techs.boiler)
            add_boiler_tech_constraints(m, p)
			m[:TotalPerUnitProdOMCosts] += m[:TotalBoilerPerUnitProdOMCosts]
			m[:TotalFuelCosts] += m[:TotalBoilerFuelCosts]
        end

		if !isempty(p.techs.cooling)
            add_cooling_tech_constraints(m, p)
        end
    
        if !isempty(p.techs.thermal)
            add_thermal_load_constraints(m, p)  # split into heating and cooling constraints?
        end

        if !isempty(p.ghp_options)
            add_ghp_constraints(m, p)
        end

        if !isempty(p.techs.steam_turbine)
            add_steam_turbine_constraints(m, p)
            m[:TotalPerUnitProdOMCosts] += m[:TotalSteamTurbinePerUnitProdOMCosts]
        end

        if !isempty(p.techs.pbi)
            @warn "Adding binary variable(s) to model production based incentives"
            add_prod_incent_vars_and_constraints(m, p)
        end
    end

	add_elec_load_balance_constraints(m, p)

	if p.s.settings.off_grid_flag
		add_operating_reserve_constraints(m, p)
	end

	if !isempty(p.s.electric_tariff.export_bins)
		add_export_constraints(m, p)
	end

	if !isempty(p.s.electric_tariff.monthly_demand_rates)
		add_monthly_peak_constraint(m, p)
	end

	if !isempty(p.s.electric_tariff.tou_demand_ratchet_time_steps)
		add_tou_peak_constraint(m, p)
	end

	if !(p.s.electric_utility.allow_simultaneous_export_import) & !isempty(p.s.electric_tariff.export_bins)
		add_simultaneous_export_import_constraint(m, p)
	end

	if p.s.electric_tariff.n_energy_tiers > 1
		add_energy_tier_constraints(m, p)
	end

    if p.s.electric_tariff.demand_lookback_percent > 0
        add_demand_lookback_constraints(m, p)
    end

    if !isempty(p.s.electric_tariff.coincpeak_periods)
        add_coincident_peak_charge_constraints(m, p)
    end

    if !isempty(setdiff(p.techs.all, p.techs.segmented))
        m[:TotalTechCapCosts] += p.third_party_factor *
            sum( p.cap_cost_slope[t] * m[:dvPurchaseSize][t] for t in setdiff(p.techs.all, p.techs.segmented))
    end

    if !isempty(p.techs.segmented)
        @warn "Adding binary variable(s) to model cost curves"
        add_cost_curve_vars_and_constraints(m, p)
        for t in p.techs.segmented  # cannot have this for statement in sum( ... for t in ...) ???
            m[:TotalTechCapCosts] += p.third_party_factor * (
                sum(p.cap_cost_slope[t][s] * m[Symbol("dvSegmentSystemSize"*t)][s] + 
                    p.seg_yint[t][s] * m[Symbol("binSegment"*t)][s] for s in 1:p.n_segs_by_tech[t])
            )
        end
    end
	
	@expression(m, TotalStorageCapCosts, p.third_party_factor * (
		sum( p.s.storage.attr[b].net_present_cost_per_kw * m[:dvStoragePower][b] for b in p.s.storage.types.elec) + 
		sum( p.s.storage.attr[b].net_present_cost_per_kwh * m[:dvStorageEnergy][b] for b in p.s.storage.types.all )
	))
	
	@expression(m, TotalPerUnitSizeOMCosts, p.third_party_factor * p.pwf_om *
		sum( p.om_cost_per_kw[t] * m[:dvSize][t] for t in p.techs.all )
	)

	add_elec_utility_expressions(m, p)

	if !isempty(p.s.electric_utility.outage_durations)
		add_dv_UnservedLoad_constraints(m,p)
		add_outage_cost_constraints(m,p)
		add_MG_production_constraints(m,p)
		if !isempty(p.s.storage.types.elec)
			add_MG_storage_dispatch_constraints(m,p)
		else
			fix_MG_storage_variables(m,p)
		end
		add_cannot_have_MG_with_only_PVwind_constraints(m,p)
		add_MG_size_constraints(m,p)
		
		if !isempty(p.techs.gen)
			add_MG_fuel_burn_constraints(m,p)
			add_binMGGenIsOnInTS_constraints(m,p)
		else
			m[:ExpectedMGFuelUsed] = 0
			m[:ExpectedMGFuelCost] = 0
			@constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
				m[:binMGGenIsOnInTS][s, tz, ts] == 0
			)
		end
		
		if p.s.site.min_resil_time_steps > 0
			add_min_hours_crit_ld_met_constraint(m,p)
		end
	end

	# Note: renewable heat calculations are currently added in post-optimization
	add_re_elec_calcs(m,p)
	add_re_elec_constraints(m,p)
	add_yr1_emissions_calcs(m,p)
	add_lifecycle_emissions_calcs(m,p)
	add_emissions_constraints(m,p)
	
	if p.s.settings.off_grid_flag
		offgrid_other_capex_depr_savings = get_offgrid_other_capex_depreciation_savings(p.s.financial.offgrid_other_capital_costs, 
			p.s.financial.owner_discount_rate_fraction, p.s.financial.analysis_years, p.s.financial.owner_tax_rate_fraction)
		m[:OffgridOtherCapexAfterDepr] = p.s.financial.offgrid_other_capital_costs - offgrid_other_capex_depr_savings 
	end

	#################################  Objective Function   ########################################
	@expression(m, Costs,
		# Capital Costs
		m[:TotalTechCapCosts] + TotalStorageCapCosts + m[:GHPCapCosts] +

		# Fixed O&M, tax deductible for owner
		(TotalPerUnitSizeOMCosts + m[:GHPOMCosts]) * (1 - p.s.financial.owner_tax_rate_fraction) +

		# Variable O&M, tax deductible for owner
		(m[:TotalPerUnitProdOMCosts] + m[:TotalPerUnitHourOMCosts]) * (1 - p.s.financial.owner_tax_rate_fraction) +

		# Total Fuel Costs, tax deductible for offtaker
        m[:TotalFuelCosts] * (1 - p.s.financial.offtaker_tax_rate_fraction) +

		# CHP Standby Charges
		m[:TotalCHPStandbyCharges] * (1 - p.s.financial.offtaker_tax_rate_fraction) +

		# Utility Bill, tax deductible for offtaker
		m[:TotalElecBill] * (1 - p.s.financial.offtaker_tax_rate_fraction) -

        # Subtract Incentives, which are taxable
		m[:TotalProductionIncentive] * (1 - p.s.financial.owner_tax_rate_fraction) +

		# Comfort limit violation costs
		#TODO: add this to objective like SOC incentive below and 
		#don't then subtract out when setting lcc in results/financial.jl
		m[:dvComfortLimitViolationCost] + 

		# Additional annual costs, tax deductible for owner (only applies when `off_grid_flag` is true)
		p.s.financial.offgrid_other_annual_costs * p.pwf_om * (1 - p.s.financial.owner_tax_rate_fraction) +

		# Additional capital costs, depreciable (only applies when `off_grid_flag` is true)
		m[:OffgridOtherCapexAfterDepr]

	);
	if !isempty(p.s.electric_utility.outage_durations)
		add_to_expression!(Costs, m[:ExpectedOutageCost] + m[:mgTotalTechUpgradeCost] + m[:dvMGStorageUpgradeCost] + m[:ExpectedMGFuelCost])
	end
	# Add climate costs
	if p.s.settings.include_climate_in_objective # if user selects to include climate in objective
		add_to_expression!(Costs, m[:Lifecycle_Emissions_Cost_CO2]) 
	end
	# Add Health costs (NOx, SO2, PM2.5)
	if p.s.settings.include_health_in_objective
		add_to_expression!(Costs, m[:Lifecycle_Emissions_Cost_Health])
	end
	
	@expression(m, Objective,
		m[:Costs]
	)
		
	if !(isempty(p.s.storage.types.elec)) && p.s.settings.add_soc_incentive
		# Incentive to keep SOC high
		add_to_expression!(
			Objective, 
			- sum(
				m[:dvStoredEnergy][b, ts] for b in p.s.storage.types.elec, ts in p.time_steps
			) / (8760. / p.hours_per_time_step)
		)
	end
	if !isempty(p.s.electric_utility.outage_durations)
		# Incentive to minimize unserved load in each outage, not just the max over outage start times
		add_to_expression!(
			Objective, 
			sum(sum(0.0001 * m[:dvUnservedLoad][s, tz, ts] for ts in 1:p.s.electric_utility.outage_durations[s]) for s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps)
		)
	end

	@objective(m, Min, m[:Objective])
	
	# if !(isempty(p.s.storage.types.elec)) && p.s.settings.add_soc_incentive # Keep SOC high
	# 	@objective(m, Min, m[:Costs] - 
	# 	sum(m[:dvStoredEnergy][b, ts] for b in p.s.storage.types.elec, ts in p.time_steps) /
	# 		(8760. / p.hours_per_time_step)
	# 	)
	
	# end

	for b in p.s.storage.types.elec
		if p.s.storage.attr[b].model_degradation
			add_degradation(m, p; b=b)
			if p.s.settings.add_soc_incentive
				@warn "Settings.add_soc_incentive is set to true but no incentive will be added because it conflicts with the battery degradation model."
			end
		end
	end
    
	nothing
end


function run_reopt(m::JuMP.AbstractModel, p::REoptInputs; organize_pvs=true)

	try
		build_reopt!(m, p)

		@info "Model built. Optimizing..."
		tstart = time()
		optimize!(m)
		opt_time = round(time() - tstart, digits=3)
		if termination_status(m) == MOI.TIME_LIMIT
			status = "timed-out"
		elseif termination_status(m) == MOI.OPTIMAL
			status = "optimal"
		else
			status = "not optimal"
			@warn "REopt solved with " termination_status(m), ", returning the model."
			return m
		end
		@info "REopt solved with " termination_status(m)
		@info "Solving took $(opt_time) seconds."

		tstart = time()
		results = reopt_results(m, p)
		time_elapsed = time() - tstart
		@info "Results processing took $(round(time_elapsed, digits=3)) seconds."
		results["status"] = status
		results["solver_seconds"] = opt_time

		if organize_pvs && !isempty(p.techs.pv)  # do not want to organize_pvs when running BAU case in parallel b/c then proform code fails
			organize_multiple_pv_results(p, results)
		end

		# add error messages (if any) and warnings to results dict
		results["Messages"] = logger_to_dict()

		return results
	catch e
		if isnothing(e) # Error thrown by REopt
			handle_errors()
		else
			handle_errors(e, stacktrace(catch_backtrace()))
		end
	end
end


"""
    add_variables!(m::JuMP.AbstractModel, p::REoptInputs)

Add JuMP variables to the model.
"""
function add_variables!(m::JuMP.AbstractModel, p::REoptInputs)
	@variables m begin
		dvSize[p.techs.all] >= 0  # System Size of Technology t [kW]
		dvPurchaseSize[p.techs.all] >= 0  # system kW beyond existing_kw that must be purchased
		dvGridPurchase[p.time_steps, 1:p.s.electric_tariff.n_energy_tiers] >= 0  # Power from grid dispatched to meet electrical load [kW]
		dvRatedProduction[p.techs.all, p.time_steps] >= 0  # Rated production of technology t [kW]
		dvCurtail[p.techs.all, p.time_steps] >= 0  # [kW]
		dvProductionToStorage[p.s.storage.types.all, p.techs.all, p.time_steps] >= 0  # Power from technology t used to charge storage system b [kW]
		dvDischargeFromStorage[p.s.storage.types.all, p.time_steps] >= 0 # Power discharged from storage system b [kW]
		dvGridToStorage[p.s.storage.types.elec, p.time_steps] >= 0 # Electrical power delivered to storage by the grid [kW]
		dvStoredEnergy[p.s.storage.types.all, 0:p.time_steps[end]] >= 0  # State of charge of storage system b
		dvStoragePower[p.s.storage.types.all] >= 0   # Power capacity of storage system b [kW]
		dvStorageEnergy[p.s.storage.types.all] >= 0   # Energy capacity of storage system b [kWh]
		dvPeakDemandTOU[p.ratchets, 1:p.s.electric_tariff.n_tou_demand_tiers] >= 0  # Peak electrical power demand during ratchet r [kW]
		dvPeakDemandMonth[p.months, 1:p.s.electric_tariff.n_monthly_demand_tiers] >= 0  # Peak electrical power demand during month m [kW]
		MinChargeAdder >= 0
        binGHP[p.ghp_options], Bin  # Can be <= 1 if require_ghp_purchase=0, and is ==1 if require_ghp_purchase=1
	end

	if !isempty(p.techs.gen)  # Problem becomes a MILP
		@warn "Adding binary variable to model gas generator. Some solvers are very slow with integer variables."
		@variables m begin
			binGenIsOnInTS[p.techs.gen, p.time_steps], Bin  # 1 If technology t is operating in time step h; 0 otherwise
		end
	end

    if !isempty(p.techs.fuel_burning)
		@variable(m, dvFuelUsage[p.techs.fuel_burning, p.time_steps] >= 0) # Fuel burned by technology t in each time step [kWh]
    end

    if !isempty(p.s.electric_tariff.export_bins)
        @variable(m, dvProductionToGrid[p.techs.elec, p.s.electric_tariff.export_bins, p.time_steps] >= 0)
    end

	if !(p.s.electric_utility.allow_simultaneous_export_import) & !isempty(p.s.electric_tariff.export_bins)
		@warn "Adding binary variable to prevent simultaneous grid import/export. Some solvers are very slow with integer variables"
		@variable(m, binNoGridPurchases[p.time_steps], Bin)
	end

    if !isempty(p.techs.thermal)
        @variables m begin
			dvThermalProduction[p.techs.thermal, p.time_steps] >= 0
			dvSupplementaryThermalProduction[p.techs.chp, p.time_steps] >= 0
			dvSupplementaryFiringSize[p.techs.chp] >= 0  #X^{\sigma db}_{t}: System size of CHP with supplementary firing [kW]
		end
        if !isempty(p.techs.chp)
            @variable(m, dvProductionToWaste[p.techs.chp, p.time_steps] >= 0)
        end
    end

    if !isempty(p.techs.steam_turbine)
        @variable(m, dvThermalToSteamTurbine[p.techs.can_supply_steam_turbine, p.time_steps] >= 0)
    end

	if !isempty(p.s.electric_utility.outage_durations) # add dvUnserved Load if there is at least one outage
		@warn "Adding binary variable to model outages. Some solvers are very slow with integer variables"
		max_outage_duration = maximum(p.s.electric_utility.outage_durations)
		outage_time_steps = p.s.electric_utility.outage_time_steps
		tZeros = p.s.electric_utility.outage_start_time_steps
		S = p.s.electric_utility.scenarios
		# TODO: currently defining more decision variables than necessary b/c using rectangular arrays, could use dicts of decision variables instead
		@variables m begin # if there is more than one specified outage, there can be more othan one outage start time
			dvUnservedLoad[S, tZeros, outage_time_steps] >= 0 # unserved load not met by system
			dvMGProductionToStorage[p.techs.elec, S, tZeros, outage_time_steps] >= 0 # Electricity going to the storage system during each time_step
			dvMGDischargeFromStorage[S, tZeros, outage_time_steps] >= 0 # Electricity coming from the storage system during each time_step
			dvMGRatedProduction[p.techs.elec, S, tZeros, outage_time_steps]  # MG Rated Production at every time_step.  Multiply by production_factor to get actual energy
			dvMGStoredEnergy[S, tZeros, 0:max_outage_duration] >= 0 # State of charge of the MG storage system
			dvMaxOutageCost[S] >= 0 # maximum outage cost dependent on number of outage durations
			dvMGTechUpgradeCost[p.techs.elec] >= 0
			dvMGStorageUpgradeCost >= 0
			dvMGsize[p.techs.elec] >= 0
			
			dvMGFuelUsed[p.techs.elec, S, tZeros] >= 0
			dvMGMaxFuelUsage[S] >= 0
			dvMGMaxFuelCost[S] >= 0
			dvMGCurtail[p.techs.elec, S, tZeros, outage_time_steps] >= 0

			binMGStorageUsed, Bin # 1 if MG storage battery used, 0 otherwise
			binMGTechUsed[p.techs.elec], Bin # 1 if MG tech used, 0 otherwise
			binMGGenIsOnInTS[S, tZeros, outage_time_steps], Bin
		end
	end

	if p.s.settings.off_grid_flag
		@variables m begin
			dvOpResFromBatt[p.s.storage.types.elec, p.time_steps_without_grid] >= 0 # Operating reserves provided by the electric storage [kW]
			dvOpResFromTechs[p.techs.providing_oper_res, p.time_steps_without_grid] >= 0 # Operating reserves provided by techs [kW]
			1 >= dvOffgridLoadServedFraction[p.time_steps_without_grid] >= 0 # Critical load served in each time_step. Applied in off-grid scenarios only. [fraction]
		end
	end
end
