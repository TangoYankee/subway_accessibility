#libraries ----
library(sf)
library(tmap)
library(leaflet)
library(councildown)
library(htmlwidgets)
library(data.table)
library(dplyr)
library(plyr)
library(tidyr)
library(purrr)
library(leaflet.extras)

#borough geojson
bb=st_read('BoroughBoundaries.geojson') %>%
  st_transform("+proj=longlat +datum=WGS84")
#stations and lines -----
ss=st_read('Subway_Stops_2019/stops_nyc_subway_may2019.shp', layer="stops_nyc_subway_may2019") %>%
  st_transform("+proj=longlat +datum=WGS84")
sublines2 = st_read('Subway_Lines_2019/routes_nyc_subway_may2019.shp',
                    layer = "routes_nyc_subway_may2019") %>%
  st_transform("+proj=longlat +datum=WGS84")
#for filtering subway lines -----
full=st_read('ADA/Stations_ADA_Full.shp', layer="Stations_ADA_Full") %>%
  st_transform("+proj=longlat +datum=WGS84")
partial=st_read('ADA/Stations_ADA_Partial.shp', layer="Stations_ADA_Partial") %>%
  st_transform("+proj=longlat +datum=WGS84")
const=st_read('ADA/Stations_ADA_ConstructionInProgress.shp', layer="Stations_ADA_ConstructionInProgress") %>%
  st_transform("+proj=longlat +datum=WGS84")
noplan=st_read('NoADA/Stations_NoADA_NoPlans.shp', layer="Stations_NoADA_NoPlans") %>%
  st_transform("+proj=longlat +datum=WGS84")
ff=st_read('NoADA/Stations_NoADA_UnderConsideration.shp', layer="Stations_NoADA_UnderConsideration") %>%
  st_transform("+proj=longlat +datum=WGS84")

full_sir=st_read('SIR/SIRail_ADA.shp', layer="SIRail_ADA") %>%
  st_transform("+proj=longlat +datum=WGS84") 
full_sir$ADA_Status=rep("Full ADA Access", nrow(full_sir))
full_sir=full_sir[,c(2,3,11,1,10)]

noplan_sir=st_read('SIR/SIRail_NoADA.shp', layer="SIRail_NoADA") %>%
  st_transform("+proj=longlat +datum=WGS84")
noplan_sir$ADA_Status=rep("No Access - No Plans for Funding", nrow(noplan_sir))
noplan_sir=noplan_sir[,c(2,3,11,1,10)]

ff_sir=st_read('SIR/SIRail_NoADA_UnderConsideration.shp', layer="SIRail_NoADA_UnderConsideration") %>%
  st_transform("+proj=longlat +datum=WGS84")
ff_sir$ADA_Status=rep("No Access - Under Consideration", nrow(ff_sir))
ff_sir=ff_sir[,c(2,3,11,1,10)]

#combining all stops ----
allstops=rbind(full, partial, const, ff, noplan)
allstops=allstops[,c(3,5,7,4,8)]
all_sir=rbind(data.frame(full_sir),data.frame(noplan_sir),data.frame(ff_sir))
names(all_sir)<-names(allstops)
allstops=rbind(data.frame(allstops),data.frame(all_sir))


allstops1=data.table(allstops)

#fixing line column to filter -----
allstops1$line=gsub(" Express", "", allstops$line)
#####
s=list()
for (i in 1:nrow(allstops1)){
  s[i]=strsplit(allstops1$line[i],"-")
}
#####make lines unique
u2=c()
for (i in 1:length(s))
{
  u2[i]=paste(sort(unique(unlist(s[[i]]))),  collapse="-")
}

s1=list()
for (i in 1:length(u2)){
  s1[i]=strsplit(u2[i],"-")
}

#s1[1]

####add unique lines to dataframe
allstops1$s=s1
########################
#creating station/point for each line
allstops1=allstops1 %>% 
  mutate(s=map(s,~tibble(s=.))) %>% 
  unnest(s, .drop = FALSE)
