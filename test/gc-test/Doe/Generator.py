
# %pip install openpyxl

import json
import pandas as pd


df = pd.read_csv('test\gc-test\Doe\DoE.csv')
# print(df)

path = "test\gc-test\Doe\DoE.xlsx" # "path_to_csv": str(row[17]),
place = "56f071345457a351557112bc" #https://apps.openei.org/USURDB/rate/view/56f071345457a351557112bc

for index, row in df.iterrows():
    print(row[0],row[1], row[2])
    print("\n")


    item_data = {}


    item_data["PV"] = {
        df.columns[0]:int(row[0]),
        df.columns[1]:str(row[1]),
        df.columns[2]:str(row[2])
    }

    item_data["Site"] = {
        "longitude": str(row[0]),
        "latitude": str(row[1]),
        "roof_squarefeet": str(row[2]),
        "land_acres": str(row[3]),
        "node": str(row[4])
    }

    item_data["PV"] = {
        "macrs_bonus_fraction": str(row[5]), #Find out meaning
        "installed_cost_per_kw": str(row[6]),
        "tilt": str(row[7]),
        "degradation_fraction": str(row[8]),
        "macrs_option_years": str(row[9]),
        "federal_itc_fraction": str(row[10]),
        "module_type": str(row[11]),
        "array_type": str(row[12]),
        "om_cost_per_kw": str(row[13]),
        "macrs_itc_reduction": str(row[14]),
        "azimuth": str(row[15]),
        "federal_rebate_per_kw": str(row[16])
    }
    item_data["ElectricLoad"] = {
        "path_to_csv": path,
        "critical_load_fraction": str(row[17]),
        "year": str(row[18])
    },
    item_data["ElectricStorage"] =  {
        "total_rebate_per_kw": str(row[19]),
        "macrs_option_years": str(row[20]),
        "can_grid_charge": str(row[21]),
        "macrs_bonus_fraction": str(row[22]),
        "replace_cost_per_kw": str(row[23]),
        "replace_cost_per_kwh": str(row[24]),
        "installed_cost_per_kw": str(row[25]),
        "installed_cost_per_kwh": str(row[26]),
        "total_itc_fraction": str(row[27]),
        "charge_efficiency": str(row[28]) #origianl ref is 0.975**(1/2)*0.96
    },
    item_data["ElectricTariff"] = {
        "urdb_label": place #updated value for princeton
    },
    item_data["Financial"] =  {
        "elec_cost_escalation_rate_fraction": str(row[29]),
        "offtaker_discount_rate_fraction": str(row[30]),
        "owner_discount_rate_fraction": str(row[31]),
        "offtaker_tax_rate_fraction": str(row[32]),
        "owner_tax_rate_fraction": str(row[33]),
        "om_cost_escalation_rate_fraction": str(row[34])
    }

    # temp.append(item_data)

    var = f'case_{index+1}.json'
    print(var)

    with open (var, "w") as f:
        json.dump(item_data, f, indent=4)
