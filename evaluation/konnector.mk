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
KONNECTOR_OPT=-k$k -j$j -vvv
# user-specified konnector options
konnector_opt?=

#------------------------------------------------------------
# meta rules
#------------------------------------------------------------

.PHONY: check-params check-bloom-params build-bloom
default: check-params $(name)_merged.fa.gz

check-params:
ifndef pe_reads
	$(error missing parameter 'pe_reads' (paired-end reads))
endif
ifndef k
	$(error missing parameter 'k' (kmer size))
endif
ifndef name
	$(error missing parameter 'name' (output file prefix))
endif

build-bloom: check-params $(bloom)

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

# run konnector
$(name)_merged.fa.gz: $(bloom) $(pe_reads) | $(dir $(name))
	/usr/bin/time -p -o $(name).time \
		$(konnector) $(KONNECTOR_OPT) -i <(zcat $<) -o $(name).partial \
		-t >(gzip >$(name).trace.gz) $(konnector_opt) $(pe_reads)
	gzip $(name).partial_*
	rename 's|$(name).partial|$(name)|' $(name).partial_*