#add subway colors from sublines for filtering by subway lines-----
allstops1$linecolors<-c(rep("",nrow(allstops1)))
allstops1[which(allstops1$s=='A'|allstops1$s=='C'|allstops1$s=='E' ),7]<-"#0039A6"
allstops1[which(allstops1$s=='B'|allstops1$s=='D'|allstops1$s=='F'|allstops1$s=='M'),7]<-"#FF6319"
allstops1[which(allstops1$s=='G'),7]<-"#6CBE45"
allstops1[which(allstops1$s=='J'|allstops1$s=='Z'),7]<-"#996633"
allstops1[which(allstops1$s=='L'),7]<-"#A7A9AC"
allstops1[which(allstops1$s=='N'|allstops1$s=='Q'|allstops1$s=='R'|allstops1$s=='W'),7]<-"#FCCC0A"
allstops1[which(allstops1$s=='S'),7]<-"#808183"
allstops1[which(allstops1$s=='1'|allstops1$s=='2'|allstops1$s=='3'),7]<-"#EE352E"
allstops1[which(allstops1$s=='4'|allstops1$s=='5'|allstops1$s=='6'),7]<-"#00933C"
allstops1[which(allstops1$s=='7'),7]<-"#B933AD"
allstops1[which(allstops1$s=='SIR'),7]<-"#053159"

###changing ada status labels -----
allstops1$ADA_StatusLayer=as.character(allstops1$ADA_Status)
allstops1[allstops1$ADA_StatusLayer=='Partial ADA Acccess southbound only',8]<-"Partial ADA Access"
allstops1[which(allstops1$ADA_StatusLayer=='Partial ADA Access northbound only'),8]<-'Partial ADA Access'
allstops1[which(allstops1$ADA_StatusLayer=='Partial ADA Access soutbound only'),8]<-'Partial ADA Access'
allstops1[which(allstops1$ADA_StatusLayer=='Partial ADA Access Southbound Only'),8]<-'Partial ADA Access'
allstops1[which(allstops1$ADA_StatusLayer=='ADA Access Under Construction'),8]<-'In Construction'
allstops1[which(allstops1$ADA_StatusLayer=='No Access - Under Consideration'),8]<-'No ADA: Under Consideration'
allstops1[which(allstops1$ADA_StatusLayer=='No Access - No Plans for Funding'),8]<-'No ADA: No Funding Plans'

#add subway colors from sublines for filtering by ada status type-----
allstops1$adacolors<-c(rep("",nrow(allstops1)))
allstops1[which(allstops1$ADA_StatusLayer=="Full ADA Access"),9]<-"#228AE6"
allstops1[which(allstops1$ADA_StatusLayer=="Partial ADA Access"),9]<-"#82C91E"
allstops1[which(allstops1$ADA_StatusLayer=="In Construction"),9]<-"#BE4BDB"
allstops1[which(allstops1$ADA_StatusLayer=="No ADA: Under Consideration"),9]<-"#D05D4E"
allstops1[which(allstops1$ADA_StatusLayer=="No ADA: No Funding Plans"),9]<-"#666666"

#adding elevator outages ----
ee=read.csv('elevator/out_lines_new.csv', stringsAsFactors = FALSE)
allstops1=left_join(allstops1,ee,by=c("bbl"="BBL"))


#converting into shapefile ----
allstops1<-st_as_sf(allstops1) %>%
  st_transform("+proj=longlat +datum=WGS84")


st_write(allstops1, "allstops.geojson", driver = "GeoJSON", delete_dsn=TRUE)

#subsetting each lines into its own shapefile for leaflet layer selector ----
sub_sir=allstops1[which(allstops1$s==sort(unique(allstops1$s))[22]),]
sub_w=allstops1[which(allstops1$s==sort(unique(allstops1$s))[23]),]
sub_z=allstops1[which(allstops1$s==sort(unique(allstops1$s))[24]),]
sub1=allstops1[which(allstops1$s==sort(unique(allstops1$s))[1]),]
sub2=allstops1[which(allstops1$s==sort(unique(allstops1$s))[2]),]
sub3=allstops1[which(allstops1$s==sort(unique(allstops1$s))[3]),]
sub4=allstops1[which(allstops1$s==sort(unique(allstops1$s))[4]),]
sub5=allstops1[which(allstops1$s==sort(unique(allstops1$s))[5]),]
sub6=allstops1[which(allstops1$s==sort(unique(allstops1$s))[6]),]
sub7=allstops1[which(allstops1$s==sort(unique(allstops1$s))[7]),]
sub_a=allstops1[which(allstops1$s==sort(unique(allstops1$s))[8]),]
sub_b=allstops1[which(allstops1$s==sort(unique(allstops1$s))[9]),]
sub_c=allstops1[which(allstops1$s==sort(unique(allstops1$s))[10]),]
sub_d=allstops1[which(allstops1$s==sort(unique(allstops1$s))[11]),]
sub_e=allstops1[which(allstops1$s==sort(unique(allstops1$s))[12]),]
sub_f=allstops1[which(allstops1$s==sort(unique(allstops1$s))[13]),]
sub_g=allstops1[which(allstops1$s==sort(unique(allstops1$s))[14]),]
sub_j=allstops1[which(allstops1$s==sort(unique(allstops1$s))[15]),]
sub_l=allstops1[which(allstops1$s==sort(unique(allstops1$s))[16]),]
sub_m=allstops1[which(allstops1$s==sort(unique(allstops1$s))[17]),]
sub_n=allstops1[which(allstops1$s==sort(unique(allstops1$s))[18]),]
sub_q=allstops1[which(allstops1$s==sort(unique(allstops1$s))[19]),]
sub_r=allstops1[which(allstops1$s==sort(unique(allstops1$s))[20]),]
sub_s=allstops1[which(allstops1$s==sort(unique(allstops1$s))[21]),]


