#!/usr/bin/make -Rrf
SHELL=/bin/bash -o pipefail

#------------------------------------------------------------
# meta rules
#------------------------------------------------------------

.PHONY: check-params length-hist align percent-id
default: check-params length-hist align percent-id

check-params:
ifndef reads
	$(error missing parameter 'pe_reads' (paired-end reads))
endif
ifndef ref
	$(error missing parameter 'ref' (reference genome FASTA))
endif
ifndef name
	$(error missing parameter 'name' (output file prefix))
endif

length-hist: check-params $(name).length.hist
align: check-params $(name).sam.gz
percent-id: check-params $(name).percent-id.tab.gz

#------------------------------------------------------------
# analysis rules
#------------------------------------------------------------

# read length histogram
$(name).length.hist: $(reads)
	bioawk -c fastx '{print length($$seq)}' $^ | hist > $@.partial
	mv $@.partial $@

# read-to-ref alignments
$(name).sam.gz: $(reads)
	bwa-mem.mk bwa_opt=$(bwa_opt) query=$^ target=$(ref) \
		name=$(name).partial $(name).partial.sam.gz
	mv $(name).partial.sam.gz $@

# percent seq identity for each read
$(name).percent-id.tab.gz: $(name).sam.gz
	zcat $^ | samtools calmd -S - $(ref) | \
		sam2pairwise | pairwise2percentid | \
		gzip > $@.partial
	mv $@.partial $@