# this script displays the independent variable and all used dependent variables
# together in one diagram to demonstrate the distribution over time.
# tikz is used to write the plots into a tex file.

require(dplyr)
require(ggthemes)
require(ggplot2)
require(viridis)
require(sm)
require(car)
require(jtools)
require(tikzDevice)
require(zoo)
require(gridExtra)
require(grid)

# clear workspace and define new working directory
rm(list=ls())
# change this path to the folder where the data are located on your machine
setwd(paste("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/Daten", sep=""))

# load the aggregated data of trades an quotes and merge it together (as already
# commented in the script "plots of w and n.R")
container <- data.frame(symbol=character(), month=character(), V=double(),
                        sigma=double(), W=double(), N=double(), X=double(),
                        P=double())

trade_files <- list.files(path = "./Aggregationen", pattern="*Trades.csv$")
quote_files <- list.files(path = "./Aggregationen", pattern="*Quotes.csv$")

trades <- data.frame()
quotes <- data.frame()

for (i in 1:length(trade_files)) {
  trade <- read.csv(file=paste0("./Aggregationen/", trade_files[i]),
                    header=TRUE, sep=",")
  quote <- read.csv(file=paste0("./Aggregationen/", quote_files[i]),
                    header=TRUE, sep=",")
  if (i == 1) {
    trades <- trade
    quotes <- quote
  } else {
    trades <- rbind(trades, trade)
    quotes <- rbind(quotes, quote)
  }
}

container <- merge(trades, quotes, by=c("ticker","date"))
excluded_tickers <- c('FTIp.BS','FTIp.CHI','FTIp.TQ','TECp.BS',
                      'TECp.CHI','TECp.TQ','VLOF.PA','VNAd.BS',
                      'VNAd.CHI','VNAd.TQ','VNAn.DE','FRp.BS',
                      'FRp.CHI','FRp.TQ','FRTp.BS','FTI.PA')
container <- subset(container, !ticker %in% excluded_tickers)
container$W <- container$sigma_m_log * container$V

mean_trades <- aggregate(container$N.x, list(container$date), mean)
mean_quotes <- aggregate(container$N.y, list(container$date), mean)

mean_W <- aggregate(container$W, list(container$date), mean)
mean_W_log <- aggregate(log(container$W), list(container$date), mean)

X_over_V <- aggregate(container$X/container$V, list(container$date), mean)
first_lvl_vol <- aggregate(container$ask_size+container$bid_size,
                           list(container$date), mean)

abs_spread <- aggregate(container$ask_price-container$bid_price,
                        list(container$date), mean)
rel_spread <- aggregate(container$rel_spread, list(container$date), mean)

# define a function for the labels of the time axis
my_date_format <- function()
{
  function(x)
  {
    m <- format(x,"%b")
    y <- format(x,"%Y")
    gsub(" ", "\n", ifelse(duplicated(y),m,paste(m, y)))
  }
}


# plot the number of quotes and trades
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
"Masterarbeit/LaTeX/input/Plots/number-trades-quotes-mean.tex"),
height=2.3, width=6.1)
  q <- ggplot(mean_quotes, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
    geom_line() + xlab("") + ylab("$\\overline{N_Q}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          axis.text.x=element_blank(),
          axis.ticks.x=element_blank(),
          plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
  t <- ggplot(mean_trades, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
    geom_line() + xlab("") + ylab("$\\overline{N_T}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          plot.margin=unit(c(0,0.1,0,0.1), "cm"))
  grid.draw(rbind(ggplotGrob(q), ggplotGrob(t), size = "first"))
dev.off()


# plot the trading activity and log trading activity
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
"Masterarbeit/LaTeX/input/Plots/W-Wlog-mean.tex"), height=2.3, width=6.1)
  w <- ggplot(mean_W, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) + 
    geom_line() + xlab("") + ylab("$\\bar{W}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          axis.text.x=element_blank(),
          axis.ticks.x=element_blank(),
          plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
  wlog <- ggplot(mean_W_log, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
    geom_line() + xlab("") + ylab("$\\bar{\\ln{W}}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          plot.margin=unit(c(0,0.1,0,0.1), "cm"))
  grid.draw(rbind(ggplotGrob(w), ggplotGrob(wlog), size = "first"))
dev.off()


# plot the traded volume and liquidity
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
"Masterarbeit/LaTeX/input/Plots/Vol-mean.tex"), height=2.3, width=6.1)
  vol1 <- ggplot(X_over_V, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
    geom_line() + xlab("") + ylab("$\\overline{X/V}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          axis.text.x=element_blank(),
          axis.ticks.x=element_blank(),
          plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
  vol2 <- ggplot(first_lvl_vol, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")),
                                    x)) + geom_line() + xlab("") + 
    ylab("$\\overline{X_b+X_a}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          plot.margin=unit(c(0,0.1,0,0.1), "cm"))
  grid.draw(rbind(ggplotGrob(vol1), ggplotGrob(vol2), size = "first"))
dev.off()


# plot the absolute and relative spread
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
"Masterarbeit/LaTeX/input/Plots/Spread-mean.tex"), height=2.3, width=6.1)
  spread1 <- ggplot(abs_spread, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")),
                                    x)) + geom_line() + xlab("") +
    ylab("$\\overline{P_a-P_b}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          axis.text.x=element_blank(),
          axis.ticks.x=element_blank(),
          axis.title.y = element_text(angle = 90, vjust=12),
          plot.margin=unit(c(0.1,0.1,0,0.9), "cm"))
  spread2 <- ggplot(rel_spread, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")),
                                    x)) + geom_line() + xlab("") + 
    ylab("$\\overline{(P_a-P_b)/M}$") +
    scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                     labels=my_date_format()) +
    scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                                 decimal.mark = ",",
                                                 scientific = FALSE)) +
    theme(legend.position="none",
          axis.title.x=element_blank(),
          axis.title.y = element_text(angle = 90, vjust=12),
          plot.margin=unit(c(0,0.1,0,0.9), "cm"))
  grid.draw(rbind(ggplotGrob(spread1), ggplotGrob(spread2), size = "first"))