#for filtering by accessibility type ---------
#add the sir shapefiles
full=full[,c(3,5,7,4,8)]
names(full_sir)<-names(full)
full=rbind(data.frame(full),data.frame(full_sir))%>% 
  as.data.frame() %>% 
  st_as_sf()

ff=ff[,c(3,5,7,4,8)]
names(ff_sir)<-names(ff)
ff=rbind(data.frame(ff),data.frame(ff_sir)) %>% 
  as.data.frame() %>% 
  st_as_sf()

noplan=noplan[,c(3,5,7,4,8)]
names(noplan_sir)<-names(noplan)
noplan=rbind(data.frame(noplan),data.frame(noplan_sir)) %>% 
  as.data.frame() %>% 
  st_as_sf()


#adding subway line colors for filtering by accessibility type----------
#http://web.mta.info/developers/resources/line_colors.htm
#not needed anymore, baruch gis file has colors 
#https://www.baruch.cuny.edu/confluence/pages/viewpage.action?pageId=28016896


#reorder columns for popup -----
sublines2=sublines2[,c(2,5,3,4,6)]

#council categorical color palette ----
council_pal<- c("#D05D4E","#12B886","#BE4BDB", "#F59F00", "#228AE6", "#A07952", "#82C91E")


#using leaflet -----


#for legend icons in layor selector for overlay groups ------------
un1=unname(paste0("<div style='background-color:","#228AE6",
                  ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                  'Full Accessibility'))
un2=unname(paste0("<div style='background-color:","#82C91E",
                  ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                  'Partial Accessibility'))
un3=unname(paste0("<div style='background-color:","#BE4BDB",
                  ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                  'In Construction'))
un4=unname(paste0("<div style='background-color:","#D05D4E",
                  ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                  'No ADA: Under Consideration'))
un5=unname(paste0("<div style='background-color:","#666666",
                  ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                  'No ADA: No Funding Plans'))


#for legend icons in layor selector for base groups -------------------
sub1_l=unname(paste0("<div style='background-color:","#EE352E",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     '1'))
sub2_l=unname(paste0("<div style='background-color:","#EE352E",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     '2'))
sub3_l=unname(paste0("<div style='background-color:","#EE352E",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     '3'))
sub4_l=unname(paste0("<div style='background-color:","#00933C",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     '4'))
sub5_l=unname(paste0("<div style='background-color:","#00933C",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     '5'))
sub6_l=unname(paste0("<div style='background-color:","#00933C",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     '6'))
sub7_l=unname(paste0("<div style='background-color:","#B933AD",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     '7'))
sub_al=unname(paste0("<div style='background-color:","#0039A6",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'A'))
sub_bl=unname(paste0("<div style='background-color:","#FF6319",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'B'))
sub_cl=unname(paste0("<div style='background-color:","#0039A6",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'C'))
sub_dl=unname(paste0("<div style='background-color:","#FF6319",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'D'))
sub_fl=unname(paste0("<div style='background-color:","#FF6319",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'F'))
sub_gl=unname(paste0("<div style='background-color:","#6CBE45",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'G'))
sub_jl=unname(paste0("<div style='background-color:","#996633",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'J'))
sub_ll=unname(paste0("<div style='background-color:","#A7A9AC",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'L'))
sub_ml=unname(paste0("<div style='background-color:","#FF6319",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'M'))
sub_nl=unname(paste0("<div style='background-color:","#FCCC0A",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'N'))
sub_ql=unname(paste0("<div style='background-color:","#FCCC0A",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'Q'))
sub_rl=unname(paste0("<div style='background-color:","#FCCC0A",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'R'))
sub_sl=unname(paste0("<div style='background-color:","#808183",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'S'))
sub_wl=unname(paste0("<div style='background-color:","#FCCC0A",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'W'))
sub_zl=unname(paste0("<div style='background-color:","#996633",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'Z'))
sub_el=unname(paste0("<div style='background-color:","#0039A6",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'E'))
sub_sirl=unname(paste0("<div style='background-color:","#053159",
                     ";position: relative; right:2px; top: 4px; display: inline-block; width: 1em;height: 1em; margin: 2px;'></div>",
                     'SIR'))



