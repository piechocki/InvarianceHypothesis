# this script performs the central regression models as described in my thesis.
# the aggregated data that are required can be calculated with the python code
# in the other folders.

require(dplyr)
require(ggthemes)
require(ggplot2)
require(viridis)
require(sm)
require(car)
require(jtools)
require(tikzDevice)
require(expss)

# clear workspace and define new working directory
rm(list=ls())
# change this path to the folder where the data are located on your machine
setwd(paste("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/Daten", sep=""))

# create new empty dataframe for results
container <- data.frame(symbol=character(), month=character(), V=double(),
                        sigma=double(), W=double(), N=double(), X=double(),
                        P=double())
coefficient <- data.frame(symbol=character(), model=character(), mu=double(),
                          a=double(), p=double(), r_squared=double(),
                          r_adjusted=double(), a_se=double(), f_test_p=double(),
                          symbol_rm=character(), index=character(),
                          venue=character(), market=character())

# get list of corresponding csv files
trade_files <- list.files(path = "./Aggregationen", pattern="*Trades.csv$")
quote_files <- list.files(path = "./Aggregationen", pattern="*Quotes.csv$")

# new temporary dataframes
trades <- data.frame()
quotes <- data.frame()

# load all aggregations from csvs and append data to two dataframes
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

# merge aggregations of trades and quotes into one dataframe
container <- merge(trades, quotes, by=c("ticker","date"))

# drop all rows that contain tickers that has been excluded from sample
excluded_tickers <- c('FTIp.BS','FTIp.CHI','FTIp.TQ','TECp.BS',
                      'TECp.CHI','TECp.TQ','VLOF.PA','VNAd.BS',
                      'VNAd.CHI','VNAd.TQ','VNAn.DE','FRp.BS',
                      'FRp.CHI','FRp.TQ','FRTp.BS','FTI.PA')
container <- container[!container$ticker %in% excluded_tickers,]

# remove senseless days where spread is negative in average
container <- subset(container, bid_price<ask_price)

# calculate trading activity
container$W <- container$sigma_m_log * container$V
W_star <- mean(container$W)

# extract stock from ticker and add a column with its upper case value
container$stock <- do.call(rbind, strsplit(as.character(container$ticker), '.',
                                           fixed = TRUE))[,1]
container$stock_upper <- lapply(container$stock, function(v) {
  if (is.character(v)) return(toupper(v))
  else return(v)
})

# extract venue from ticker and deduce the market from it
# ("Primary" for Regulated Market or else "MTF")
container$venue <- do.call(rbind, strsplit(as.character(container$ticker), '.',
                                           fixed = TRUE))[,2]
container$venue <- ifelse(container$venue == "AS" | container$venue == "BR",
                          "PA", container$venue)
container$market <- ifelse(container$venue == "DE" | container$venue == "PA",
                           "Primary", "MTF")

# get a list with the tickers with members of the dax and cac
dax_ticker <- unlist(read.csv(file="./dax ticker.csv", header=FALSE, sep=","))
cac_ticker <- unlist(read.csv(file="./cac ticker.csv", header=FALSE, sep=","))

# compare the tickers with the lists and write the index ("DAX" or "CAC")
# into a new column
container$index <- ifelse(container$stock %in% dax_ticker |
                            container$stock_upper %in% dax_ticker,
                          "DAX",
                          ifelse(container$stock %in% cac_ticker |
                                   container$stock_upper %in% cac_ticker,
                                 "CAC",
                                 NA))

# ------------------------------------------------------------------------------
# leave this part out commented for analyses of the whole series (i.e. no time
# frame analysis). otherwise activate timeframe 1 OR timeframe 2 temporary
# (only one row should be executed for a useful calculation):
# timeframe 1
#container <- container[(container$date<20161000 & container$index=="CAC") |
#                       (container$date<=20160615 & container$index=="DAX"),]
# timeframe 2
#container <- container[(container$date>20161000 & container$index=="CAC") |
#                       (container$date>20160615 & container$index=="DAX"),]
# ------------------------------------------------------------------------------

# load the market caps from file and define a boolean variable "large_cap" that
# is TRUE for all market caps higher than the average
market_cap <- read.csv(file="./market cap.csv", sep=";")
market_cap$large_cap <- ifelse(market_cap$MARKET.CAPITALIZATION > median(
  market_cap$MARKET.CAPITALIZATION),1,0)

