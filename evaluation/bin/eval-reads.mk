#!/usr/bin/make -Rrf
SHELL=/bin/bash -o pipefail

#------------------------------------------------------------
# params
#------------------------------------------------------------

# num threads
j?=1

#------------------------------------------------------------
# meta rules
#------------------------------------------------------------

.PHONY: check-params length-hist length-hist-plot align \
	percent-id percent-id-plot
default: check-params length-hist-plot align percent-id-plot

check-params:
ifndef reads
	$(error missing parameter 'reads' (paired-end reads))
endif
ifndef ref
	$(error missing parameter 'ref' (reference genome FASTA))
endif
ifndef name
	$(error missing parameter 'name' (output file prefix))
endif

length-hist: check-params $(name).length.hist
length-hist-plot: check-params $(name).length.hist.pdf
align: check-params $(name).sam.gz $(name).unmapped.sam.gz
percent-id: check-params $(name).percent-id.tab.gz
percent-id-plot: check-params $(name).percent-id.hist.pdf

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
		name=$(name).partial j=$j $(name).partial.sam.gz
	mv $(name).partial.sam.gz $@

# num unmapped reads
$(name).unmapped.sam.gz: $(name).sam.gz
	zcat $^ | awk 'and($$2,4)' | \
		gzip > $@

# percent seq identity for each read
$(name).percent-id.tab.gz: $(name).sam.gz
	zcat $^ | \
		awk '!and($$2,4)' | \
		sam2pairwise | pairwise2percentid | \
		gzip > $@.partial
	mv $@.partial $@

#------------------------------------------------------------
# plotting rules
#------------------------------------------------------------

$(name).length.hist.pdf: $(name).length.hist
	expand-hist $^ | length-hist.r > $@.partial
	mv $@.partial $@

$(name).percent-id.hist.pdf: $(name).percent-id.tab.gz
	zcat $^ | cut -f2 | percent-identity.r > $@.partial
	mv $@.partial $@
