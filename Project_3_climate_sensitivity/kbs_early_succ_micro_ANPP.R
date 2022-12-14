### KBS Early Successional Microplot ANPP — Main Cropping System Experiment (MCSE) Data Cleaning ###

## Data manipulation packages
library(tidyverse)
library(SPEI)
library(ggpp)
library(nlme)
library(emmeans)
library(MuMIn)
library(visreg)
library(car)
library(piecewiseSEM)
#https://lter.kbs.msu.edu/datatables/448
kbs_monthly_MET= read.table(here::here("Project_3_climate_sensitivity","KBS_data","448-monthly+precipitation+and+air+temperature+1666860249.csv"),
                            sep = ",", header = T)
head(kbs_monthly_MET)
dim(kbs_monthly_MET)
#417   6

#Calculate balances

kbs_monthly_MET$PET <- thornthwaite(kbs_monthly_MET$air_temp_mean, 42.415329)
kbs_monthly_MET$BAL <- kbs_monthly_MET$precipitation-kbs_monthly_MET$PET
summary(kbs_monthly_MET)
ggplot(kbs_monthly_MET,aes(x=year, y=BAL))+geom_point(aes(color=month))
kbs_monthly_MET_ts=ts(kbs_monthly_MET[,-c(1,2)],end = c(2022,9), frequency=12)

#6 month spei 
spei_KBS6=spei(kbs_monthly_MET_ts[,"BAL"], 6)
spei_KBS6_df=try_data_frame(spei_KBS6$fitted)
colnames(spei_KBS6_df)=c("time","SPEI_6m")
head(spei_KBS6_df)
spei_KBS6_df$year=format(as.Date(spei_KBS6_df$time),"%Y")
spei_KBS6_df$month=format(as.Date(spei_KBS6_df$time),"%m")
spei_KBS6_df$time=NULL
head(spei_KBS6_df)

#Annual precip and max temp
head(kbs_monthly_MET)
kbs_monthly_MET_annual=kbs_monthly_MET|>group_by(year)|>
  summarise(air_temp_max_max=max(air_temp_max), annual_precip=sum(precipitation))


#https://lter.kbs.msu.edu/datatables/686
source("Data_cleaning/kbs_early_succ_microplot_msce_cleaning.R") # extra column is disturbance treatment



head(KBS_spp_clean)
dim(KBS_spp_clean)
#4103   20
colnames(KBS_spp_clean)
unique(KBS_spp_clean$nadd)
unique(KBS_spp_clean$disturbance)
#Remove disturbed and nfert

KBS_spp_clean_control=subset(KBS_spp_clean, nadd=="unfertilized")
dim(KBS_spp_clean_control)
#424  20

#Summarize 

KBS_spp_clean_control_tot=KBS_spp_clean_control|>group_by(year,month,plot,nadd,uniqueID,disturbance)|>
  summarise(ANPP=sum(abundance))
dim(KBS_spp_clean_control_tot)
summary(as.numeric(KBS_spp_clean_control_tot$year))

#Annual temp and precip

KBS_spp_clean_control_tot_temp_precip=merge(KBS_spp_clean_control_tot, kbs_monthly_MET_annual,
                                            by="year" )
head(KBS_spp_clean_control_tot_temp_precip)
KBS_spp_clean_control_tot_temp_precip=KBS_spp_clean_control_tot_temp_precip|>mutate(ANPP_scale=scale(ANPP), air_temp_max_max_scale=scale(air_temp_max_max), annual_precip_scale=scale(annual_precip))

dim(KBS_spp_clean_control_tot_temp_precip)



kbs_temp_precip_mod=lme(ANPP_scale~air_temp_max_max_scale+annual_precip_scale,
                    data=KBS_spp_clean_control_tot_temp_precip,
                    random=~1|plot,method="ML")

summary(kbs_temp_precip_mod)

summary(KBS_spp_clean_control_tot_temp_precip[,c("annual_precip","air_temp_max_max")])

# Extract model components
kbs_temp_precip_mod_est <- scicomptools::nlme_extract(fit = kbs_temp_precip_mod)

# Take a look
kbs_temp_precip_mod_est


KBS_rain_temp_sub=KBS_spp_clean_control_tot_temp_precip[!duplicated(KBS_spp_clean_control_tot_temp_precip$year),]
ggplot(KBS_rain_temp_sub|>pivot_longer(cols = c(annual_precip,air_temp_max_max),names_to = "measure",values_to = "value"), aes(x=value))+geom_density()+facet_wrap(~measure,scales = "free")


