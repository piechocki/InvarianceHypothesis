# this script performs an (optical) test on distribution of the variable log m
# by plotting the actual versus the normal distribution.
# tikz is used to write the plot into a tex file.

require(car)
require(sm)
require(tikzDevice)

# clear workspace and define new working directory
rm(list=ls())
# change this path to the folder where the data are located on your machine
setwd(paste("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/Daten", sep=""))

# data of log m used in the thesis: j=Adidas, t=01.10.2015, v=Xetra
log_return_midpoint_10_sec <- read.csv(file="./log midpoint 10 sec.csv",
                                       header=FALSE, sep=",")
summary(shapiro.test(log_return_midpoint_10_sec$V2))
sm.density(log_return_midpoint_10_sec$V2, display="se", model="normal")
shapiro.test(log_return_midpoint_10_sec$V2)

tikz(paste("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
           "Masterarbeit/LaTeX/input/Plots/log_M_distribution.tex", sep=""),
     height=3, width=4)
  par(mar=c(4.1,4.1,0.2,0.2))
  qqPlot(log_return_midpoint_10_sec$V2, pch = 20, cex = 0.5,
         xlab = "Quantile der Normalverteilung", ylab = "$\\ln(M)$")
dev.off()