#mapping ------------
map <- leaflet() %>% 
  #addCouncilStyle(add_dists = FALSE) %>% 
  #addProviderTiles(providers$CartoDB.DarkMatterNoLabels) %>% 
  addPolygons(data=bb, stroke = FALSE, fillColor = "#666666") %>% 
  #base groups ----
  addCircleMarkers(data = sub1,color =sub1$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub1$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub1$line, "<br><b>","ADA Status:", "</b>","<br>",sub1$ADA_Status)),
                   group = sub1_l, fillOpacity = 1,weight = 0.5,label = sub1$name,opacity = 0) %>%
  addCircleMarkers(data = sub2,color =sub2$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub2$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub2$line, "<br><b>","ADA Status:", "</b>","<br>",sub2$ADA_Status)),
                   group = sub2_l, fillOpacity = 1,weight = 0.5,label = sub2$name,opacity = 0) %>%
  addCircleMarkers(data = sub3,color =sub3$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub3$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub3$line, "<br><b>","ADA Status:", "</b>","<br>",sub3$ADA_Status)),
                   group = sub3_l, fillOpacity = 1,weight = 0.5,label = sub3$name,opacity = 0) %>%
  addCircleMarkers(data = sub4,color =sub4$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub4$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub4$line, "<br><b>","ADA Status:", "</b>","<br>",sub4$ADA_Status)),
                   group = sub4_l, fillOpacity = 1,weight = 0.5,label = sub4$name,opacity = 0) %>%
  addCircleMarkers(data = sub5,color =sub5$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub5$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub5$line, "<br><b>","ADA Status:", "</b>","<br>",sub5$ADA_Status)),
                   group = sub5_l, fillOpacity = 1,weight = 0.5,label = sub5$name,opacity = 0) %>%
  addCircleMarkers(data = sub6,color =sub6$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub6$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub6$line, "<br><b>","ADA Status:", "</b>","<br>",sub6$ADA_Status)),
                   group = sub6_l, fillOpacity = 1,weight = 0.5,label = sub6$name,opacity = 0) %>%
  addCircleMarkers(data = sub7,color =sub7$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub7$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub7$line, "<br><b>","ADA Status:", "</b>","<br>",sub7$ADA_Status)),
                   group = sub7_l, fillOpacity = 1,weight = 0.5,label = sub7$name,opacity = 0) %>%
  addCircleMarkers(data = sub_a,color =sub_a$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_a$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_a$line, "<br><b>","ADA Status:", "</b>","<br>",sub_a$ADA_Status)),
                   group = sub_al, fillOpacity = 1,weight = 0.5,label = sub_a$name,opacity = 0) %>%
  addCircleMarkers(data = sub_b,color =sub_b$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_b$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_b$line, "<br><b>","ADA Status:", "</b>","<br>",sub_b$ADA_Status)),
                   group = sub_bl, fillOpacity = 1,weight = 0.5,label = sub_b$name,opacity = 0) %>%
  addCircleMarkers(data = sub_c,color =sub_c$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_c$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_c$line, "<br><b>","ADA Status:", "</b>","<br>",sub_c$ADA_Status)),
                   group = sub_cl, fillOpacity = 1,weight = 0.5,label = sub_c$name,opacity = 0) %>%
  addCircleMarkers(data = sub_d,color =sub_d$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_d$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_d$line, "<br><b>","ADA Status:", "</b>","<br>",sub_d$ADA_Status)),
                   group = sub_dl, fillOpacity = 1,weight = 0.5,label = sub_d$name,opacity = 0) %>%
  addCircleMarkers(data = sub_e,color =sub_e$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_e$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_e$line, "<br><b>","ADA Status:", "</b>","<br>",sub_e$ADA_Status)),
                   group = sub_el, fillOpacity = 1,weight = 0.5,label = sub_e$name,opacity = 0) %>%
  addCircleMarkers(data = sub_f,color =sub_f$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_f$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_f$line, "<br><b>","ADA Status:", "</b>","<br>",sub_f$ADA_Status)),
                   group = sub_fl, fillOpacity = 1,weight = 0.5,label = sub_f$name,opacity = 0) %>%
  addCircleMarkers(data = sub_g,color =sub_g$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_g$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_g$line, "<br><b>","ADA Status:", "</b>","<br>",sub_g$ADA_Status)),
                   group = sub_gl, fillOpacity = 1,weight = 0.5,label = sub_g$name,opacity = 0) %>%
  addCircleMarkers(data = sub_j,color =sub_j$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_j$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_j$line, "<br><b>","ADA Status:", "</b>","<br>",sub_j$ADA_Status)),
                   group = sub_jl, fillOpacity = 1,weight = 0.5,label = sub_j$name,opacity = 0) %>%
  addCircleMarkers(data = sub_l,color =sub_l$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_l$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_l$line, "<br><b>","ADA Status:", "</b>","<br>",sub_l$ADA_Status)),
                   group = sub_ll, fillOpacity = 1,weight = 0.5,label = sub_l$name,opacity = 0) %>%
  addCircleMarkers(data = sub_m,color =sub_m$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_m$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_m$line, "<br><b>","ADA Status:", "</b>","<br>",sub_m$ADA_Status)),
                   group = sub_ml, fillOpacity = 1,weight = 0.5,label = sub_m$name,opacity = 0) %>%
  addCircleMarkers(data = sub_n,color =sub_n$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_n$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_n$line, "<br><b>","ADA Status:", "</b>","<br>",sub_n$ADA_Status)),
                   group = sub_nl, fillOpacity = 1,weight = 0.5,label = sub_n$name,opacity = 0) %>%
  addCircleMarkers(data = sub_q,color =sub_q$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_q$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_q$line, "<br><b>","ADA Status:", "</b>","<br>",sub_q$ADA_Status)),
                   group = sub_ql, fillOpacity = 1,weight = 0.5,label = sub_q$name,opacity = 0) %>%
  addCircleMarkers(data = sub_r,color =sub_r$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_r$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_r$line, "<br><b>","ADA Status:", "</b>","<br>",sub_r$ADA_Status)),
                   group = sub_rl, fillOpacity = 1,weight = 0.5,label = sub_r$name,opacity = 0) %>%
  addCircleMarkers(data = sub_w,color =sub_w$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_w$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_w$line, "<br><b>","ADA Status:", "</b>","<br>",sub_w$ADA_Status)),
                   group = sub_wl, fillOpacity = 1,weight = 0.5,label = sub_w$name,opacity = 0) %>%
  addCircleMarkers(data = sub_z,color =sub_z$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_z$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_z$line, "<br><b>","ADA Status:", "</b>","<br>",sub_z$ADA_Status)),
                   group = sub_zl, fillOpacity = 1,weight = 0.5,label = sub_z$name,opacity = 0) %>%
  addCircleMarkers(data = sub_sir,color =sub_sir$colors, radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",sub_sir$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>",
                           "Lines:","</b>", sub_sir$line, "<br><b>","ADA Status:", "</b>","<br>",sub_sir$ADA_Status)),
                   group = sub_sirl, fillOpacity = 1,weight = 0.5,label = sub_sir$name,opacity = 0) %>%
  
  
  #overlay groups ----
  addPolylines(data = sublines2,weight = 3,color = sublines2$color,label = sublines2$group,group = 'Lines') %>%
  addCircleMarkers(data = full,color = '#228AE6', radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",full$name,"</h3>","<hr>", "<b>","<font size=","0.5","'>","Lines:","</b>", 
                           full$line, "<br><b>","ADA Status:", "</b><br>",full$ADA_Status)),
                   group = un1, fillOpacity = 1,weight = 0.5,label = full$name,opacity = 0) %>%
  addCircleMarkers(data = partial,color = '#82C91E', radius = 4,
                 popup = councilPopup(
                   paste("<h3 class=","header-tiny",">",partial$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>","Lines:","</b>", 
                         partial$line, "<br><b>","ADA Status:", "</b><br>",partial$ADA_Status)),
                 group = un2, fillOpacity = 1,label = partial$name,weight = 0.5,opacity = 0) %>%
  addCircleMarkers(data = const,color = '#BE4BDB', radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",const$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>","Lines:","</b>", 
                           const$line, "<br><b>","ADA Status:", "</b><br>",const$ADA_Status)),
                   group = un3,label = const$name,fillOpacity = 1,weight = 0.5, opacity = 0) %>%
