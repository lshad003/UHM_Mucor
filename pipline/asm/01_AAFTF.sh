#!/bin/bash -l
#SBATCH -N 1 -n 1 -c 24 --mem 64gb --out logs/AAFTF.%a.log -a 1-5

# Requires AAFTF 0.3.1 or later for full support of fastp options used

MEM=64
CPU=${SLURM_CPUS_ON_NODE:-1}
N=${SLURM_ARRAY_TASK_ID:-$1}

if [ -z "$N" ]; then
    echo "Need an array id or command-line value for the job"
    exit 1
fi

module load AAFTF
module load fastp

FASTQ=input
SAMPLES=samples.csv
ASM=asm/AAFTF
WORKDIR=$SCRATCH  # You can set this to working_AAFTF if you prefer
PHYLUM=Mucoromycota

mkdir -p "$ASM" "$WORKDIR"

IFS=,
tail -n +2 "$SAMPLES" | sed -n "${N}p" | while IFS=',' read BASE SPECIES STRAIN NANOPORE ILLUMINASAMPLE SUBPHYLUM PHYLUM LOCUS RNASEQ DUMMY; do
    ID=$LOCUS

    LEFTIN="${FASTQ}/${BASE}_${ILLUMINASAMPLE}_R1_001.fastq.gz"
    RIGHTIN="${FASTQ}/${BASE}_${ILLUMINASAMPLE}_R2_001.fastq.gz"

    ASMFILE=${ASM}/${ID}.spades.fasta
    VECCLEAN=${ASM}/${ID}.vecscreen.fasta
    PURGE=${ASM}/${ID}.sourpurge.fasta
    CLEANDUP=${ASM}/${ID}.rmdup.fasta
    PILON=${ASM}/${ID}.pilon.fasta
    SORTED=${ASM}/${ID}.sorted.fasta
    STATS=${ASM}/${ID}.sorted.stats.txt

    echo "BASE is $BASE"

    if [ ! -f "$LEFTIN" ]; then
        echo "No input file found: $LEFTIN"
        exit 1
    fi

    LEFTTRIM=${WORKDIR}/${BASE}_1P.fastq.gz
    RIGHTTRIM=${WORKDIR}/${BASE}_2P.fastq.gz
    MERGETRIM=${WORKDIR}/${BASE}_fastp_MG.fastq.gz
    LEFT=${WORKDIR}/${BASE}_filtered_1.fastq.gz
    RIGHT=${WORKDIR}/${BASE}_filtered_2.fastq.gz
    MERGED=${WORKDIR}/${BASE}_filtered_U.fastq.gz

    echo "base=$BASE id=$ID strain=$STRAIN"

    if [ ! -f "$LEFT" ]; then
        if [ ! -f "$LEFTTRIM" ]; then
            AAFTF trim --method fastp --dedup --merge --memory $MEM --left "$LEFTIN" --right "$RIGHTIN" -c $CPU -o "${WORKDIR}/${BASE}_fastp" -ml 50
            AAFTF trim --method fastp --cutright -c $CPU --memory $MEM --left "${WORKDIR}/${BASE}_fastp_1P.fastq.gz" --right "${WORKDIR}/${BASE}_fastp_2P.fastq.gz" -o "${WORKDIR}/${BASE}_fastp2" -ml 50
            AAFTF trim --method bbduk -c $CPU --memory $MEM --left "${WORKDIR}/${BASE}_fastp2_1P.fastq.gz" --right "${WORKDIR}/${BASE}_fastp2_2P.fastq.gz" -o "${WORKDIR}/${BASE}" -ml 50
        fi
        AAFTF filter -c $CPU --memory $MEM -o "${WORKDIR}/${BASE}" --left "$LEFTTRIM" --right "$RIGHTTRIM" --aligner bbduk
        AAFTF filter -c $CPU --memory $MEM -o "${WORKDIR}/${BASE}" --left "$MERGETRIM" --aligner bbduk

        if [ -f "$LEFT" ]; then
            rm -f "$LEFTTRIM" "$RIGHTTRIM" "${WORKDIR}/${BASE}_fastp"*
            echo "Trimmed and filtered reads ready: $LEFT"
        else
            echo "Filtered files not created: ($LEFT, $RIGHT)"
            exit 1
        fi
    fi

    if [ ! -f "$ASMFILE" ]; then
        AAFTF assemble -c $CPU --left "$LEFT" --right "$RIGHT" --merged "$MERGED" --memory $MEM -o "$ASMFILE" -w "${WORKDIR}/spades_${ID}"
        if [ -s "$ASMFILE" ]; then
            rm -rf "${WORKDIR}/spades_${ID}/K"* "${WORKDIR}/spades_${ID}/tmp"
        else
            echo "SPAdes assembly failed."
            exit 1
        fi
    fi

    [ ! -f "$VECCLEAN" ] && AAFTF vecscreen -i "$ASMFILE" -c $CPU -o "$VECCLEAN"
    [ ! -f "$PURGE" ] && AAFTF sourpurge -i "$VECCLEAN" -o "$PURGE" -c $CPU --phylum "$PHYLUM" --left "$LEFT" --right "$RIGHT"
    [ ! -f "$CLEANDUP" ] && AAFTF rmdup -i "$PURGE" -o "$CLEANDUP" -c $CPU -m 500
    [ ! -f "$PILON" ] && AAFTF pilon -i "$CLEANDUP" -o "$PILON" -c $CPU --left "$LEFT" --right "$RIGHT" --mem $MEM
    [ ! -f "$PILON" ] && { echo "Error running Pilon. Exiting."; exit 1; }
    [ ! -f "$SORTED" ] && AAFTF sort -i "$PILON" -o "$SORTED"
    [ ! -f "$STATS" ] && AAFTF assess -i "$SORTED" -r "$STATS"

done