dev.off()


# plot all seven variables together one upon the other
tikz(paste0("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
"Masterarbeit/LaTeX/input/Plots/all-variables-plot.tex"), height=8.2, width=6.1)
w <- ggplot(mean_W, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
  geom_line() + xlab("") + ylab("$\\overline{W}$") +
  scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                   labels=my_date_format()) +
  scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                               decimal.mark = ",",
                                               scientific = FALSE)) +
  theme(legend.position="none",
        axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
q <- ggplot(mean_quotes, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
  geom_line() + xlab("") + ylab("$\\overline{N_Q}$") +
  scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                   labels=my_date_format()) +
  scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                               decimal.mark = ",",
                                               scientific = FALSE)) +
  theme(legend.position="none",
        axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
t <- ggplot(mean_trades, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
  geom_line() + xlab("") + ylab("$\\overline{N_T}$") +
  scale_x_datetime(breaks = "1 month", minor_breaks = "1 week", 
                   labels=my_date_format()) +
  scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                               decimal.mark = ",",
                                               scientific = FALSE)) +
  theme(legend.position="none",
        axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
vol1 <- ggplot(X_over_V, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
  geom_line() + xlab("") + ylab("$\\overline{X/V}$") +
  scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                   labels=my_date_format()) +
  scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                               decimal.mark = ",",
                                               scientific = FALSE)) +
  theme(legend.position="none",
        axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
vol2 <- ggplot(first_lvl_vol, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
  geom_line() + xlab("") + ylab("$\\overline{X_b+X_a}$") +
  scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                   labels=my_date_format()) +
  scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                               decimal.mark = ",",
                                               scientific = FALSE)) +
  theme(legend.position="none",
        axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
spread1 <- ggplot(abs_spread, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
  geom_line() + xlab("") + ylab("$\\overline{P_a-P_b}$") +
  scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                   labels=my_date_format()) +
  scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                               decimal.mark = ",",
                                               scientific = FALSE)) +
  theme(legend.position="none",
        axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
spread2 <- ggplot(rel_spread, aes(as.POSIXct(strptime(Group.1, "%Y%m%d")), x)) +
  geom_line() + xlab("") + ylab("$\\overline{(P_a-P_b)/M*10000}$") +
  scale_x_datetime(breaks = "1 month", minor_breaks = "1 week",
                   labels=my_date_format()) +
  scale_y_continuous(labels=function(x) format(x, big.mark = ".",
                                               decimal.mark = ",",
                                               scientific = FALSE)) +
  theme(legend.position="none",
        axis.title.x=element_blank(),
        plot.margin=unit(c(0.1,0.1,0,0.1), "cm"))
grid.draw(rbind(ggplotGrob(w), ggplotGrob(q), ggplotGrob(t), ggplotGrob(vol1),
                ggplotGrob(vol2), ggplotGrob(spread1), ggplotGrob(spread2),
                size = "first"))
dev.off()
