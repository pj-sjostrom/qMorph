#############################
## Shawniya Alageswaran    ##
## 2025.12.17              ##
## Sjostrom Lab            ##
## McGill University       ##
## Montreal QC, Canada     ##
#############################
## Sholl Analysis -         ##
## Mixed-effect Model      ##
##                         ##
#############################
##################################################################################
# THE FOLLOWING CODE IS ADAPTED FROM:        
# ******
# Statistical analysis of Sholl profiles based on mixed-effect models
#
# Adrian Gabriel Zucco
# Center for Translational Neuromedicine
# University of Copenhagen
#
# Adapted from:
# Wilson, M. D., Sethi, S., Lein, P. J. & Keil, K. P.
# Valid statistical approaches for analyzing sholl data: Mixed effects
# versus simple linear models. Journal of Neuroscience Methods 279, 33-43 (2017).
# ******
##################################################################################

install.packages('mixpoissonreg')
install.packages("writexl")
library(dplyr)
library(readxl)
library(lme4)
library(emmeans)
library(writexl)

############ Installing needed packages if missing ############################
list.of.packages <-
  c("data.table",
    "lmerTest",
    "nlme",
    "reshape2",
    "ggplot2",
    "plyr",
    "dplyr",
    "MESS")
new.packages <-
  list.of.packages[!(list.of.packages %in% installed.packages()[, "Package"])]
if (length(new.packages)) {
  install.packages(new.packages)
}

library(data.table)
library(lmerTest)
library(nlme)
library(reshape2)
library(ggplot2)
library(plyr)
library(dplyr)
library(MESS)

options(contrasts = c(factor = "contr.SAS", ordered = "contr.poly"))

#change filepath to condition to analyze
data<-read.csv('/Users/shawniya/Documents/Analysis/Sholl Analysis/SR_Analysis/DataFiles/Sholl_axon_global.csv')

#reformatting
data$Animal_ID<-as.factor(data$animal_id)
data$Slice<-as.factor(data$Slice)
data$Cell<-as.factor(data$Cell)
data$Genotype<-as.factor(data$genotype)
data$Radius<-as.factor(data$radius)


# Sholl profile analysis with mixed effects models per radius
me_per_radius <-
  lmer(
    intersections ~ 1 + Radius  + Genotype + Radius:Genotype +  (1 |
                                                                     Animal_ID/Slice/Cell),
    data,
    REML = FALSE
  )

test_summ = summary(me_per_radius, ddf = "Satterthwaite") #gives you 2-tailed p value
print(test_summ, correlation = FALSE)

tvalue<-test_summ$coefficients[,"t value"]
cond_t<-tvalue[grep("Genotype",names(tvalue))]
df<-test_summ$coefficients[,"df"]
cond_df<-df[grep("Genotype",names(df))]
pv= test_summ$coefficients[, 5]
cond_pv= pv[grep("Genotype",names(pv))]

p_1tailed<-c()
for (t in 1:length(cond_t)){
  if (cond_t[t]<0){
    p_1tailed<-c(p_1tailed,pt(cond_t[t],cond_df[t],lower.tail=TRUE))
  } else{
    p_1tailed<-c(p_1tailed,pv[t])
  }
}

################# p-values adjustment ###########################
pvals = p_1tailed
cond_pvals = pvals[grep("Genotype", names(pvals))]
#Benjamini-Hochberg
padj <- as.data.frame(p.adjust(cond_pvals , method = "BH"))
padj$significance <-
  symnum(
    padj[, 1],
    corr = FALSE,
    na = FALSE,
    cutpoints = c(0, 0.001, 0.01, 0.05, 1),
    symbols = c("***", "**", "*", " ")
  )

print("Adjusted p-values: ")
padj
padj$comparison<-rownames(padj)
write_xlsx(x = padj, path = "PATH TO SAVE FILE TO WITH FILE NAME AT THE END")



