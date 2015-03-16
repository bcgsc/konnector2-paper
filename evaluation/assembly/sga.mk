#!/usr/bin/make -Rrf
SHELL=/bin/bash -o pipefail

#------------------------------------------------------------
# params
#------------------------------------------------------------

sga?=sga
verbose=-v
j?=1
min_kmer_cov=1
min_merge_overlap?=$(min_overlap)

#------------------------------------------------------------
# meta rules
#------------------------------------------------------------

.PHONY: index
default: check-params contigs

contigs: $(name)-contigs.fa

check-params:
ifndef name
	$(error missing parma 'name')
endif
ifndef reads
	$(error missing param 'reads')
endif
ifndef min_overlap
	$(error missing param 'min_overlap')
endif

#------------------------------------------------------------
# assembly rules
#------------------------------------------------------------

# flatten ambiguity codes in reads
$(name)-1.fa: $(reads)
	$(sga) preprocess $(verbose) \
		--permute-ambiguous -o $@ $^

# index
$(name)-1.bwt: $(name)-1.fa
	$(sga) index $(verbose) -t $j $^

# remove duplicate reads and contained reads
$(name)-2.fa $(name)-2.bwt: $(name)-1.fa $(name)-1.bwt
	$(sga) filter $(verbose) -t $j \
		--no-kmer-check -o $@ $<

# merge unambiguous overlaps
$(name)-3.fa: $(name)-2.fa $(name)-2.bwt
	$(sga) fm-merge $(verbose) \
		-m $(min_merge_overlap) -t $j -o $@ $<

# re-index
$(name)-3.bwt: $(name)-3.fa
	$(sga) index $(verbose) -t $j $^

# compute overlap graph
$(name)-3.asqg.gz: $(name)-3.fa $(name)-3.bwt
	$(sga) overlap $(verbose) \
		-m $(min_merge_overlap) -t $j $<

# assemble contigs
$(name)-contigs.fa: $(name)-3.asqg.gz
	$(sga) assemble -m $(min_overlap) -o $(name) $^