#Identify the anomalies 
quantile(KBS_rain_temp_sub$air_temp_max_max, c(0.05, 0.95)) ## find 5th and 9th percentile
quantile(KBS_rain_temp_sub$annual_precip, c(0.05, 0.95))
KBS_spei_sub$anomalies <- ifelse(KBS_spei_sub$SPEI_6m >= 1.763899, "anomaly",
                                 ifelse(KBS_spei_sub$SPEI_6m <= -1.384875, "anomaly", "normal")) ## classify 


ggplot(KBS_spei_sub, aes(x=SPEI_6m))+geom_density()+geom_dotplot(aes(color=anomalies,fill=anomalies))



#SPEI time
head(spei_KBS6_df)
KBS_spp_clean_control_spei=merge(KBS_spp_clean_control_tot, spei_KBS6_df,
                                            by=c("year","month") )
head(KBS_spp_clean_control_spei)
KBS_spp_clean_control_spei=KBS_spp_clean_control_spei|>mutate(ANPP_scale=scale(ANPP),
                                                              SPEI_6m_scale=scale(SPEI_6m))
dim(KBS_spp_clean_control_spei)

kbs_spei_mod=lme(ANPP_scale~SPEI_6m,
                    data=KBS_spp_clean_control_spei,
                    random=~1|plot,method="ML")
summary(KBS_spp_clean_control_spei$SPEI_6m)
summary(KBS_spp_clean_control_spei)
summary(kbs_spei_mod)

# Extract model components
kbs_spei_mod_est <- scicomptools::nlme_extract(fit = kbs_spei_mod)

# Take a look
kbs_spei_mod_est

ggplot(KBS_spp_clean_control_spei, aes(x=SPEI_6m,y=ANPP_scale))+geom_point()+
  geom_abline(slope = kbs_spei_mod_est[kbs_spei_mod_est$Term=="SPEI_6m",]$Value,
              intercept = kbs_spei_mod_est[kbs_spei_mod_est$Term=="(Intercept)",]$Value)+
  geom_smooth(color="red")

KBS_spei_sub=KBS_spp_clean_control_spei[!duplicated(KBS_spp_clean_control_spei[,c("month","year")]),]
ggplot(KBS_spei_sub, aes(x=SPEI_6m))+geom_density()

#Identify the anomalies 
quantile(KBS_spei_sub$SPEI_6m, c(0.05, 0.95)) ## find 5th and 9th percentile
KBS_spei_sub$anomalies <- ifelse(KBS_spei_sub$SPEI_6m >= 1.763899, "anomaly",
                             ifelse(KBS_spei_sub$SPEI_6m <= -1.384875, "anomaly", "normal")) ## classify 


ggplot(KBS_spei_sub, aes(x=SPEI_6m))+geom_density()+geom_dotplot(aes(color=anomalies,fill=anomalies))

#####Top five taxa####
colnames(KBS_spp_clean_control)

#total spp biomass

kbs_spp_biomass_tot<-KBS_spp_clean_control|>
  group_by(species)|>
  summarise(spp_bio_tot=sum(abundance))

ggplot(kbs_spp_biomass_tot,aes(x=spp_bio_tot))+
  geom_histogram()

kbs_spp_biomass_tot$species
kbs_spp_biomass_tot[order(kbs_spp_biomass_tot$spp_bio_tot,decreasing = T),][1:5,]$species

KBS_spp_clean_control_tops<-
  KBS_spp_clean_control[KBS_spp_clean_control$species%in%kbs_spp_biomass_tot[order(kbs_spp_biomass_tot$spp_bio_tot,decreasing = T),][1:6,]$species,]


ggplot(KBS_spp_clean_control_tops,aes(x=as.numeric(year),y=abundance))+
  geom_point()+facet_wrap(~species,scales = "free_y")

#####Non-linear code section #####
#some sites have multiple sampling dates

#Let's take the final harvest from each year 

kbs_mcse_e_succ_last=kbs_mcse_e_succ|>group_by(year,treatment,replicate,method,disturbed,fertilized)|>
  top_n(1,as.Date(sample_date))
dim(kbs_mcse_e_succ_last)
#709  10
kbs_mcse_e_succ_last$month

kbs_mcse_e_succ_last_spei=merge(kbs_mcse_e_succ_last,
                                spei_KBS6_df, 
                                by=c("year","month"))
dim(kbs_mcse_e_succ_last_spei)

#numeric year
kbs_mcse_e_succ_last_spei$year=as.numeric(kbs_mcse_e_succ_last_spei$year)

#Experimental year 

kbs_mcse_e_succ_last_spei$expyear=kbs_mcse_e_succ_last_spei$year-min(kbs_mcse_e_succ_last_spei$year)+1
summary(kbs_mcse_e_succ_last_spei)
#There is a split plot design which I am not sure how to handle... 
#Let's make a unique value for plot replicate
kbs_mcse_e_succ_last_spei|>group_by(disturbed,method)|>summarise(n())