addCircleMarkers(data = ff, color = '#D05D4E', radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",ff$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>","Lines:","</b>", 
                           ff$line, "<br><b>","ADA Status:", "</b><br>",ff$ADA_Status)),
                   group = un4,label = ff$name,fillOpacity = 1,weight = 0.5,opacity = 0) %>%
  addCircleMarkers(data = noplan, color = '#666666', radius = 4,
                   popup = councilPopup(
                     paste("<h3 class=","header-tiny",">",noplan$name,"</h3>", "<hr>", "<b>","<font size=","0.5","'>","Lines:","</b>", 
                           noplan$line, "<br><b>","ADA Status:", "</b><br>",noplan$ADA_Status)),
                   group = un5,label = noplan$name,fillOpacity = 1,weight = 0.5,opacity = 0) %>%
  #layers control -----
  addLayersControl(baseGroups = 
                     c(sub1_l,sub2_l,sub3_l,sub4_l,sub5_l,sub6_l,sub7_l,sub_al,sub_cl,sub_el,sub_bl,sub_dl,sub_fl,
                                  sub_ml, sub_gl, sub_ll,sub_nl,sub_ql,sub_rl,sub_wl,sub_al,sub_jl,sub_zl, sub_sirl),
                   position = "bottomright", 
                   options = layersControlOptions(collapsed = FALSE, sortLayers = FALSE)) %>%
  addLayersControl(overlayGroups = c(un1,un2,un3,un4,un5),
                   position = "topright", 
                   options = layersControlOptions(collapsed = FALSE, sortLayers = FALSE)) %>%
  #search control -----
  addResetMapButton() %>%   
  addSearchFeatures(targetGroups =  c(un1,un2,un3,un4,un5,sub1_l,sub2_l,sub3_l,sub4_l,sub5_l,sub6_l,sub7_l,sub_al, 
                                      sub_cl,sub_el,sub_bl,sub_dl,sub_fl,sub_ml, sub_gl, sub_ll,sub_nl,sub_ql,
                                      sub_rl,sub_wl,sub_al,sub_jl,sub_zl, sub_sirl),
                    options = searchFeaturesOptions(zoom=18, openPopup = TRUE, firstTipSubmit = TRUE,
                                                    autoCollapse = TRUE, hideMarkerOnCollapse = TRUE, position = "topleft" )) %>%
  addControl("Search by Station Name",position='topleft') %>% 
  hideGroup(c(un1,un2,un3,un4,un5,sub2_l,sub3_l,sub4_l,sub5_l,sub6_l,sub7_l, sub_cl,sub_el,sub_bl,sub_dl,sub_fl,
              sub_ml, sub_gl, sub_ll,sub_nl,sub_ql,sub_rl,sub_wl,sub_al,sub_jl,sub_zl, sub_sirl)) %>%
  
  #zoom parameters
  setView(-73.88099670410158,40.72540497175607,  zoom = 10.5)


