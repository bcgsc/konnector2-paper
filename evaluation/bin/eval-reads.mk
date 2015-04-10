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
	percent-id percent-id-plot genome-cov
default: check-params length-hist-plot align percent-id-plot \
	genome-cov

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
align: check-params $(name).sam.gz $(name).sorted.bam \
	$(name).unmapped.sam.gz
percent-id: check-params $(name).percent-id.tab.gz
percent-id-plot: check-params $(name).percent-id.hist.pdf
genome-cov: $(name).genome-cov.txt

#------------------------------------------------------------
# alignment rules
#------------------------------------------------------------

# read-to-ref alignments
$(name).sam.gz $(name).sorted.bam: $(reads)
	bwa-mem.mk bwa_opt=$(bwa_opt) query=$^ target=$(ref) \
		name=$(name).partial j=$j
	for file in $(name).partial.*{sam,bam}*; do \
		mv $$file $${file/.partial/}; \
	done

# save unmapped reads in separate file
$(name).unmapped.sam.gz: $(name).sam.gz
	zcat $^ | awk 'and($$2,4)' | \
		gzip > $@

# read-to-ref alignments (with multimapping)
$(name)-multimapped.sorted.bam: $(reads)
	bwa-mem.mk bwa_opt='-a $(bwa_opt)' query=$^ target=$(ref) \
		name=$(name)-multimapped.partial j=$j
	for file in $(name)-multimapped.partial.*{sam,bam}*; do \
		mv $$file $${file/.partial/}; \
	done

#------------------------------------------------------------
# analysis rules
#------------------------------------------------------------

# read length histogram
$(name).length.hist: $(reads)
	bioawk -c fastx '{print length($$seq)}' $^ | \
		hist > $@.partial
	mv $@.partial $@

# percent seq identity for each read
$(name).percent-id.tab.gz: $(name).sam.gz
	zcat $^ | \
		awk '!and($$2,4)' | \
		sam2pairwise | pairwise2percentid | \
		gzip > $@.partial
	mv $@.partial $@

# percentage genome coverage
$(name).genome-cov.txt: $(name)-multimapped.sorted.bam
	percent-genome-cov $^ > $@.partial
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
