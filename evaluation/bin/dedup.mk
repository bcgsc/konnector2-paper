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

.PHONY: check-params
default: check-params $(name).fa.gz

check-params:
ifndef name
	$(error missing param 'name')
endif
ifndef reads
	$(error missing param 'reads')
endif

#------------------------------------------------------------
# main rules
#------------------------------------------------------------

$(reads).bwt: $(reads)
	bwa index $^

$(name).sam.gz: $(reads).bwt
	bwa mem -t$j -a $(reads) $(reads) | awk '!/^@/' | \
		TMPDIR=. sort | gzip > $@.partial
	mv $@.partial $@

$(name).fa.gz: $(name).sam.gz
	dedup-sam-gz $^ | gzip > $@.partial
	mv $@.partial $@