#save a stand-alone, interactive map as an html file -------------
getwd()
htmlwidgets::saveWidget(map, file = 'subaccessmap.html', selfcontained = F)

#charts for webpage ----
t=allstops
class(t$ADA_Status)
t$ADA_Status=as.character(t$ADA_Status)
t[which(t$ADA_Status=='Full ADA Access'),3]<-'Full Accessibility'
t[which(t$ADA_Status=='Partial ADA Acccess southbound only'),3]<-'Partial Accessibility'
t[which(t$ADA_Status=='Partial ADA Access northbound only'),3]<-'Partial Accessibility'
t[which(t$ADA_Status=='Partial ADA Access soutbound only'),3]<-'Partial Accessibility'
t[which(t$ADA_Status=='Partial ADA Access Southbound Only'),3]<-'Partial Accessibility'
t[which(t$ADA_Status=='ADA Access Under Construction'),3]<-'In Construction'
t[which(t$ADA_Status=='No Access - Under Consideration'),3]<-'No ADA - Under Consideration'
t[which(t$ADA_Status=='No Access - No Plans for Funding'),3]<-'No ADA - No Funding Plans'

a=as.data.frame(table(t$ADA_Status))
names(a)<-c("Status", "Station_Platforms")
a$percent=a$Station_Platforms/sum(a$Station_Platforms)*100
write.csv(a,'Station_Platform_ADA_Status.csv', row.names = FALSE)






st_ids=read.csv('Subway_Stops_2019/stopsmatch.csv', stringsAsFactors = FALSE)
st_ids$geometry=paste(st_ids$lon,st_ids$lat,sep = ",")
