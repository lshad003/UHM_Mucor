import os
import json
import re
import csv

# Set base path to where all the Mucor samples are located
base_path = "/bigdata/stajichlab/lshad003/Mucor/annotation"
output_file = os.path.join(base_path, "antismash_summary.tsv")

# This list should match your folder names
samples = ["UHM10_S1", "UHM23_S2", "UHM31_S3", "UHM32_S4", "UHM35_S5"]

# Prepare output rows
rows = []

for sample in samples:
    regions_path = os.path.join(base_path, sample, "antismash_local", "regions.js")
    
    if not os.path.exists(regions_path):
        print(f"Missing file: {regions_path}")
        continue

    with open(regions_path) as f:
        content = f.read()

    # Extract JSON array from JS variable assignment
    match = re.search(r"var\s+recordData\s*=\s*(\[\s*{.*?}\s*]);", content, re.DOTALL)
    if not match:
        print(f"Could not parse: {regions_path}")
        continue

    json_data = json.loads(match.group(1))

    for record in json_data:
        scaffold = record.get("seq_id", "unknown")
        for region in record.get("regions", []):
            region_number = region.get("region_number", "NA")
            start = region.get("start", "NA")
            end = region.get("end", "NA")
            product = region.get("type", "NA")
            rows.append([sample, scaffold, region_number, start, end, product])

# Write to TSV
with open(output_file, "w", newline="") as out_f:
    tsv_writer = csv.writer(out_f, delimiter='\t')
    tsv_writer.writerow(["sample", "scaffold", "region", "start", "end", "type"])
    tsv_writer.writerows(rows)
    
print(f"Saved: {output_file}")



import pandas as pd
import matplotlib.pyplot as plt

# Load the TSV summary
df = pd.read_csv("/bigdata/stajichlab/lshad003/Mucor/annotation/antismash_summary.tsv", sep="\t")

# Drop rows with missing BGC type (just in case)
df = df.dropna(subset=["type"])

# Count BGC types per sample
bgc_counts = df.groupby(["sample", "type"]).size().unstack(fill_value=0)

# Plot
ax = bgc_counts.plot(kind="bar", stacked=True, figsize=(10, 6))
plt.title("Biosynthetic Gene Clusters (BGCs) by Sample")
plt.xlabel("Sample")
plt.ylabel("Count of BGCs")
plt.legend(title="BGC Type", bbox_to_anchor=(1.05, 1), loc="upper left")
plt.tight_layout()

# Display
plt.show()
