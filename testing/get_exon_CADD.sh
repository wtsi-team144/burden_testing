#!/bin/bash

gencode=$1
lfeatures=$2
ilist=$3
caddfile=$4
extend=$5
outfile=$6

if [[ -z ${extend} ]];then
    extend=50
fi
export extend=$extend

# Equivalent to: -g exon -x 50 -s CADD

zcat $gencode|while read chr start end gname ID;do
    start=$((start-1)) # linked features is 0-based
    
    tabix $lfeatures $chr:$start-$end | grep "\"gene_ID\":\"$ID\""| cut -f 5| perl -MJSON -lne 'BEGIN{$extend=$ENV{extend};}{%h = %{decode_json($_)};if ($h{source} eq "GENCODE" && $h{class} eq "exon"){$,="\t";print $h{"chr"},$h{"start"}-$extend,$h{"end"}+$extend;}}' | sort -k1,1 -k2,2n > 01.regions.CADD.bed

    n=$(cat 01.regions.CADD.bed | wc -l)
    if [[ $n -eq 0 ]];then
	continue
    fi    

    mergeBed -i 01.regions.CADD.bed > 02.regions.merged.CADD.bed

    n=$(cat 02.regions.merged.CADD.bed | wc -l)
    if [[ $n -eq 0 ]];then
	continue
    fi    

    # selecting variants from ilist
    # list is 1-based, BEDs are 0-based
    tabixstr=$(cat 02.regions.merged.CADD.bed| perl -lne '@a=split(/\t/);$s=$a[1]+1;print $a[0].":".$s."-".$a[2];'| tr '\n' ' ')
    tabix $ilist $tabixstr > 03.variants.CADD.txt

    n=$(cat 03.variants.CADD.txt | wc -l)
    if [[ $n -eq 0 ]];then
	continue
    fi
    
    # get CADD scores, omitting indels
    cat 03.variants.CADD.txt | perl -lne '@a=split(/\t/);$,="\t";if (length($a[3])==1 && length($a[4])==1){print $a[0],$a[1],$a[3],$a[4];}'|while read c p r a;do lines=$(tabix $caddfile $c":"$p"-"$p);score=$(echo "$lines" | awk -v a=$a 'BEGIN{FS="\t";b="NA";}$4==a{b=$6;}END{print b;}');echo $ID $c $p "." $r $a $score;done | tr ' ' '\t' | grep -v "NA" >> $outfile
    echo $ID
done










