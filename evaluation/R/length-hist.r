#!/usr/bin/env Rscript
data=read.delim(file('stdin'), header=FALSE)
library(ggplot2)
pdf(file='|cat')
p = ggplot(data, aes(x=V1)) +
	geom_line(stat="bin", binwidth=500) +
	xlab("sequence length") +
	ylab("count (log)") +
	ggtitle("Lengths of Pseudoreads") +
	scale_y_log10()
print(p)
dev.off()