# for each ticker in container, find the column with this ticker in the market
# cap dataframe and save these column indeces in a vector
ticker_column <- ifelse(container$market=="Primary",1,ifelse(
  container$venue=="BS",2,ifelse(container$venue=="CHI",3,4)))

# do a vlookup of the large_cap value in the market cap dataframe dynamically
# with the specific column index as search column in vlookup
container$large_cap <- NA
for (i in 1:nrow(container)) {
  container$large_cap[i] <- vlookup(container$ticker[i], market_cap, 6,
                                    ticker_column[i])
}

# do a vlookup to get the ticker of the stock on the primary venue (RM)
container$ticker_rm <- NA
for (i in 1:nrow(container)) {
  x <- vlookup(container$ticker[i], market_cap, 1, ticker_column[i])
  container$ticker_rm[i] <- as.character.factor(x)
}

# # put the stocks into two groups dependent on the market cap
# a <- container[container$large_cap>mean(market_cap$MARKET.CAPITALIZATION),]
# b <- container[container$large_cap<=mean(market_cap$MARKET.CAPITALIZATION),]
# 
# # test whether the mean of volatility and of the traded volume is the equal in 
# # both groups
# t.test(a$sigma_m_log, b$sigma_m_log, var.equal=TRUE)
# t.test(a$V, b$V, var.equal=TRUE)

# define a sample (as a subset of container)
sample <- container #[container$venue=="TQ",]

# predict the six models
summary(model_trade_freq <- lm(log(N.x) ~ log(W/W_star),
                               data = sample))
summary(model_quote_freq <- lm(log(N.y) ~ log(W/W_star),
                               data = sample))
summary(model_trade_vol <- lm(log(X/(V/P)) ~ log(W/W_star),
                              data = sample))
summary(model_quote_vol <- lm(log(bid_size+ask_size) ~ log(W/W_star),
                              data = sample))
summary(model_abs_spread <- lm(log(ask_price-bid_price) ~ log(W/W_star),
                               data = sample))
summary(model_rel_spread <- lm(log(rel_spread) ~ log(W/W_star),
                               data = sample))

# plot the models
plot(log(sample$W/W_star), log(sample$N.x),
     pch = 16, cex = 0.1)
abline(model_trade_freq)
plot(log(sample$W/W_star), log(sample$N.y),
     pch = 16, cex = 0.1)
abline(model_quote_freq)
plot(log(sample$W/W_star), log(sample$X/(sample$V/sample$P)),
     pch = 16,cex = 0.1)
abline(model_trade_vol)
plot(log(sample$W/W_star), log(sample$bid_size+sample$ask_size),
     pch = 16, cex = 0.1)
abline(model_quote_vol)
plot(log(sample$W/W_star), log(sample$ask_price-sample$bid_price),
     pch = 16, cex = 0.1)
abline(model_abs_spread)
plot(log(sample$W/W_star), log(sample$rel_spread),
     pch = 16, cex = 0.1)
abline(model_rel_spread)

# do the regression now for every combination of symbol and venue
# therefore get a list with all unique tickers
rics <- as.character(levels(container$ticker)[as.integer(container$ticker)])
rics <- unique(rics)

