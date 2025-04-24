#!/usr/bin/bash -l
#SBATCH -p short --mem 64gb -c 16 --out logs/phyling_filter.%A.log

module load phyling

# Define paths based on your actual alignment folder
INPUT_DIR="/bigdata/stajichlab/lshad003/Mucor/phyling/align-mucoromycota-taxa_64"
OUTPUT_DIR="/bigdata/stajichlab/lshad003/Mucor/phyling/filtered_align_64"

# Run the filter step to select top orthologs by treeness/RCV score
phyling filter \
  -I "$INPUT_DIR" \
  -o "$OUTPUT_DIR" \
  -n 50 \
  -t 16 \
  --verbose
