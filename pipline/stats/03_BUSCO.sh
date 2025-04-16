#!/bin/bash -l
#SBATCH --nodes 1 --ntasks 8 --mem 32G -p short --out logs/busco.%a.log -J busco -a 1-5

# Load environment
module unload miniconda3
module load busco/5.8.0
module load workspace/scratch

# Augustus config path (adjusted to a valid shared config path)
export AUGUSTUS_CONFIG_PATH=/bigdata/stajichlab/shared/pkg/augustus/3.3/config

# Set CPU
CPU=${SLURM_CPUS_ON_NODE}
if [ -z "$CPU" ]; then
    CPU=2
fi

# Get array index
N=${SLURM_ARRAY_TASK_ID}
if [ -z "$N" ]; then
    N=$1
    if [ -z "$N" ]; then
        echo "Need array id or command line argument"
        exit 1
    fi
fi

# Run settings
LINEAGE=mucoromycota_odb10
LINEAGE_PATH=/bigdata/stajichlab/lshad003/Mucor/busco_downloads
OUTFOLDER=BUSCO
GENOMEFOLDER=asm/AAFTF
EXT=pilon.fasta
SAMPLES=samples.csv
SEED_SPECIES=rhizopus_oryzae  # closest known model for Mucor

mkdir -p $OUTFOLDER

IFS=,  # set CSV delimiter
tail -n +2 $SAMPLES | sed -n ${N}p | while IFS=',' read BASE SPECIES STRAIN NANOPORE ILLUMINA SUBPHYLUM PHYLUM LOCUS RNASEQ DUMMY
do
    GENOMEFILE=$GENOMEFOLDER/${BASE}.${EXT}
    OUTNAME=${BASE}_busco

    if [ -f "$GENOMEFILE" ]; then
        echo "Running BUSCO on $GENOMEFILE"
        busco -i "$GENOMEFILE" \
              -o "$OUTNAME" \
              -m genome \
              -l "$LINEAGE" \
              -c "$CPU" \
              --offline \
              --force \
              --augustus_species "$SEED_SPECIES" \
              --download_path "$LINEAGE_PATH" \
              --out_path "$OUTFOLDER"
    else
        echo "Missing genome file: $GENOMEFILE"
    fi
done