# loop through all tickers
for (i in 1:length(rics)) {
  ric <- rics[i]
  # redefine the sample with the current ticker
  sample <- subset(container, container$ticker == ric)
  
  # predict all models with the new subsample
  model_trade_freq <- lm(log(N.x) ~ log(W/W_star),
                         data = sample)
  model_quote_freq <- lm(log(N.y) ~ log(W/W_star),
                         data = sample)
  model_trade_vol <- lm(log(X/(V/P)) ~ log(W/W_star),
                        data = sample)
  model_quote_vol <- lm(log(bid_size+ask_size) ~ log(W/W_star),
                        data = sample)
  model_abs_spread <- lm(log(ask_price-bid_price) ~ log(W/W_star),
                         data = sample)
  model_rel_spread <- lm(log(rel_spread) ~ log(W/W_star),
                         data = sample)
    
  # save desired data of each regression in a temporary container
  container_temp <- data.frame(
    r=ric,
    m=c("trade_freq",
        "quote_freq",
        "trade_vol",
        "quote_vol",
        "abs_spread",
        "rel_spread"),
    c1=c(as.numeric(model_trade_freq$coefficients[1]),
         as.numeric(model_quote_freq$coefficients[1]),
         as.numeric(model_trade_vol$coefficients[1]),
         as.numeric(model_quote_vol$coefficients[1]),
         as.numeric(model_abs_spread$coefficients[1]),
         as.numeric(model_rel_spread$coefficients[1])),
    c2=c(as.numeric(model_trade_freq$coefficients[2]),
         as.numeric(model_quote_freq$coefficients[2]),
         as.numeric(model_trade_vol$coefficients[2]),
         as.numeric(model_quote_vol$coefficients[2]),
         as.numeric(model_abs_spread$coefficients[2]),
         as.numeric(model_rel_spread$coefficients[2])),
    p=c(as.numeric(summary(model_trade_freq)$coefficients[2,"Pr(>|t|)"]),
        as.numeric(summary(model_quote_freq)$coefficients[2,"Pr(>|t|)"]),
        as.numeric(summary(model_trade_vol)$coefficients[2,"Pr(>|t|)"]),
        as.numeric(summary(model_quote_vol)$coefficients[2,"Pr(>|t|)"]),
        as.numeric(summary(model_abs_spread)$coefficients[2,"Pr(>|t|)"]),
        as.numeric(summary(model_rel_spread)$coefficients[2,"Pr(>|t|)"])),
    r_s=c(as.numeric(summary(model_trade_freq)$r.squared),
          as.numeric(summary(model_quote_freq)$r.squared),
          as.numeric(summary(model_trade_vol)$r.squared),
          as.numeric(summary(model_quote_vol)$r.squared),
          as.numeric(summary(model_abs_spread)$r.squared),
          as.numeric(summary(model_rel_spread)$r.squared)),
    r_a=c(as.numeric(summary(model_trade_freq)$adj.r.squared),
          as.numeric(summary(model_quote_freq)$adj.r.squared),
          as.numeric(summary(model_trade_vol)$adj.r.squared),
          as.numeric(summary(model_quote_vol)$adj.r.squared),
          as.numeric(summary(model_abs_spread)$adj.r.squared),
          as.numeric(summary(model_rel_spread)$adj.r.squared)),
    a_se=c(as.numeric(summary(model_trade_freq)$coefficients[2,"Std. Error"]),
           as.numeric(summary(model_quote_freq)$coefficients[2,"Std. Error"]),
           as.numeric(summary(model_trade_vol)$coefficients[2,"Std. Error"]),
           as.numeric(summary(model_quote_vol)$coefficients[2,"Std. Error"]),
           as.numeric(summary(model_abs_spread)$coefficients[2,"Std. Error"]),
           as.numeric(summary(model_rel_spread)$coefficients[2,"Std. Error"])),
    f_p=c(as.numeric(pf(summary(model_trade_freq)$fstatistic[1],
                        summary(model_trade_freq)$fstatistic[2],
                        summary(model_trade_freq)$fstatistic[3], lower=FALSE)),
          as.numeric(pf(summary(model_quote_freq)$fstatistic[1],
                        summary(model_quote_freq)$fstatistic[2],
                        summary(model_quote_freq)$fstatistic[3], lower=FALSE)),
          as.numeric(pf(summary(model_trade_vol)$fstatistic[1],
                        summary(model_trade_vol)$fstatistic[2],
                        summary(model_trade_vol)$fstatistic[3], lower=FALSE)),
          as.numeric(pf(summary(model_quote_vol)$fstatistic[1],
                        summary(model_quote_vol)$fstatistic[2],
                        summary(model_quote_vol)$fstatistic[3], lower=FALSE)),
          as.numeric(pf(summary(model_abs_spread)$fstatistic[1],
                        summary(model_abs_spread)$fstatistic[2],
                        summary(model_abs_spread)$fstatistic[3], lower=FALSE)),
          as.numeric(pf(summary(model_rel_spread)$fstatistic[1],
                        summary(model_rel_spread)$fstatistic[2],
                        summary(model_rel_spread)$fstatistic[3], lower=FALSE))),
    symbol_rm=sample$ticker_rm[1],
    index=sample$index[1],
    venue=sample$venue[1],
    market=sample$market[1])
  
  # rename temporary dataframe for merging
  names(container_temp) <- names(coefficient)
  
  # append the temporary container to the results dataframe
  coefficient <- rbind(coefficient, container_temp)
}

# split the data into dax and cac sample
dax <- coefficient[coefficient$index=="DAX",]
cac <- coefficient[coefficient$index=="CAC",]
# take only with those regressions that are significant and get rid of the rest
dax_p <- coefficient[coefficient$index=="DAX" & coefficient$p <= 0.05,]
cac_p <- coefficient[coefficient$index=="CAC" & coefficient$p <= 0.05,]

