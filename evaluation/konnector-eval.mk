#!/usr/bin/make -Rrf
SHELL=/bin/bash -o pipefail

#------------------------------------------------------------
# parameters
#------------------------------------------------------------

# path to konnector binary
konnector=konnector
# path to abyss-bloom binary
abyss_bloom=abyss-bloom
# user-specified abyss-bloom options
bloom_opt?=
# reads to load into Bloom filter
bloom_reads?=$(pe_reads)
# Bloom filter path
bloom?=$(name).bloom.gz
# num threads
j?=1
# required konnector options
KONNECTOR_OPT=-k$k -j$j -o $(name) -vvv
# user-specified konnector options
konnector_opt?=

#------------------------------------------------------------
# meta rules
#------------------------------------------------------------

.PHONY: check-params check-bloom-params build-bloom eval
default: check-params eval

check-params: check-bloom-params
ifndef ref
	$(error missing parameter 'ref' (reference genome FASTA))
endif

check-bloom-params:
ifndef pe_reads
	$(error missing parameter 'pe_reads' (paired-end reads))
endif
ifndef k
	$(error missing parameter 'k' (kmer size))
endif
ifndef name
	$(error missing parameter 'name' (output file prefix))
endif

build-bloom: check-bloom-params $(name).k$k.bloom.gz

#------------------------------------------------------------
# utility rules
#------------------------------------------------------------

%.gz: %
	gzip $^

#------------------------------------------------------------
# build bloom filter
#------------------------------------------------------------

# Bloom filter output dir
$(dir $(bloom)):
	mkdir -p $@

$(bloom): $(bloom_reads) | $(dir $(bloom))
	$(abyss_bloom) build -vvv -k$k -j$j -l2 $(bloom_opt) - $^ | \
		gzip > $@.partial
	mv $@.partial $@

#------------------------------------------------------------
# run konnector
#------------------------------------------------------------

# konnector output dir
$(dir $(name)):
	mkdir -p $@

$(name)_merged.fa: $(bloom) $(pe_reads) | $(dir $(name))
	$(konnector) $(KONNECTOR_OPT) -i <(zcat $<) $(konnector_opt) $(pe_reads)

#------------------------------------------------------------
# analyze konnector output
#------------------------------------------------------------

eval: $(name)_merged.fa.gz $(ref)
	eval-reads.mk name=$(name)_merged reads=$(name)_merged.fa.gz \
		ref=$(ref) bwa_opt=$(bwa_opt)
