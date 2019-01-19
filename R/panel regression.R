# this script performs several again an ols regression, but now with pooled data
# (aka panel regression). the calculation is based on the container that is
# built with the script 'regression.r'.

require(nlme)
require(plm)

# clear workspace and define new working directory
rm(list=ls())
# change this path to the folder where the data are located on your machine
setwd(paste("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/Daten", sep=""))

# load the aggregated data and instanciate an empty dataframe for results
container <- read.csv(file="./Regression/container.csv")
coefficient <- data.frame(model=character(), mu=double(),
                          a=double(), p=double(), r_squared=double(),
                          r_adjusted=double(), a_se=double(), f_test_p=double(),
                          index=character(), venue=character(),
                          panel=character())

# definition of the number of iterations
models <- c("pooling","within","between","random")
venues <- c("DE", "PA", "BS", "CHI", "TQ")
indexes <- c("DAX", "CAC")

for (m in 1:1) { #length(models)) { #for further models, remove the first hash
  model <- models[m]
  for (v in 1:length(venues)) {
    venue <- venues[v]
    for (i in 1:length(indexes)) {
      index <- indexes[i]
      if(!((index == "DAX" & venue == "PA") | (index=="CAC" & venue=="DE"))) {
        # get the right sample for current iteration
        sample <- container[container$venue==venue & container$index==index,]
        
        # calculate the panel regression models
        model_trade_freq <- plm(log(N.x) ~ log(W), data=sample,
                                index = c("ticker","date"), model=model)
        model_quote_freq <- plm(log(N.y) ~ log(W), data=sample,
                                index = c("ticker","date"), model=model)
        model_trade_vol <- plm(log(X/(V/P)) ~ log(W), data=sample,
                               index = c("ticker","date"), model=model)
        model_quote_vol <- plm(log(bid_size+ask_size) ~ log(W), data=sample,
                               index = c("ticker","date"), model=model)
        model_abs_spread <- plm(log(ask_price-bid_price) ~ log(W), data=sample,
                                index = c("ticker","date"), model=model)
        model_rel_spread <- plm(log(rel_spread) ~ log(W), data=sample,
                                index = c("ticker","date"), model=model)
        
        # save all the model output data in a temporary dataframe
        container_temp <- data.frame(
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
          r_s=c(as.numeric(summary(model_trade_freq)$r.squared[1]),
                as.numeric(summary(model_quote_freq)$r.squared[1]),
                as.numeric(summary(model_trade_vol)$r.squared[1]),
                as.numeric(summary(model_quote_vol)$r.squared[1]),
                as.numeric(summary(model_abs_spread)$r.squared[1]),
                as.numeric(summary(model_rel_spread)$r.squared[1])),
          r_a=c(as.numeric(summary(model_trade_freq)$r.squared[2]),
                as.numeric(summary(model_quote_freq)$r.squared[2]),
                as.numeric(summary(model_trade_vol)$r.squared[2]),
                as.numeric(summary(model_quote_vol)$r.squared[2]),
                as.numeric(summary(model_abs_spread)$r.squared[2]),
                as.numeric(summary(model_rel_spread)$r.squared[2])),
          a_se=c(as.numeric(summary(
                   model_trade_freq)$coefficients[2,"Std. Error"]),
                 as.numeric(summary(
                   model_quote_freq)$coefficients[2,"Std. Error"]),
                 as.numeric(summary(
                   model_trade_vol)$coefficients[2,"Std. Error"]),
                 as.numeric(summary(
                   model_quote_vol)$coefficients[2,"Std. Error"]),
                 as.numeric(summary(
                   model_abs_spread)$coefficients[2,"Std. Error"]),
                 as.numeric(summary(
                   model_rel_spread)$coefficients[2,"Std. Error"])),
          f_p=c(as.numeric(summary(model_trade_freq)$fstatistic[4]),
                as.numeric(summary(model_quote_freq)$fstatistic[4]),
                as.numeric(summary(model_trade_vol)$fstatistic[4]),
                as.numeric(summary(model_quote_vol)$fstatistic[4]),
                as.numeric(summary(model_abs_spread)$fstatistic[4]),
                as.numeric(summary(model_rel_spread)$fstatistic[4])),
          index=index,
          venue=venue,
          panel=model)
        
        # rename temporary dataframe for merging
        names(container_temp) <- names(coefficient)
        
        # append the temporary container to the results dataframe
        coefficient <- rbind(coefficient, container_temp)
        
      }
    }
  }
}

# sort the results and write on disc
coefficient <- coefficient[order(coefficient$panel, coefficient$index,
                                 coefficient$venue, coefficient$model),]
write.csv(z_scores, "./Regression/coefficient_panel.csv", row.names=FALSE)


#-------------------------------------------------------------------------------
# optional and not used in the master thesis: linear mixed models
# (e.g. now with additional random effects)

# random intercept
mod1 <- lme(log(N.x) ~ log(W), random = ~1|ticker, data=sample)
summary(mod1)
# random intercept + slope (now with several covariates, only for testing)
mod2 <- lme(log(N.x) ~ log(W) + large_cap + rel_spread + sigma_m_log + sigma_s +
              N.y + P + V + X + sigma_r + sigma_p, random = ~1+log(W)|ticker,
            data=sample)
summary(mod2)
