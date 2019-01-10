# this script performs several plots of the linear relationship of W and N and
# plots the distribution of the variables versus the normal distribution.
# tikz is used to write the plots into a tex file.

require(dplyr)
require(ggthemes)
require(ggplot2)
require(viridis)
require(sm)
require(car)
require(jtools)
require(tikzDevice)

# clear workspace and define new working directory
rm(list=ls())
# change this path to the folder where the data are located on your machine
setwd(paste("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/Daten", sep=""))

# create new empty dataframe for results
container <- data.frame(symbol=character(), month=character(), V=double(),
                        sigma=double(), W=double(), N=double(), X=double(),
                        P=double())

# load all aggregations from venue Dax
trades <- read.csv(file="./Aggregationen/DAX Xetra Trades.csv",
                  header=TRUE, sep=",")
quotes <- read.csv(file="./Aggregationen/DAX Xetra Quotes.csv",
                  header=TRUE, sep=",")

# merge aggregations of trades and quotes into one dataframe
container <- merge(trades, quotes, by=c("ticker","date"))

# calculate trading activity
container$W <- container$sigma_m_log * container$V

# data used in the thesis for this plot: j=Adidas, t=T (all days), v=Xetra
ads_sample <- container[which(container$ticker=="ADSGn.DE"),]

# rename trading frequency variable
ads_sample$N <- ads_sample$N.x

# plot W versus N before transformation
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/LaTeX/input/Plots/WN-before-transformation.tex"),
     height=2.85, width=2.95)
  ggplot(ads_sample, aes(x = W, y = N)) +
  geom_jitter(size=0.5) +
  geom_smooth(method = "lm", color=inferno(1, begin = 0.9),   se=FALSE) +
  geom_smooth(span   = 1,    color=viridis(1, begin = 0.7), se=FALSE,
              linetype="dashed") +
  xlim(c(0, 500000)) +
  ylim(c(0, 7500)) +
  xlab("$W$") +
  ylab("$N$")
dev.off()

# plot W versus N after transformation (log)
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/LaTeX/input/Plots/WN-after-transformation.tex"),
     height=2.85, width=2.95)
  ggplot(ads_sample, aes(x = log(W), y = log(N))) +
  geom_jitter(size=0.5) +
  geom_smooth(method = "lm", color=inferno(1, begin = 0.9), se=FALSE) +
  geom_smooth(span   = 1,    color=viridis(1, begin = 0.7), se=FALSE,
              linetype="dashed") +
  xlim(c(10, 14.5)) +
  ylim(c(6.5, 9.5)) +
  xlab("$\\ln(W)$") +
  ylab("$\\ln(N)$")
dev.off()

# calculate W_star, W over W_star and log of N
W_star <- mean(ads_sample$W)
ads_sample$midpoint <- (ads_sample$ask_price + ads_sample$bid_price) / 2
ads_sample$log_W_over_W_star <- log(ads_sample$W)/W_star
ads_sample$log_N <- log(ads_sample$N)

# plot W versus N again after transformation, now with W over W_star
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/LaTeX/input/Plots/WN-after-transformation2.tex"),
     height=2.85, width=2.95)
  ggplot(ads_sample, aes(x = log_W_over_W_star, y = log_N)) +
  geom_jitter(size=0.5) +
  geom_smooth(method = "lm", color=inferno(1, begin = 0.9), se=FALSE) +
  geom_smooth(span   = 1,    color=viridis(1, begin = 0.7), se=FALSE,
              linetype="dashed") +
  xlim(c(0.0000375, 0.0000525)) +
  ylim(c(7, 9.25)) +
  xlab("$\\ln(\\frac{W}{W_{*}})$") +
  ylab("$\\ln(N)$")
dev.off()

# plot the same relationships as before but with usual plot function (no ggplot)
# these plots are not used in the thesis
model1 <- lm(N ~ W, data = ads_sample)
model2 <- lm(log(N) ~ log(W), data = ads_sample)

tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/LaTeX/input/Plots/WN-before-transformation.tex"),
     height=3.5, width=3.1)
  plot(ads_sample$W, ads_sample$N, pch = 16, cex = 0.6, xlab = "$W$",
       ylab = "$N$", xlim=range(3000:40000), ylim=range(0:15000))
  abline(model1)
dev.off()

tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/LaTeX/input/Plots/WN-after-transformation.tex"),
     height=3.5, width=3.1)
  plot(log(ads_sample$W), log(ads_sample$N), pch = 16, cex = 0.6,
       xlab = "$\\ln(W)$", ylab = "$\\ln(N)$", xlim=range(8.5:11),
       ylim=range(7:10))
  abline(model2)
dev.off()

# plot the distribution of W and N before and after transformation in comparison
# to normal distribution
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/LaTeX/input/Plots/WN-density.tex"),
     height=5, width=6.2)
  par(mfrow=c(2,2))
  par(mar=c(4.5,2.5,0.8,0.8))
  d1 <- sm.density(ads_sample$W, model="normal", xlab = "$W$", ylab = "",
                   xlim=range(-2000000:3000000))
  d2 <- sm.density(log(ads_sample$W), model="normal", xlab = "$\\ln(W)$",
                   ylab = "", xlim=range(9:15))
  d3 <- sm.density(ads_sample$N, model="normal", xlab = "$N$", ylab = "",
                   xlim=range(-6000:14000))
  d4 <- sm.density(log(ads_sample$N), model="normal", xlab = "$\\ln(N)$",
                   ylab = "", xlim=range(6:10.5))
  par(mfrow=c(1,1))
dev.off()
