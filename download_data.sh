#!/bin/bash

## Description:
# Downloading data for later merging using merge_data.sh

script_version=1.0
last_modified=2020.Dec.10

## Built in versions:
GENCODE_release=32
Ensembl_release=98
GTExRelease=8

# Get script dir:
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## printing out information if no parameter is provided:
function usage {
    echo ""
    echo "Usage: $0 -o <output directory> : required, output directory"
    echo "          -e <ftp://ftp.ensembl.org> : optional, Ensembl FTP server"
    echo "          -s <download steps to perform> : optional, can be a range of the form: 2-4 or just one step (ranging from 1 to 7, see below); default: all steps"
    echo ""
    echo " This script was written to download data for the burden testing pipeline."
    echo ""
    echo ""
    echo "Version: ${script_version}, Last modified: ${last_modified}"
    echo ""
    echo "Steps:"
    echo "  1. Download VEP"
    echo "  2. Download GTEx (v${GTExRelease}) dataset"
    echo "  3: Download v${GENCODE_release} GENCODE release"
    echo "  4: Download v${Ensembl_release} ENSEMBL Regulation release"
    echo "  5: Download newest APPRIS release"
    echo "  6: Download Egen Phred scores"
    echo "  7: Download CADD scores"
    echo ""
    exit 0
}

# check if supplied steps are valid
function check_steps() {
    local s="$1"
    if [[ $s =~ ^[1-7]$ ]]; then
	:
    elif [[ $s =~ ^([1-7])-([1-7])$ ]];then
	i="${BASH_REMATCH[1]}"
	j="${BASH_REMATCH[2]}"
	if [[ $j -lt $i ]];then
            echo "[Error] Download steps are not valid: $s"
            echo "[Error] Exit"
	    exit 1
	else
	    :
	fi
    else
        echo "[Error] Download steps are not valid: $s"
        echo "[Error] Exit"
	exit 1
    fi
}

function get_first_step() {
    local s="$1"
    if [[ $s =~ ^[1-7]$ ]]; then
	echo $s
    elif [[ $s =~ ^([1-7])-([1-7])$ ]];then
	i="${BASH_REMATCH[1]}"
	echo $i
    else
        echo "[Error] Download steps are not valid: $s"
        echo "[Error] Exit"
	exit 1
    fi
}

function get_last_step() {
    local s="$1"
    if [[ $s =~ ^[1-7]$ ]]; then
	echo $s
    elif [[ $s =~ ^([1-7])-([1-7])$ ]];then
	j="${BASH_REMATCH[2]}"
	echo $j
    else
        echo "[Error] Download steps are not valid: $s"
        echo "[Error] Exit"
	exit 1
    fi
}

# axel wrapper
function custom_axel() {
    local fname="$1"
    local url="$2"
    if [ ! -e "$fname" ]; then
        echo "file not found, downloading: $fname"
        axel -an4 "$url" -o "$fname"
    elif [ -e "${fname}.st" ]; then
        echo "found partial download, resuming: $fname"
        axel -an4  "$url" -o "$fname"
    else
        echo "already have the file, skipped: $fname"
    fi
}

# Function to test if a given file exists or not in which case it reports and terminates the
# execution.
function testFile {
    if [[ ! -e "$1"  ]]; then
        echo "[Error] At this step something failed. The file was not created! $1"
        echo "[Error] Exit"
        exit 1
    fi
}

# We also run a test to check if the number of lines of a temporary file is zero or not.
# If it is zero, the script exits, because it indicates there were some problems.
function testFileLines {

    # Check if file is zipped:
    IsCompressed=$( file $1 | grep compressed | wc -l)

    # Check the number of lines:
    if [[ $IsCompressed -ne 0 ]]; then
        lines=$( zcat $1 | wc -l )
    else
        lines=$( cat $1 | wc -l )
    fi

    # exit if lines are zero:
    if [[ $lines == 0 ]]; then
        echo "[Error] file ($1) contains no lines. Exit";
        exit 1;
    fi
}

function info {
    hourMin=$(date +"%T" | awk 'BEGIN{FS=OFS=":"}{print $1, $2}')
    echo -ne "[Info ${hourMin}] $1"
}

# Printing help message if no parameters are given:
if [[ $# == 0 ]]; then usage; fi

# Processing command line options:
ensftp="ftp://ftp.ensembl.org"
OPTIND=1
outdir=""
steps="1-7"
while getopts "he:o:s:" optname; do
    case "$optname" in
        "h" ) usage ;;
        "e" ) ensftp="${OPTARG}" ;;
        "o" ) outdir="${OPTARG}" ;;
        "s" ) steps="${OPTARG}" ;;
        "?" ) usage ;;
        *) usage ;;
    esac;
done

check_steps "$steps"
step1=$(get_first_step $steps)
step2=$(get_last_step $steps)

echo "Download steps: $steps"
echo "First step: ${step1}"
echo "Last step: ${step2}"
echo ""

if [[ -z ${outdir} ]];then
    echo "[Error] no output directory specified"
    exit 1
fi

mkdir -p ${outdir}
if [ $? -ne 0 ] ; then
    echo "[Error] Could not create ${outdir}"
    exit 1
fi

# full dirname
outdir=`readlink -f $outdir`
outdir=${outdir%/}

targetDir=${outdir}"/prepare_regions_tempfiles"
mkdir -p ${targetDir}
if [ $? -ne 0 ] ; then
    echo "[Error] Could not create ${targetDir}"
    exit 1
fi

cd ${outdir}
cur_step=1
#===================================== VEP ===================================================