# calculate the means and further indicators for each model and venue
dax1 <- aggregate(dax$a, list(levels(dax$model)[as.integer(dax$model)],
                              levels(dax$venue)[as.integer(dax$venue)]),
                  FUN = function(x) c(mean = mean(x),
                                      min = min(x),
                                      max = max(x),
                                      median = median(x)))
dax2 <- aggregate(dax_p$a, list(levels(dax_p$model)[as.integer(dax_p$model)],
                                levels(dax_p$venue)[as.integer(dax_p$venue)]),
                  FUN = function(x) c(mean = mean(x),
                                      min = min(x),
                                      max = max(x),
                                      median = median(x)))
dax3 <- aggregate(dax$p, list(levels(dax$model)[as.integer(dax$model)],
                              levels(dax$venue)[as.integer(dax$venue)]),
                  FUN = function(x) c(p5 = sum(x<=0.05),
                                      p1 = sum(x<=0.01),
                                      n = length(x)))
dax4 <- aggregate(dax$r_squared, list(levels(dax$model)[as.integer(dax$model)],
                                      levels(dax$venue)[as.integer(dax$venue)]),
                  FUN = function(x) c(r_s=mean(x)))
dax5 <- aggregate(dax$r_adjusted, list(levels(dax$model)[as.integer(dax$model)],
                                      levels(dax$venue)[as.integer(dax$venue)]),
                  FUN = function(x) c(r_a=mean(x)))
# rename these dataframes to know the several content of each column, especially
# after the merging of all columns
names(dax4) <- c("Group.1","Group.2","r_squared")
names(dax5) <- c("Group.1","Group.2","r_adjusted")

# do the same for cac data
cac1 <- aggregate(cac$a, list(levels(cac$model)[as.integer(cac$model)],
                              levels(cac$venue)[as.integer(cac$venue)]),
                  FUN = function(x) c(mean = mean(x),
                                      min = min(x),
                                      max = max(x),
                                      median = median(x)))
cac2 <- aggregate(cac_p$a, list(levels(cac_p$model)[as.integer(cac_p$model)],
                                levels(cac_p$venue)[as.integer(cac_p$venue)]),
                  FUN = function(x) c(mean = mean(x),
                                      min = min(x),
                                      max = max(x),
                                      median = median(x)))
cac3 <- aggregate(cac$p, list(levels(cac$model)[as.integer(cac$model)],
                              levels(cac$venue)[as.integer(cac$venue)]),
                  FUN = function(x) c(p5 = sum(x<=0.05),
                                      p1 = sum(x<=0.01),
                                      n = length(x)))
cac4 <- aggregate(cac$r_squared, list(levels(cac$model)[as.integer(cac$model)],
                                      levels(cac$venue)[as.integer(cac$venue)]),
                  FUN = function(x) c(r_s=mean(x)))
cac5 <- aggregate(cac$r_adjusted, list(levels(cac$model)[as.integer(cac$model)],
                                      levels(cac$venue)[as.integer(cac$venue)]),
                  FUN = function(x) c(r_a=mean(x)))
names(cac4) <- c("Group.1","Group.2","r_squared")
names(cac5) <- c("Group.1","Group.2","r_adjusted")

# merge all means and indicators in one dataframe
dax_csv <- merge(merge(dax1, dax2, by=c("Group.1","Group.2"),
                       suffixes = c("all","significant")),
                 dax3, by=c("Group.1","Group.2"))
dax_csv <- merge(merge(dax_csv, dax4, by=c("Group.1","Group.2")),
                 dax5, by=c("Group.1","Group.2"))
# sorting of the result to have a uniform order
dax_csv <- dax_csv[order(dax_csv$Group.2, dax_csv$Group.1),]
# save the csv
write.csv(dax_csv, "./Regression/dax.csv", row.names=FALSE)

# and again do the same stuff for the dataframes of the cac data
cac_csv <- merge(merge(cac1, cac2, by=c("Group.1","Group.2"),
                       suffixes = c("all","significant")),
                 cac3, by=c("Group.1","Group.2"))
cac_csv <- cac_csv[order(cac_csv$Group.2, cac_csv$Group.1),]
cac_csv <- merge(merge(cac_csv, cac4, by=c("Group.1","Group.2")),
                 cac5, by=c("Group.1","Group.2"))
write.csv(cac_csv, "./Regression/cac.csv", row.names=FALSE)

# finally save the coefficients dataframe for later usage
write.csv(coefficient, "./Regression/coefficient.csv", row.names=FALSE)
