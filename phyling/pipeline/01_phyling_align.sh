#!/usr/bin/bash -l
#SBATCH -p short --mem 128gb -c 128 --out logs/phyling_align.%A.log

module load phyling

COUNT=$(ls protein_input/*.fa | wc -l | awk '{print $1}')

phyling align -I protein_input \
  -m mucoromycota_odb10 \
  -o align-mucoromycota-taxa_${COUNT} -t 128 --verbose
