# -*- coding: utf-8 -*-
"""
Created on Wed Mar 15 12:51:50 2023

@author: evanc
"""

import pandas as pd
import json
import os

# Path to the directory containing JSON files
directory_path = 'test/gc-test/results'

# List all the JSON files in the directory
json_files = [f for f in os.listdir(directory_path) if f.endswith('.json')]

# Combine all the JSON files into a list of dictionaries
dict_list = []
for file in json_files:
    with open(os.path.join(directory_path, file)) as f:
        data = json.load(f)
        dict_list.append(data)

# Convert the list of dictionaries to a dataframe
df = pd.json_normalize(dict_list)

print(df.columns)

# Select specific columns from the dataframe. These will represent our metrics
df_selected = df[['ElectricStorage.size_kw', 'ElectricStorage.size_kwh','ElectricStorage.initial_capital_cost', 'ElectricUtility.lifecycle_emissions_tonnes_PM25','ElectricUtility.lifecycle_emissions_tonnes_SO2','ElectricUtility.lifecycle_emissions_tonnes_NOx','ElectricUtility.lifecycle_emissions_tonnes_CO2','ElectricTariff.lifecycle_fixed_cost_after_tax','ElectricTariff.lifecycle_energy_cost_after_tax','Site.total_renewable_energy_fraction', 'Site.annual_emissions_tonnes_PM25','PV.size_kw','PV.annual_energy_produced_kwh',"PV.lcoe_per_kwh",'PV.lifecycle_om_cost_after_tax','Financial.lcc','Financial.lifecycle_om_costs_after_tax','Financial.lifecycle_capital_costs_plus_om_after_tax','Financial.lifecycle_emissions_cost_health','Financial.lifecycle_outage_cost','Financial.initial_capital_costs_after_incentives','Financial.lifecycle_storage_capital_costs','Financial.lifecycle_om_costs_before_tax','Financial.lifecycle_emissions_cost_climate','Financial.lifecycle_fuel_costs_after_tax','Financial.lifecycle_capital_costs','Financial.replacements_future_cost_after_tax', 'Financial.developer_om_and_replacement_present_cost_after_tax']]

# Save the selected columns to a CSV file
df_selected.to_csv('ReOPT_output.csv', index=False)
# Print the resulting dataframe
print(df_selected.columns)

#PLACEHOLDER FOR TESTING ONLY
#df.to_csv('ReOPT_output.csv', index=False)



    
