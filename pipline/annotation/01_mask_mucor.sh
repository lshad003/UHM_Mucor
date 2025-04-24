#!/usr/bin/bash -l
#SBATCH -N 1 -c 24 --mem 24gb --out logs/repeatmask.%a.log

module load RepeatModeler

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi
THREADS=$(expr $CPU / 4)
if [ $THREADS -eq 0 ]; then
    THREADS=1
fi

INDIR=asm/AAFTF
MASKDIR=analysis/RepeatMasker
SAMPLES=samples.csv
RMLIBFOLDER=lib/repeat_library
FUNGILIB=lib/fungi_repeat.20170127.lib
mkdir -p $RMLIBFOLDER
RMLIBFOLDER=$(realpath $RMLIBFOLDER)
N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi

MAX=$(wc -l $SAMPLES | awk '{print $1}')
if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPLES"
    exit
fi

IFS=,
PHYLUM="Mucoromycotina"

tail -n +2 $SAMPLES | sed -n ${N}p | while read BASE FileBase SPECIES STRAIN LOCUS TYPE
do
    name=$BASE
    mkdir -p $MASKDIR/$BASE
    GENOME=$(realpath $INDIR)/$BASE.sorted.fasta
    if [ ! -f $GENOME ]; then
        module load AAFTF
        AAFTF sort -ml 1000 -i $INDIR/$BASE.fcs_clean.fasta -o $GENOME
        module unload AAFTF
    fi
    FINAL=$(realpath $INDIR)/$BASE.masked.fasta
    if [ ! -s $MASKDIR/$BASE/$BASE.sorted.fasta.masked ]; then
        LIBRARY=$RMLIBFOLDER/$BASE.repeatmodeler.lib
        COMBOLIB=$RMLIBFOLDER/$BASE.combined.lib
        if [ ! -f $LIBRARY ]; then
            pushd $MASKDIR/$BASE
            BuildDatabase -name $BASE $GENOME
            RepeatModeler -threads $THREADS -database $BASE -LTRStruct
            rsync -a RM_*/consensi.fa.classified $LIBRARY
            rsync -a RM_*/families-classified.stk $RMLIBFOLDER/$BASE.repeatmodeler.stk
            popd
        fi
        if [ ! -s $COMBOLIB ]; then
            cat $LIBRARY $FUNGILIB > $COMBOLIB
        fi
        if [[ -s $LIBRARY && -s $COMBOLIB ]]; then
            module load RepeatMasker
            RepeatMasker -e ncbi -xsmall -s -pa $CPU -lib $COMBOLIB -dir $MASKDIR/$BASE -gff $GENOME
        fi
    else
        echo "Skipping $BASE as masked file already exists"
    fi
    if [ ! -f $FINAL ]; then
        rsync -a $MASKDIR/$BASE/$BASE.sorted.fasta.masked $FINAL
    fi
done
