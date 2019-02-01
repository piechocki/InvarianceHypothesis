# this script performs an ols regression again, but now with fixed effects
# within the data (aka panel regression with the 'within-model').
# after the panel regression the corresponding z-tests are performed as already
# done in the script 'z tests.r'
# the calculation is based on the container that is built with the script
# 'regression.r'.

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
models <- c("within") #,"pooling","between","random")
# for further models, remove the hash and closing bracket in the line above
venues <- c("DE", "PA") #, "BS", "CHI", "TQ")
indexes <- c("DAX", "CAC")

for (m in 1:length(models)) {
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
          p=c(as.numeric(summary(model_trade_freq)$coefficients[1,"Pr(>|t|)"]),
              as.numeric(summary(model_quote_freq)$coefficients[1,"Pr(>|t|)"]),
              as.numeric(summary(model_trade_vol)$coefficients[1,"Pr(>|t|)"]),
              as.numeric(summary(model_quote_vol)$coefficients[1,"Pr(>|t|)"]),
              as.numeric(summary(model_abs_spread)$coefficients[1,"Pr(>|t|)"]),
              as.numeric(summary(model_rel_spread)$coefficients[1,"Pr(>|t|)"])),
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
                   model_trade_freq)$coefficients[1,"Std. Error"]),
                 as.numeric(summary(
                   model_quote_freq)$coefficients[1,"Std. Error"]),
                 as.numeric(summary(
                   model_trade_vol)$coefficients[1,"Std. Error"]),
                 as.numeric(summary(
                   model_quote_vol)$coefficients[1,"Std. Error"]),
                 as.numeric(summary(
                   model_abs_spread)$coefficients[1,"Std. Error"]),
                 as.numeric(summary(
                   model_rel_spread)$coefficients[1,"Std. Error"])),
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
write.csv(coefficient, "./Regression/coefficient_panel.csv", row.names=FALSE)



# z-tests:
# part 1: z-tests between different venues
coefficient <- read.csv(file="./Regression/coefficient_panel.csv")
coefficient$a <- coefficient$mu
models <- c("trade_freq","quote_freq","trade_vol","quote_vol","abs_spread",
            "rel_spread")
venues <- c("DE", "PA")
indeces <- c("DAX", "CAC")

for (ind in 1:length(indeces)) {
  z_scores <- data.frame(venue1=character(), venue2=character(), z1=double(),
                         z2=double(), z3=double(), z4=double(), z5=double(),
                         z6=double())
  index <- indeces[ind]
  if(index=="DAX") {
    venues <- c("BS","CHI","TQ","DE")
  } else {
    venues <- c("BS","CHI","TQ","PA")
  }
  for (m in 1:length(models)) {
    model <- models[m]
    sample <- coefficient[coefficient$index==index &
                            coefficient$model==model,]
    for (i in 1:nrow(sample)) {
      venue1 <- sample$venue[i]
      for (j in 1:nrow(sample)) {
        venue2 <- sample$venue[j]
        if(i<j) {
          z <- (sample$a[i]-sample$a[j]) /
            sqrt(sample$a_se[i]^2 + sample$a_se[j]^2)
          if(m==1) {
            z_score <- data.frame(v1=venue1, v2=venue2, z1=z, z2=NA,
                                  z3=NA, z4=NA, z5=NA, z6=NA)
            names(z_score) <- names(z_scores)
            z_scores <- rbind(z_score, z_scores)
          } else {
            eval(parse(text=paste0("z_scores[z_scores$venue1==venue1 & ",
                                   "z_scores$venue2==venue2, 'z",
                                   m,
                                   "'] <- z")))
          }
        }
      }
    }
  }
  write.csv(z_scores, paste0("./Regression/z_scores_panel_3_", index, ".csv"),
            row.names=FALSE)
}


# part 2: z-tests between different periods of time
coefficient_p1 <- read.csv(file="./Regression/coefficient_panel_period1.csv")
coefficient_p2 <- read.csv(file="./Regression/coefficient_panel_period2.csv")
coefficient_p1$a <- coefficient_p1$mu
coefficient_p2$a <- coefficient_p2$mu
venues <- c("DE", "PA")

for (v in 1:length(venues)) {
  z_scores <- data.frame(v=character(), z1=double(),
                         z2=double(), z3=double(), z4=double(), z5=double(),
                         z6=double())
  venue <- venues[v]
  for (m in 1:length(models)) {
    model <- models[m]
    sample1 <- coefficient_p1[coefficient_p1$venue==venue &
                                coefficient_p1$model==model,]
    sample2 <- coefficient_p2[coefficient_p2$venue==venue &
                                coefficient_p2$model==model,]
    z <- (sample1$a-sample2$a) /
      sqrt(sample1$a_se^2 + sample2$a_se^2)
    
    if(m==1) {
      z_score <- data.frame(v=venue, z1=z, z2=NA,
                            z3=NA, z4=NA, z5=NA, z6=NA)
      names(z_score) <- names(z_scores)
      z_scores <- rbind(z_score, z_scores)
    } else {
      eval(parse(text=paste0("z_scores[z_scores$v==venue, 'z",
                             m,
                             "'] <- z")))
    }
  }
  write.csv(z_scores, paste0("./Regression/z_scores_panel_2_",
                             ifelse(venue=="DE","DAX","CAC"),
                             ".csv"),
            row.names=FALSE)
}




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