kbs_mcse_e_succ_last_spei$uniq_replicate=with(kbs_mcse_e_succ_last_spei, 
                                         interaction(replicate,fertilized,disturbed,method))




#Model selection----------------
#Candidate model set
#L=linear, Q=quadratic, C=cubic, a=additive, i=interaction
m.null<-lme(biomass_g_m2~year*fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.La<-lme(biomass_g_m2~SPEI_6m+fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Li<-lme(biomass_g_m2~SPEI_6m*fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Qa<-lme(biomass_g_m2~SPEI_6m+fertilized+I(SPEI_6m^2),data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Qi<-lme(biomass_g_m2~SPEI_6m*fertilized+I(SPEI_6m^2)*fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Ca<-lme(biomass_g_m2~SPEI_6m+fertilized+I(SPEI_6m^2)+I(SPEI_6m^3),data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Ci<-lme(biomass_g_m2~SPEI_6m*fertilized+I(SPEI_6m^2)*fertilized+I(SPEI_6m^3)*fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")

m.La<-lme(biomass_g_m2~SPEI_6m+fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Li<-lme(biomass_g_m2~SPEI_6m*fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Qa<-lme(biomass_g_m2~SPEI_6m+fertilized+I(SPEI_6m^2),data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Qi<-lme(biomass_g_m2~SPEI_6m*fertilized+I(SPEI_6m^2)*fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Ca<-lme(biomass_g_m2~SPEI_6m+fertilized+I(SPEI_6m^2)+I(SPEI_6m^3),data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Ci<-lme(biomass_g_m2~SPEI_6m*fertilized+I(SPEI_6m^2)*fertilized+I(SPEI_6m^3)*fertilized,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")

# model selection
AICc(m.null, m.La,m.Li,m.Qa,m.Qi,m.Ca,m.Ci)
AICc(m.null, m.La,m.Li,m.Qa,m.Qi,m.Ca,m.Ci)[AICc(m.null, m.La,m.Li,m.Qa,m.Qi,m.Ca,m.Ci)[,2]<=
                                              min(AICc(m.null, m.La,m.Li,m.Qa,m.Qi,m.Ca,m.Ci)[,2])+2,]
#Best model is m.null
#m.null  6 4320.802
# AR1 - autocorrelation 1, AR1 - autocorrelation 2 to best model from above
#This is only necessary if year includes non-integer numbers
int.year <- kbs_mcse_e_succ_last_spei$expyear*2-1 #convert to integer
kbs_mcse_e_succ_last_spei$expyear <- int.year
#Fit temporal autocorrelation models
m.AR1<-update(m.null,correlation=corAR1(form=~expyear))
m.AR2<-update(m.null,correlation=corARMA(form=~expyear,p=2))
# model selection
AICc(m.null,m.AR1,m.AR2)
# best model m.AR2

rsquared(m.AR2)
#Marginal R2:  the proportion of variance explained by the fixed factor(s) alone
#Conditional R2: he proportion of variance explained by both the fixed and random factors

#Evaluate model assumptions

plot(m.AR2)#a bit funnel shaped
qqPlot(residuals(m.AR2))
hist(residuals(m.AR2))

#Do sketchy frequentist tests on best model
anova(m.AR2,type="marginal")#F test
Anova(m.AR2,type=2)# Chisq test. Mostly similar except for significance of "SPEI_6m"

#Param estimates and post-hoc pairwise comparisons
emtrends(m.AR2,~ fertilized | degree, "year", max.degree = 3)
pairs(emtrends(m.AR2,~ fertilized | degree , "year", max.degree = 3))


#Visualize CSF results---------------------
# get a plot of estimated values from the model, by each depth
# visreg with ggplot graphics
#visreg(fit=m.AR2,"SPEI_6m",type="conditional",by="fertilized",gg=TRUE,partial=F,rug=F)+ 
 # geom_point(aes(x=SPEI_6m,y=biomass_g_m2,col=year),alpha=0.2,data=kbs_mcse_e_succ_last_spei)+
#  theme_bw()+
#  labs(x="SPEI",
 #      y="Aboveground total cover")

#Alternative visualization code if the above doesn't work
kbs_mcse_e_succ_last_spei$predicted<-predict(m.AR2, kbs_mcse_e_succ_last_spei)
ggplot(kbs_mcse_e_succ_last_spei, aes(x=year, y=predicted)) +
  facet_wrap(~fertilized)+
  geom_point(aes(x=year, y=biomass_g_m2), color="gray60", size=0.5) +
  geom_smooth(aes(y=predicted), color="gray20")+
  theme_bw()+
  theme(panel.grid.major = element_blank(),panel.grid.minor = element_blank())+ 
  labs(x="Year",
       y="Aboveground total cover")


#Remove the effects of year?


m.La.YR<-lme(biomass_g_m2~SPEI_6m+fertilized+year,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Li.YR<-lme(biomass_g_m2~SPEI_6m*fertilized+year,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Qa.YR<-lme(biomass_g_m2~SPEI_6m+fertilized+I(SPEI_6m^2)+year,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Qi.YR<-lme(biomass_g_m2~SPEI_6m*fertilized+I(SPEI_6m^2)*fertilized+year,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Ca.YR<-lme(biomass_g_m2~SPEI_6m+fertilized+I(SPEI_6m^2)+I(SPEI_6m^3)+year,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")
m.Ci.YR<-lme(biomass_g_m2~SPEI_6m*fertilized+I(SPEI_6m^2)*fertilized+I(SPEI_6m^3)*fertilized+year,data=kbs_mcse_e_succ_last_spei,random=~1|uniq_replicate,method="ML")

# model selection
AICc(m.null, m.La.YR,m.Li.YR,m.Qa.YR,m.Qi.YR,m.Ca.YR,m.Ci.YR)
AICc(m.null, m.La.YR,m.Li.YR,m.Qa.YR,m.Qi.YR,m.Ca.YR,m.Ci.YR)[AICc(m.null, m.La.YR,m.Li.YR,m.Qa.YR,m.Qi.YR,m.Ca.YR,m.Ci.YR)[,2]<=
                                              min(AICc(m.null, m.La.YR,m.Li.YR,m.Qa.YR,m.Qi.YR,m.Ca.YR,m.Ci.YR)[,2])+2,]
#Best model is m.null, but m.Ca.YR is within 2
#m.null  6 4320.802
# AR1 - autocorrelation 1, AR1 - autocorrelation 2 to best model from above
#This is only necessary if year includes non-integer numbers
int.year <- kbs_mcse_e_succ_last_spei$expyear*2-1 #convert to integer
kbs_mcse_e_succ_last_spei$expyear <- int.year
#Fit temporal autocorrelation models
m.AR1.YR<-update(m.Ca.YR,correlation=corAR1(form=~expyear))
m.AR2.YR<-update(m.Ca.YR,correlation=corARMA(form=~expyear,p=2))
# model selection
AICc(m.Ca.YR,m.AR1.YR,m.AR2.YR)
# best model m.AR2.YR

rsquared(m.AR2.YR)
#Marginal R2:  the proportion of variance explained by the fixed factor(s) alone
#Conditional R2: he proportion of variance explained by both the fixed and random factors

#Evaluate model assumptions

plot(m.AR2.YR)#a bit funnel shaped
qqPlot(residuals(m.AR2.YR))
hist(residuals(m.AR2.YR))

#Do sketchy frequentist tests on best model
anova(m.AR2.YR,type="marginal")#F test
Anova(m.AR2.YR,type=2)# Chisq test. Mostly similar except for significance of "SPEI_6m"

#Param estimates and post-hoc pairwise comparisons
emtrends(m.AR2.YR,~ fertilized | degree, "year", max.degree = 3)
pairs(emtrends(m.AR2.YR,~ fertilized | degree , "year", max.degree = 3))
#The quadratic slope is the most different

#Visualize CSF results---------------------
# get a plot of estimated values from the model, by each depth
# visreg with ggplot graphics
#visreg(fit=m.AR2.YR,"SPEI_6m",type="conditional",by="fertilized",gg=TRUE,partial=F,rug=F)+ 
# geom_point(aes(x=SPEI_6m,y=biomass_g_m2,col=year),alpha=0.2,data=kbs_mcse_e_succ_last_spei)+
#  theme_bw()+
#  labs(x="SPEI",
#      y="Aboveground total cover")

#Alternative visualization code if the above doesn't work
kbs_mcse_e_succ_last_spei$predicted.YR<-predict(m.AR2.YR, kbs_mcse_e_succ_last_spei)
ggplot(kbs_mcse_e_succ_last_spei, aes(x=SPEI_6m, y=predicted)) +
  facet_wrap(~fertilized)+
  geom_point(aes(x=SPEI_6m, y=biomass_g_m2), color="gray60", size=0.5) +
  geom_smooth(aes(y=predicted), color="gray20")+
  theme_bw()+
  theme(panel.grid.major = element_blank(),panel.grid.minor = element_blank())+ 
  labs(x="SPEI (6 month)",
       y="Aboveground total cover")







