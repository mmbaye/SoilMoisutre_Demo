suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(patchwork)
  library(caret)
  library(RColorBrewer)
  library(grid)
})




# section 1 ---------------------------------------------------------------

theme_set(theme_light()+ 
            theme(title=element_text(face = 'bold', size = 12),
                  axis.text.y = element_text(face = 'bold',size=12),
                  axis.text.x = element_text(face = 'bold', size = 12),
                  axis.title.x = element_text(face = 'bold',size = 12),
                  axis.title.y = element_text(face = 'bold',size = 12),
                  legend.position = 'right', legend.title=element_text(face="bold", size=14), 
                  legend.text = element_text(face="bold", size = 12)))



# section 2 ---------------------------------------------------------------


dn<-dir('.','txt');dn
fn<-dir('.','csv'); fn
process_petzen<-function(filepath){
  colvars<-c("UTC", "N1" ,"N2" , "P1",
             "Battery","H7","T7","P4",
             "D1", "NMcounts","fbar","fhum",
             "fsol", "VWC", "BM" ,"periods")
  varnames<-colvars[c(1:3,14)]
  df<- filepath %>%
    read.csv()  %>%
    set_names(colvars) %>% 
    filter(VWC>0) %>% 
    select(c(1:3,14)) %>% 
    mutate(
      UTC=as.Date(UTC),
      Year=year(UTC), Months=month(UTC, label = T))
}


df<-process_petzen(dn)

df %>% 
  filter(Year %in% c(2018,2019,2020)) %>% 
  ggplot(aes(x=UTC)) + 
  geom_line(aes(y=VWC), show.legend = F,size=0.8) +
  facet_wrap(~year(UTC), scales = 'free', nrow =3)+
  scale_x_date(date_breaks = '1 month', date_labels = '%b')+
  labs(y='Volumetric Water Content',x='',title = '') ->p1


p1

#ggsave('timeSeries.pdf')
# sentinel vv data --------------------------------------------------------

process_all<-function(filepath) {
  radar <-filepath[2] %>%  read.csv() %>% mutate(UTC=mdy(Time)) %>% select(c(2,3))
  crns<-process_petzen(dn) %>% group_by(UTC) %>% summarise(VWC=mean(VWC)) %>% as.data.frame
  df<-crns %>% inner_join(radar, by='UTC') %>% filter(VWC<=0.4)
  return(df)
  
}
df.merge<-process_all(fn)

# Merging -----------------------------------------------------------------

# Calculating daily mean average of soil moisture prior to merge it


p3<-df.merge %>% 
  filter(UTC>=ymd(20200101) & UTC<=ymd(20200601)) %>% 
  ggplot(aes(UTC,VV)) +
  geom_point(size=2,shape=21)+
  geom_line(size=0.6)+
  geom_smooth(se = F) +
  labs(title = 'Radar Co-polarized Signal' , x='',y=' Backscatter Signal VV')  


p3

p4<-df.merge %>%
  filter(UTC>=ymd(20200101) & UTC<=ymd(20200601)) %>% 
  ggplot(aes(UTC,VWC)) +
  geom_point(size=2)+
  geom_line()+
  geom_smooth(se = F)+
  labs(title = 'CRNS Soil moisture data' , x='',y=bquote('VWC'~m^3/m^3)) 



p3/p4


# calibration -------------------------------------------------------------
dts<-df.merge %>%  
  filter(UTC>=ymd(20200101) & UTC<=ymd(20200601)) %>% 
  select(c(3,2))
x<-dts$VV
y<-dts$VWC

# training model ----------------------------------------------------------
mod<-lm(y~x)
mod
# validation and prediction -----------------------------------------------

observed.train<-dts$VWC
predicted.train<-predict(mod,dts)
observed.val<-df.merge$VWC
predicted.val<-(mod$coefficients[2]*df.merge$VV  + mod$coefficients[1])

rmse.val<-caret::RMSE(observed.val,predicted.val)
rmse.train<-caret::RMSE(observed.train,predicted.train)




myplot<-function(x,y){
  axisRange.val <- extendrange(c(x,y))
  plot(x,
       y,
       cex.lab=1.2,cex=2,
       las=1,cex.axis=1.2,
       cex.main=1.5,
       font.axis=2, font.main=4,
       font.lab=2,
       ylim = axisRange.val,
       xlim = axisRange.val,
       pch=19)
  abline(0, 1, col = "black", lty = 1,lwd=2)
}
# plotting ----------------------------------------------------------------
graphics.off()
n<-layout(matrix(c(1,1,2,3),2,2, byrow = T))
plot(x,y, pch=19,col='black',
     cex.lab=1.2,cex=2,las=1,cex.axis=1.2,cex.main=1.5,
     font.axis=2, font.main=4, font.lab=2,
     main = 'Model calibration, 2020 Training Data',
     ylab='Volumetric Water Content', 
     xlab="Radar Co-polarized Signal VV")
abline(mod, lwd=3, col='black')
segments(x,fitted(mod),x,y,lwd=2,col='grey',lty=1)
text(-9, 0.16,labels=c('Model Calibration '), cex=1, font=2)
text(-9, 0.15,labels=bquote(R^2==0.81), cex=1.2, font=2)
text(-9, 0.14,labels='RMSE = 0.016', cex=1, font=1)

# plot2 -------------------------------------------------------------------


myplot(observed.train,predicted.train)
text(0.22, 0.14,labels=paste0('RMSE = ', round(rmse.train,3)), cex=1.1, font=2)
text(0.22, 0.13,labels='Training', cex=1.1, font=2,col='darkblue')



myplot(observed.val,predicted.val)
text(0.35, 0.10,labels=paste0('RMSE = ', round(rmse.val,3)), cex=1.1, font=2)
text(0.35, 0.07,labels='Validation', cex=1.1, font=2,col='darkblue')


# plots -------------------------------------------------------------------





