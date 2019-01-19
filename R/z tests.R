# this script performs several z-tests, based on the coefficients that are
# calculated with the script 'regression.r'.

# clear workspace and define new working directory
rm(list=ls())
# change this path to the folder where the data are located on your machine
setwd(paste("C:/Users/marti/OneDrive/Documents/OLAT/Master/4. Semester/",
            "Masterarbeit/Daten", sep=""))


coefficient <- read.csv(file="./Regression/coefficient.csv")
models <- c("trade_freq","quote_freq","trade_vol","quote_vol","abs_spread",
            "rel_spread")
venues <- c("DE", "PA")

# part 1: z-tests between different stocks
for (v in 1:length(venues)) {
  z_scores <- data.frame(symbol1=character(), symbol2=character(),
                         v=character(), z1=double(), z2=double(), z3=double(),
                         z4=double(), z5=double(), z6=double())
  venue <- venues[v]
  for (m in 1:length(models)) {
    model <- models[m]
    sample <- coefficient[coefficient$venue==venue & coefficient$model==model,]
    for (i in 1:nrow(sample)) {
      ric1 <- sample$symbol[i]
      for (j in 1:nrow(sample)) {
        ric2 <- sample$symbol[j]
        if(i<j) {
          z <- (sample$a[i]-sample$a[j]) /
            sqrt(sample$a_se[i]^2 + sample$a_se[j]^2)
          if(m==1) {
            z_score <- data.frame(s1=ric1, s2=ric2, v=venue, z1=z, z2=NA, z3=NA,
                                  z4=NA, z5=NA, z6=NA)
            names(z_score) <- names(z_scores)
            z_scores <- rbind(z_score, z_scores)
          } else {
            eval(parse(text=paste0("z_scores[z_scores$symbol1==ric1 & ",
                                            "z_scores$symbol2==ric2 & ",
                                            "z_scores$v==venue, 'z",
                                   m,
                                   "'] <- z")))
          }
        }
      }
    }
  }
  write.csv(z_scores, paste0("./Regression/z_scores_1_",
                             ifelse(venue=="DE","DAX","CAC"), ".csv"),
            row.names=FALSE)
}


# part 2: z-tests between different venues
indeces <- c("DAX", "CAC")

for (ind in 1:length(indeces)) {
  z_scores <- data.frame(symbol=character(), venue1=character(),
                         venue2=character(), z1=double(), z2=double(),
                         z3=double(), z4=double(), z5=double(), z6=double())
  index <- indeces[ind]
  if(index=="DAX") {
    venues <- c("BS","CHI","TQ","DE")
  } else {
    venues <- c("BS","CHI","TQ","PA")
  }
  stocks <- unique(coefficient[coefficient$index==index, "symbol_rm"])
  for (s in 1:length(stocks)) {
    stock <- as.character(stocks[s])
    for (m in 1:length(models)) {
      model <- models[m]
      sample <- coefficient[coefficient$index==index &
                              coefficient$model==model &
                              coefficient$symbol_rm==stock,]
      for (i in 1:nrow(sample)) {
        venue1 <- sample$venue[i]
        for (j in 1:nrow(sample)) {
          venue2 <- sample$venue[j]
          if(i<j) {
            z <- (sample$a[i]-sample$a[j]) /
              sqrt(sample$a_se[i]^2 + sample$a_se[j]^2)
            if(m==1) {
              z_score <- data.frame(s=stock, v1=venue1, v2=venue2, z1=z, z2=NA,
                                    z3=NA, z4=NA, z5=NA, z6=NA)
              names(z_score) <- names(z_scores)
              z_scores <- rbind(z_score, z_scores)
            } else {
              eval(parse(text=paste0("z_scores[z_scores$symbol==stock & ",
                                     "z_scores$venue1==venue1 & ",
                                     "z_scores$venue2==venue2, 'z",
                                     m,
                                     "'] <- z")))
            }
          }
        }
      }
    }
  }
  write.csv(z_scores, paste0("./Regression/z_scores_3_", index, ".csv"),
            row.names=FALSE)
}


# part 3: z-tests between different periods of time
coefficient_p1 <- read.csv(file="./Regression/coefficient_period1.csv")
coefficient_p2 <- read.csv(file="./Regression/coefficient_period2.csv")
venues <- c("DE", "PA")

for (v in 1:length(venues)) {
  z_scores <- data.frame(symbol=character(), v=character(), z1=double(),
                         z2=double(), z3=double(), z4=double(), z5=double(),
                         z6=double())
  venue <- venues[v]
  stocks <- unique(coefficient_p1[coefficient_p1$venue==venue, "symbol_rm"])
  for (s in 1:length(stocks)) {
    stock <- as.character(stocks[s])
    for (m in 1:length(models)) {
      model <- models[m]
      sample1 <- coefficient_p1[coefficient_p1$venue==venue &
                                coefficient_p1$symbol_rm==stock & 
                                coefficient_p1$model==model,]
      sample2 <- coefficient_p2[coefficient_p2$venue==venue &
                                coefficient_p2$symbol_rm==stock & 
                                coefficient_p2$model==model,]
      z <- (sample1$a-sample2$a) /
        sqrt(sample1$a_se^2 + sample2$a_se^2)
      
      if(m==1) {
        z_score <- data.frame(s=stock, v=venue, z1=z, z2=NA,
                              z3=NA, z4=NA, z5=NA, z6=NA)
        names(z_score) <- names(z_scores)
        z_scores <- rbind(z_score, z_scores)
      } else {
        eval(parse(text=paste0("z_scores[z_scores$symbol==stock & ",
                               "z_scores$v==venue, 'z",
                               m,
                               "'] <- z")))
      }
    }
  }
  write.csv(z_scores, paste0("./Regression/z_scores_2_",
                             ifelse(venue=="DE","DAX","CAC"),
                             ".csv"),
            row.names=FALSE)
}
