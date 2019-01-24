# this script calculates several aggregate measures for descriptice statistics. 
# the output is a dataframe with all measures separated for each venue and each
# index.

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
require(stringr)
require(expss)

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
container$stock <- do.call(rbind, strsplit(as.character(container$ticker), '.',
                                           fixed = TRUE))[,1]
container$stock_upper <- lapply(container$stock, function(v) {
  if (is.character(v)) return(toupper(v))
  else return(v)
})

container$venue <- do.call(rbind, strsplit(as.character(container$ticker), '.',
                                           fixed = TRUE))[,2]
container$market <- ifelse(container$venue == "DE" | container$venue == "PA",
                           "Primary", "MTF")

dax_ticker <- unlist(read.csv(file="./dax ticker.csv", header=FALSE, sep=","))
cac_ticker <- unlist(read.csv(file="./cac ticker.csv", header=FALSE, sep=","))
container$index <- ifelse(container$stock %in% dax_ticker |
                            container$stock_upper %in% dax_ticker,
                          "DAX",
                          ifelse(container$stock %in% cac_ticker |
                                   container$stock_upper %in% cac_ticker,
                                 "CAC",
                                 NA))

# create an empty dataframe for results
descriptive <- data.frame(indicator = character(0), dax_x = numeric(0),
                          dax_bs = numeric(0), dax_chi = numeric(0),
                          dax_tq = numeric(0), dax_mtfs = numeric(0),
                          dax_all = numeric(0), cac_e = numeric(0),
                          cac_bs = numeric(0), cac_chi = numeric(0),
                          cac_tq = numeric(0), cac_mtfs = numeric(0),
                          cac_all = numeric(0), all = numeric(0))

# define the aggregation as function because of the iterative and dynamic usage
add_aggregate_to_descriptive <- function(aggregate_name, field, funct)
{
  # definition of sub samples
  dax <- container[container$index == 'DAX', ]
  cac <- container[container$index == 'CAC', ]
  # definition of dynamic columns (on which later aggregation is done)
  field_all <- parse(text=field)
  field_dax <- parse(text=gsub("container", "dax", field))
  field_cac <- parse(text=gsub("container", "cac", field))
  
  # perform all aggregations for each sub sample
  aggregate_index <- aggregate(eval(field_all), list(container$index),
                               eval(substitute(funct)))
  aggregate_all <-  eval(substitute(funct(eval(field_all))))
  
  aggregate_venues_dax <- aggregate(eval(field_dax), list(dax$venue),
                                    eval(substitute(funct)))
  aggregate_market_dax <- aggregate(eval(field_dax), list(dax$market),
                                    eval(substitute(funct)))
  
  aggregate_venues_cac <- aggregate(eval(field_cac), list(cac$venue),
                                    eval(substitute(funct)))
  aggregate_market_cac <- aggregate(eval(field_cac), list(cac$market),
                                    eval(substitute(funct)))
  
  # save the data in a temporary dataframe
  aggregate_row <- data.frame(aggregate_name,
                              vlookup("DE", aggregate_venues_dax),
                              vlookup("BS", aggregate_venues_dax),
                              vlookup("CHI", aggregate_venues_dax),
                              vlookup("TQ", aggregate_venues_dax),
                              vlookup("MTF", aggregate_market_dax),
                              vlookup("DAX", aggregate_index),
                              vlookup("PA", aggregate_venues_cac),
                              vlookup("BS", aggregate_venues_cac),
                              vlookup("CHI", aggregate_venues_cac),
                              vlookup("TQ", aggregate_venues_cac),
                              vlookup("MTF", aggregate_market_cac),
                              vlookup("CAC", aggregate_index),
                              aggregate_all)
  names(aggregate_row) <- c("indicator",
                            "dax_x",
                            "dax_bs",
                            "dax_chi",
                            "dax_tq",
                            "dax_mtfs",
                            "dax_all",
                            "cac_e",
                            "cac_bs",
                            "cac_chi",
                            "cac_tq",
                            "cac_mtfs",
                            "cac_all",
                            "all")
  # append the temporary dataframe to the results
  descriptive <<- rbind(descriptive, aggregate_row)
}
na_values <- subset(container, is.na(index)) # this df should have a length of 0

# call the new function for appending one new row with aggregations to the
# descriptive dataframe:

# trade size
add_aggregate_to_descriptive("Tradegröße (Stück)", "container$X/container$N.x",
                             mean)
# number of quotes
add_aggregate_to_descriptive("Anzahl Quotes", "container$N.y", mean)
# number of trade
add_aggregate_to_descriptive("Anzahl Trades", "container$N.x", mean)
# daily trading volume
add_aggregate_to_descriptive("Tagesvolumen (EUR)", "container$V", mean)
# daily quote volume (first level of the orderbook)
add_aggregate_to_descriptive("Volumen an Orderbuchspitze (Stück)",
                             "container$ask_size+container$bid_size", mean)
# price
add_aggregate_to_descriptive("Preis (EUR)", "container$P", mean)
# volatility
add_aggregate_to_descriptive("Realisierte Rendite-Volatilität (EUR)",
                             "container$sigma_m_log", mean)
# absolute spread
add_aggregate_to_descriptive("Absoluter Spread (EUR)",
                             "container$ask_price-container$bid_price", mean)
# relative spread
add_aggregate_to_descriptive("Relativer Spread (bps)",
                             "container$rel_spread", mean)
# trading activity (W)
add_aggregate_to_descriptive("Handelsaktivität", "container$W", mean)

# save the statistics finally
write.csv(descriptive, file="descriptive statistics.csv", row.names=FALSE)


# calculate particular measures for the table "overview of the sample"
counter <- aggregate(container$date, by = list(container$ticker),
                     function(x){NROW(x)})
colnames(counter)<- c("ticker", "days")
max_date <- aggregate(container$date, by = list(container$ticker), max)
colnames(max_date)<- c("ticker", "max_date")
min_date <- aggregate(container$date, by = list(container$ticker), min)
colnames(min_date)<- c("ticker", "min_date")
X <- aggregate(container$X, by = list(container$ticker), sum)
colnames(X)<- c("ticker", "volume")
P <- aggregate(container$P, by = list(container$ticker), mean)
colnames(P)<- c("ticker", "price")
vola <- aggregate(container$sigma_m_log, by = list(container$ticker), mean)
colnames(vola)<- c("ticker", "vola")

counter <- merge(counter, min_date, by=c("ticker"))
counter <- merge(counter, max_date, by=c("ticker"))
counter <- merge(counter, X, by=c("ticker"))
counter <- merge(counter, P, by=c("ticker"))
counter <- merge(counter, vola, by=c("ticker"))

counter <- counter[order(tolower(counter$ticker)),]
write.csv(counter, "Übersicht der Stichprobe.csv")

#-------------------------------------------------------------------------------
# optional tests:
# comparison of average values with and without 24.06.2016 (outlier Brexit)
a <- container[container$date==20160624, ]
b <- container[!container$date==20160624, ]
mean(a$N.y)/mean(b$N.y)-1
mean(a$rel_spread)
mean(b$rel_spread)
