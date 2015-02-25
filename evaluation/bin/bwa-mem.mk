#!/usr/bin/make -Rrf

SHELL:=/bin/bash -o pipefail

# number of threads
j?=1

ifndef query
error::
	$(error missing parameter 'query')
endif
ifndef target
error::
	$(error missing parameter 'target')
endif
ifndef name
error::
	$(error missing parameter 'name')
endif

default: $(name).sorted.bam.bai

$(target).bwt: $(target)
	bwa index $(target)

$(name).sam.gz: $(target).bwt $(query)
	abyss-tofastq $(query) | bwa mem -t$j $(bwa_opt) $(target) - | \
		gzip > $@.incomplete
	mv $@.incomplete $@

$(name).bam: $(name).sam.gz
	zcat $< | samtools view -bSo $@.incomplete -
	mv $@.incomplete $@

$(name).sorted.bam: $(name).bam
	samtools sort $< $(name).sorted

$(name).sorted.bam.bai: $(name).sorted.bam
	samtools index $<
