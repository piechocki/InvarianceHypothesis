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
                          a=double())

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
container$market <- ifelse(container$venue == "DE" | container$venue == "PA" |
                             container$venue == "AS" | container$venue == "BR",
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

# put the stocks into two groups dependent on the market cap
a <- container[container$large_cap>mean(market_cap$MARKET.CAPITALIZATION),]
b <- container[container$large_cap<=mean(market_cap$MARKET.CAPITALIZATION),]

# test whether the mean of volatility and of the traded volume is the equal in 
# both groups
t.test(a$sigma_m_log, b$sigma_m_log, var.equal=TRUE)
t.test(a$V, b$V, var.equal=TRUE)

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
# get a list with all unique tickers
rics <- as.list(levels(unique(container$ticker)))

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
    
  # save data in a temporary container
  container_temp <- data.frame(r=ric,
                             m=c("trade_freq", "quote_freq", "trade_vol",
                                 "quote_vol", "abs_spread", "rel_spread"),
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
                                  as.numeric(model_rel_spread$coefficients[2])))
  names(container_temp) <- names(coefficient)
  
  # append the temporary container to the result dataframe
  coefficient <- rbind(coefficient, container_temp)
}
