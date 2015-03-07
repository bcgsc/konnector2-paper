#!/usr/bin/env Rscript
data=read.delim(file('stdin'), header=FALSE)
library(ggplot2)
pdf(file='|cat')
p = ggplot(data, aes(x=V1)) +
	geom_line(stat="bin",binwidth=1) +
	xlab("percent sequence identity") +
	ylab("count (log)") +
	ggtitle("Percent Sequence Identity of Pseudoreads") +
	scale_y_log10() +
	xlim(50,100) +
	scale_x_reverse()
print(p)
dev.off()
