#!/usr/bin/bash -l
#SBATCH -p short --mem 64gb -c 16 --out logs/phyling_tree.%A.log

module load phyling

# Set your filtered alignment directory and output folder
INPUT_DIR="/bigdata/stajichlab/lshad003/Mucor/phyling/filtered_align_64"
OUTPUT_DIR="/bigdata/stajichlab/lshad003/Mucor/phyling/tree_iqtree_64"

# Run PHYling tree module using IQ-TREE on consensus gene trees
phyling tree \
  -I "$INPUT_DIR" \
  -o "$OUTPUT_DIR" \
  -M iqtree \
  -f \
  -t 16 \
  --verbose
