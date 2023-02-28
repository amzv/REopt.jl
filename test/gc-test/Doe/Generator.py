
# %pip install openpyxl

import json
import pandas as pd


df = pd.read_csv('test/gc-test/Doe/test1.csv')
print(df.head)

path = "test/gc-test/Doe/test_load.csv" # "path_to_csv": str(row[17]),
place = "56f071345457a351557112bc" #https://apps.openei.org/USURDB/rate/view/56f071345457a351557112bc

for index, row in df.iterrows():

    item_data = {}

    if str(row[21]) == 'true':
        grid=True
    else:
        grid=False

    item_data["Site"] = {
        "longitude": row[0],
        "latitude": row[1],
        "roof_squarefeet": row[2],
        "land_acres": row[3],
        "node": row[4]
    }

    item_data["PV"] = {
        "macrs_bonus_fraction": row[5], #Find out meaning
        "installed_cost_per_kw": row[6],
        "tilt": row[7],
        "degradation_fraction": row[8],
        "macrs_option_years": row[9],
        "federal_itc_fraction": row[10],
        "module_type": row[11], #standar : 0, premium : 1 , thin_film: 2
        "array_type": row[12], #fixed : 1, one_axis : 2, one_axis_one_track : 3
        "om_cost_per_kw": row[13],
        "macrs_itc_reduction": row[14],
        "azimuth": row[15],
        "federal_rebate_per_kw": row[16]
    }
    item_data["ElectricLoad"] = {
        "path_to_csv": path,
        "critical_load_fraction": row[18],
        "year": str(row[17])
    },
    item_data["ElectricStorage"] =  {
        "total_rebate_per_kw": row[19],
        "macrs_option_years": row[20],
        "can_grid_charge": grid,
        "macrs_bonus_fraction": row[22],
        "replace_cost_per_kw": row[23],
        "replace_cost_per_kwh": row[24],
        "installed_cost_per_kw": row[25],
        "installed_cost_per_kwh": row[26],
        "total_itc_fraction": row[27],
        "charge_efficiency": row[28] #origianl ref is 0.975**(1/2)*0.96
    },
    item_data["ElectricTariff"] = {
        "urdb_label": str(place) #updated value for princeton
    },
    item_data["Financial"] =  {
        "elec_cost_escalation_rate_fraction": row[29],
        "offtaker_discount_rate_fraction": row[30],
        "owner_discount_rate_fraction": row[31],
        "offtaker_tax_rate_fraction": row[32],
        "owner_tax_rate_fraction": row[33],
        "om_cost_escalation_rate_fraction": row[34]
    }

    # temp.append(item_data)

    var = f'test\gc-test\Doe\Scenarios\case_{index+1}.json'
    print(var)

    with open (var, "w") as f:
        json.dump(item_data, f, indent=4)
