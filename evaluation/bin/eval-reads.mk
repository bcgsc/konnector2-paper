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
	percent-id percent-id-plot percent-id-hist percent-id-cdf \
	genome-cov
default: check-params length-hist-plot align percent-id-plot \
	percent-id-hist percent-id-cdf genome-cov

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

check-merge-params:
ifndef part_names
	$(error missing required param 'part_names')
endif
ifndef name
	$(error missing required param 'name')
endif

length-hist: check-params $(name).length.hist
length-hist-plot: check-params $(name).length.hist.pdf
align: check-params $(name).sam.gz $(name).sorted.bam \
	$(name).unmapped.sam.gz
percent-id: check-params $(name).percent-id.tab.gz
percent-id-hist: check-params $(name).percent-id.hist
percent-id-cdf: check-params $(name).percent-id.cdf
percent-id-plot: check-params $(name).percent-id.hist.pdf
genome-cov: $(name).genome-cov.txt
merged-percent-id-hist: check-merge-params $(name).percent-id.merged.hist
merged-percent-id-cdf: check-merge-params $(name).percent-id.merged.cdf
merged-genome-cov: check-merge-params $(name).genome-cov.merged.txt
merge: check-merge-params merged-percent-id-hist merged-percent-id-cdf merged-genome-cov

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

$(name).percent-id.hist: $(name).percent-id.tab.gz \
	$(name).sam.gz
	paste \
		<(zcat $(name).percent-id.tab.gz | cut -f2) \
		<(zcat $(name).sam.gz | awk '!/^@/ && !and($$2,4)' | \
			sam2coord | cut -f5) | \
		percentid2hist > $@.partial
	mv $@.partial $@

$(name).bases-mapped.txt: $(name).percent-id.hist
	cut -f3 $< | sum > $@.partial
	mv $@.partial $@

$(name).percent-id.cdf: $(name).percent-id.hist $(name).bases-mapped.txt
	awk 'NR>1' $< | tac | cut -f2,3 | \
		awk -v total=`cat $(name).bases-mapped.txt` \
			'{sum+=$$2; printf("%.2f\t%.6f\n",$$1,sum/total)}' \
		> $@.partial
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

#------------------------------------------------------------
# merging results on split files
#------------------------------------------------------------

$(name).bases-mapped.total.txt: $(foreach prefix,$(part_names),$(prefix).bases-mapped.txt)
	cat $^ | sum > $@.partial
	mv $@.partial $@

$(name).percent-id.merged.hist: $(foreach prefix,$(part_names),$(prefix).percent-id.hist)
	merge-percentid-hist $^ > $@.partial
	mv $@.partial $@

$(name).percent-id.merged.cdf: $(name).percent-id.merged.hist $(name).bases-mapped.total.txt
	awk 'NR>1' $< | tac | cut -f2,3 | \
		awk -v total=`cat $(name).bases-mapped.total.txt` \
			'{sum+=$$2; printf("%.2f\t%.6f\n",$$1,sum/total)}' \
		> $@.partial
	mv $@.partial $@

$(name)-multimapped.sorted.merged.bam: $(foreach prefix,$(part_names),$(prefix)-multimapped.sorted.bam)
	samtools merge $@.partial $^
	mv $@.partial $@

$(name).genome-cov.merged.txt: $(name)-multimapped.sorted.merged.bam
	percent-genome-cov $^ > $@.partial
	mv $@.partial $@