if [ ${cur_step} -ge ${step1} ] && [ ${cur_step} -le ${step2} ];then
    info "STEP 1. Downloading VEP data ...\n"
    git clone https://github.com/Ensembl/ensembl-vep.git
    cd ensembl-vep
    git checkout release/98
    mkdir -p ${outdir}/vep && cd ${outdir}/vep && custom_axel homo_sapiens_vep_98_GRCh38.tar.gz ftp://ftp.ebi.ac.uk/ensemblorg/pub/release-98/variation/indexed_vep_cache/homo_sapiens_vep_98_GRCh38.tar.gz && echo Unpacking ... && tar -xzf homo_sapiens_vep_98_GRCh38.tar.gz && rm homo_sapiens_vep_98_GRCh38.tar.gz && cd -
    sed 's/ensembl\.org/ebi\.ac\.uk\/ensemblorg/g' INSTALL.pl | sponge INSTALL.pl
    info "Done\n"
fi

cd ${outdir}
cur_step=2
#====================================== GTEx =================================================

if [ ${cur_step} -ge ${step1} ] && [ ${cur_step} -le ${step2} ];then
    #cd ${outdir}
    info "STEP 2. Downloading GTEx data ...\n"
    custom_axel GTEx_Analysis_v8_eQTL.tar https://storage.googleapis.com/gtex_analysis_v8/single_tissue_qtl_data/GTEx_Analysis_v8_eQTL.tar
    testFile "GTEx_Analysis_v8_eQTL.tar"
    info "Done\n"
fi

cur_step=3
#=================================== GENCODE =================================================

if [ ${cur_step} -ge ${step1} ] && [ ${cur_step} -le ${step2} ];then
    info "STEP 3. Downloading GENCODE data ...\n"
    mkdir -p ${targetDir}/GENCODE
    custom_axel ${targetDir}/GENCODE/gencode.v${GENCODE_release}.annotation.gtf.gz ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_${GENCODE_release}/gencode.v${GENCODE_release}.annotation.gtf.gz
    testFile "${targetDir}/GENCODE/gencode.v${GENCODE_release}.annotation.gtf.gz"
    info "Done\n"
fi

cur_step=4
#=================================== REGULATION ==============================================

if [ ${cur_step} -ge ${step1} ] && [ ${cur_step} -le ${step2} ];then
    info "STEP 4. Downloading Regulation data ...\n"
    mkdir -p ${targetDir}/EnsemblRegulation
    cells=$(curl -s ${ensftp}/pub/release-${Ensembl_release}/regulation/homo_sapiens/RegulatoryFeatureActivity/ | perl -lane 'print $F[-1]')
    if [ -z "${cells}" ]; then
	echo "[Error] No cell types were found in the Ensembl regulation folder: ${ensftp}/pub/release-${Ensembl_release}/regulation/homo_sapiens/RegulatoryFeatureActivity/"
	echo "Exit"
	exit 1
    fi

    #Download all cell type data:
    for cell in ${cells}; do
	echo "Downloading cell type : $cell"
	custom_axel ${targetDir}/EnsemblRegulation/${cell}.gff.gz ${ensftp}/pub/release-${Ensembl_release}/regulation/homo_sapiens/RegulatoryFeatureActivity/${cell}/homo_sapiens.GRCh38.${cell}.Regulatory_Build.regulatory_activity.20190329.gff.gz
	testFile "${targetDir}/EnsemblRegulation/${cell}.gff.gz"
    done
    info "Done\n"
fi

cur_step=5
#=================================== APPRIS ==================================================

if [ ${cur_step} -ge ${step1} ] && [ ${cur_step} -le ${step2} ];then
    info "STEP 5. Downloading APPRIS isoform data ...\n"
    mkdir -p ${targetDir}/APPRIS
    custom_axel ${targetDir}/APPRIS/appris_data.principal.txt http://apprisws.bioinfo.cnio.es/pub/current_release/datafiles/homo_sapiens/GRCh38/appris_data.principal.txt
    testFile "${targetDir}/APPRIS/appris_data.principal.txt"
    info "Done\n"
fi

cur_step=6
#=================================== EIGEN PHRED =============================================

if [ ${cur_step} -ge ${step1} ] && [ ${cur_step} -le ${step2} ];then
    info "STEP 6. Downloading Eigen Phred scores ...\n"
    mkdir -p scores
    custom_axel scores/eigen.phred_v2.dat ftp://anonymous@ftpexchange.helmholtz-muenchen.de:21021/ticketnr_3523523523525/eigen.phred_v2.dat
    testFile "scores/eigen.phred_v2.dat"
    custom_axel scores/eigen.phred_v2.dat.tbi ftp://anonymous@ftpexchange.helmholtz-muenchen.de:21021/ticketnr_3523523523525/eigen.phred_v2.dat.tbi
    testFile "scores/eigen.phred_v2.dat.tbi"
    info "Done\n"
fi

cur_step=7
#===================================== CADD  ================================================

if [ ${cur_step} -ge ${step1} ] && [ ${cur_step} -le ${step2} ];then
    info "STEP 7. Downloading CADD scores ...\n"
    mkdir -p scores
    custom_axel scores/whole_genome_SNVs.tsv.gz https://krishna.gs.washington.edu/download/CADD/v1.5/GRCh38/whole_genome_SNVs.tsv.gz
    testFile "scores/whole_genome_SNVs.tsv.gz"
    custom_axel scores/whole_genome_SNVs.tsv.gz.tbi https://krishna.gs.washington.edu/download/CADD/v1.5/GRCh38/whole_genome_SNVs.tsv.gz.tbi
    testFile "scores/whole_genome_SNVs.tsv.gz.tbi"
    info "Done\n"
fi

info "Download finished\n"
exit 0
