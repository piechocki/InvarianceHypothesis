# this script displays the distribution of the trades per minute of an example
# stock and venue (adidas and xetra).
# the actual distribution is compared to the assumed poisson distribution.
# tikz is used to write the plot into a tex file.

require(splines)
require(tikzDevice)

rm(list =ls())
setwd("C:/Users/marti/Documents/GitHub/InvarianceHypothesis")
distribution <- read.csv(file="./DAX Xetra Verteilung.csv", sep=",",
                         header = FALSE)
names(distribution) <- c("category", "frequency")
distribution <- distribution[order(distribution$category),]

# reconstruct the rawdata manually out of the already categorized data (because
# the hist() function needs the rawdata as input)
rawdata <- vector()
for (i in 1:nrow(distribution)) {
  category <- distribution[i,1]
  freq <- distribution[i,2]
  seq <- seq(from=category, by=0, length.out=freq)
  rawdata <- c(rawdata, seq)
}

tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
"Masterarbeit/LaTeX/input/Plots/trade-density.tex"), height=3.1, width=6.2)
  par(mar=c(4.9,4.5,0.6,2.1))
  hist(rawdata, prob=T, br=distribution$category, col="skyblue2",
       xlab="Trades pro Minute", ylab="Dichte",
       main=NULL, xlim = c(0,30), xaxt='n', yaxt='n')
  axis(side=1, at=seq(0.5,30.5,5), labels=seq(0,30,5))
  axis(side=2, at=seq(0,0.2,0.05), labels=format(seq(0,0.2,0.05),
                                                 big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE))
  real_poisson <- spline(dpois(seq(0,30,1), mean(rawdata)))
  # move curve 0.5 units of x to the left to be exactly on the axis labels (not
  # between)
  for (i in 1:length(real_poisson$x)){
    real_poisson$x[i]=real_poisson$x[i]-0.5
  }
  lines(real_poisson, col="red")
dev.off()
