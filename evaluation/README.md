# Description

Scripts for running konnector and analyzing the results.

# Running Konnector

##Synopsis
```
konnector.mk name=out pe_reads='read1.fq read2.fq' k=60
```

The above command will build a Bloom filter and run Konnector.

* `name`: specifies the prefix for the output filenames
* `pe_reads` specifies the input reads to be konnected
* `k` specifies the kmer size used by abyss-bloom / konnector

# Evaluating Konnector pseudoreads (or pseudoreads from other tools)

## Synopsis
```
eval-reads.mk name=out reads=konnector_merged.fa.gz ref=ref.fa [subtarget]
```

The above command will align the reads to the given reference genome and calculate the read length histogram, percent identity of the individual reads, and the genome coverage of the reads.  Histogram plots will be generated for the read length and percent identity of the reads.


## Dependencies

This script has a lot of dependencies:

* R (ggplot package must be installed)
* bioawk
* bwa
* sam2pairwise (https://github.com/mlafave/sam2pairwise)
* bedtools

## Subtargets

Add a subtarget to the end of the command above to do only do part of the work (by default it will do everything):

* `percentid`: generate file containing read IDs and percent sequence identity to the reference (requires sam2pairwise)
* `percentid-plot`: generate a plot of the above data (requires R and ggplot)
* `length-hist`: generate a text file containing a length histogram of the reads (requires bioawk)
* `length-hist-plot`: generate a plot of the data (requires R and ggplot)
* `genome-cov`: calculate genome coverage of the reads (requires bedtools)

