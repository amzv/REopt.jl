import os
import pandas as pd

# Path to directory containing JSON files
json_dir = r"C:\Users\amzv3\Documents\Github\REopt.jl\test\gc-test\results"
output_file = r"C:\Users\amzv3\Documents\Github\REopt.jl\test\gc-test\Doe\results.csv"
# List of JSON files in the directory
json_files = [f for f in os.listdir(json_dir) if f.endswith(".json")]

# List to store the dataframes from each file
df_list = []

# Loop over the JSON files and create dataframes
for file in json_files:
    # Read the JSON file into a pandas dataframe
    with open(os.path.join(json_dir, file), "r") as f:
        df = pd.read_json(f)

    # Append the dataframe to the list
    df_list.append(df)

# Concatenate all dataframes in the list into a single dataframe
combined_df = pd.concat(df_list, ignore_index=True)

combined_df.to_csv(output_file)
print('file printed')
# Print the resulting dataframe
print(combined_df.head())