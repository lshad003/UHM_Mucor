#!/usr/bin/bash -l
#SBATCH --nodes 1
#SBATCH --ntasks 8
#SBATCH --mem 16G
#SBATCH --time 12:00:00
#SBATCH --out logs/antismash.%A_%a.log
#SBATCH --job-name=antismash
#SBATCH --array=0-4

module load antismash

SAMPLES=(UHM10_S1 UHM23_S2 UHM31_S3 UHM32_S4 UHM35_S5)
CPU=${SLURM_CPUS_ON_NODE:-1}
SAMPLE=${SAMPLES[$SLURM_ARRAY_TASK_ID]}
BASE_DIR=~/bigdata/Mucor/annotation
GBK_FILE=$BASE_DIR/$SAMPLE/predict_results/Mucor_NA.gbk
OUTDIR=$BASE_DIR/$SAMPLE/antismash_local

echo "Processing $SAMPLE on $(hostname)"

if [[ -f $GBK_FILE ]]; then
  if [[ -d $OUTDIR ]]; then
    echo "Cleaning previous output at $OUTDIR"
    rm -rf "$OUTDIR"
  fi

  time antismash --taxon fungi --output-dir $OUTDIR \
       --genefinding-tool none --fullhmmer --clusterhmmer \
       --cb-general --pfam2go -c $CPU "$GBK_FILE"
else
  echo "Missing file: $GBK_FILE"
fi
