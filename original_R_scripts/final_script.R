#### Load libraries####
library(tidyverse)
library(leaflet)
library(lubridate)
library(htmltools)
library(htmlwidgets)
library(sf)
library(geosphere)

setwd("~/Documents/Blood_Glucose_Maps/original_R_scripts/")
# load functions from separate script
source("functions.R")

#### Strava Data ####
# gpx data - downloaded manually from Strava activity as gpx file
gpx_data <- "GPX_Data_files/Öffis_Stage_50.gpx" 
stage_trace <- st_read(gpx_data, layer = "track_points") # read gpx file

# extract lat lon from geometry column
lat_lon_cols <- do.call(rbind, st_geometry(stage_trace)) %>% 
  as_tibble() %>% setNames(c("lon","lat"))

# calculate distances in metres between lat lon points
# this may overestimate the total distance compared to Strava, especially if the gpx was paused and then started from another location
final_df <- stage_trace %>% 
  bind_cols(lat_lon_cols) %>% 
  mutate(distance_m = distHaversine(cbind(lon, lat),
                                    cbind(lag(lon), lag(lat)))) %>% 
  select(-geometry) %>% 
  as_tibble()

# check of final distance in km
sum(final_df$distance_m, na.rm = TRUE) / 1000

#### Blood Glucose ####
# the 5 minutely Dexcom data was interpolated to minutely values in the script interpolate_dexcom_data.R
# First select the blood glucose data during the ride using the Strava data
# make sure time zone settings of downloaded data and imported data match
minutely_bg_data <- read_csv("Blood_Glucose_Data/20200706_Minutely_Blood_Glucose_Data.csv")

# Predicting BG values during the ride
original_BG <- minutely_bg_data %>% # select time period during the cycle
  mutate(Date_Time = with_tz(Date_Time, tz = "Europe/Berlin")) %>% # Time zone of Dexcom data is UTC, converting to CET as in Strava data
  filter(Date_Time >= final_df$time[1] - 60,
         Date_Time <= final_df$time[nrow(final_df)] + 60) 

# fit the BG data using a polynomial fit and use this to predict the BG values at each second during the ride
BG_fit <- lm(Blood_Glucose_mg_dL ~ poly(Date_Time, 27), data = original_BG)
BG_seconds <- original_BG %>% 
  select(Date_Time) %>% 
  complete(Date_Time = seq.POSIXt(min(Date_Time), max(Date_Time), by = "1 sec"))  # expand dataframe to impute the seconds blood glucose datas
BG_seconds$Prediction <- predict(BG_fit, newdata = BG_seconds)

Stage_bg_data_seconds <- BG_seconds %>% rename(Blood_Glucose_mg_dL = Prediction)

#### Combine Spatial and BG Data ####
# join Spatial and BG data into a single df. Calculate cumulative distance at each point
final_stage_data <- final_df %>% 
  left_join(Stage_bg_data_seconds, by = c("time" = "Date_Time"))  %>% 
  mutate(distance_m = replace_na(distance_m, 0),
         cumulative_distance_km = cumsum(distance_m) / 1000)

#### BG Plot ####
# use leaflet to plot BG data spatially
# colour palettes
pal <- colorNumeric(palette = 'OrRd', # used in the plot
                    domain = c(60, 400))
pal_rev <- colorNumeric(palette = 'OrRd', # needed for Legend
                        reverse = TRUE,
                        domain = c(60, 400))

# icons
start_icon <- makeIcon(iconUrl = "bicycle-outline_blue.svg",
                       iconWidth = 50, iconHeight = 95)

# Prepare the text for tooltips:
mytext <- paste(round(final_stage_data$Blood_Glucose_mg_dL, 0)) %>%
  lapply(htmltools::HTML)

plot <- leaflet(data = final_stage_data) %>% 
  setView(lng = 13.47, lat = 52.56, zoom = 11) %>% 
  addProviderTiles(providers$Stamen.Toner) %>% 
  addCircleMarkers(lng = ~lon,
                   lat = ~lat,
                   radius = 1,
                   label = mytext,
                   labelOptions = labelOptions(textsize = "13px",
                                               style = list('font-weight' = 'bold')),
                   color = ~pal(Blood_Glucose_mg_dL)) %>% 
  addLegend("topright", pal = pal_rev, values = ~Blood_Glucose_mg_dL,
            title = "Blood Glucose<br>(mg/dL)",
            labFormat = labelFormat(transform = function(x) sort(x, decreasing = TRUE)),
            opacity = 1) %>% 
  addMarkers(lng = ~lon[1], # start/end icon
             lat = ~lat[1],
             icon = start_icon,
             label = htmlEscape("Ride Start/End"),
             labelOptions = labelOptions(noHide = TRUE,
                                         direction = "top",
                                         textOnly = TRUE,
                                         textsize = "12px",
                                         style = list('color' = '#006BB4',
                                                      'padding' = "13px 28px",
                                                      'font-weight' = 'bold'))) %>% 
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 9.7)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 9.7)],
                      label = HTML("<b>10 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "left",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>% 
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 17.9)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 17.9)],
                      label = HTML("<b>20 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "bottom",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>%
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 28.4)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 28.4)],
                      label = HTML("<b>30 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "bottom",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>% 
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 40.6)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 40.6)],
                      label = HTML("<b>40 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "bottom",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>% 
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 51.3)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 51.3)],
                      label = HTML("<b>50 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "top",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>% 
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 62.6)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 62.6)],
                      label = HTML("<b>60 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "top",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>% 
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 71.6)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 71.6)],
                      label = HTML("<b>70 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "right",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>% 
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 86.9)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 86.9)],
                      label = HTML("<b>85 km</b>"),
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('color' = '#006BB4',
                                                               'background' = '#cccccc'),
                                                  direction = "left",
                                                  textsize = "12px",
                                                  textOnly = TRUE)) %>%  
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 19.8)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 19.8)],
                      label = HTML("<p>&#128137;</p>"), # insulin
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('margin-top' = "-30px"),
                                                  direction = "right",
                                                  textsize = "30px",
                                                  textOnly = TRUE)) %>%  
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 43.5)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 43.5)],
                      label = HTML("<p>&#127851;</p>"), # choc
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('margin-top' = "-30px"),
                                                  direction = "right",
                                                  textsize = "30px",
                                                  textOnly = TRUE)) %>%
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 65.9)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 65.9)],
                      label = HTML("<p>&#128137;</p>"), # insulin
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('margin-top' = "-30px"),
                                                  direction = "right",
                                                  textsize = "30px",
                                                  textOnly = TRUE)) %>%  
  addLabelOnlyMarkers(lng = ~lon[row_closest_to_distance(df = final_stage_data, dist = 90.7)],
                      lat = ~lat[row_closest_to_distance(df = final_stage_data, dist = 90.7)],
                      label = HTML("<p>&#127853;</p>"), # lollipop
                      labelOptions = labelOptions(noHide = TRUE,
                                                  style = list('margin-top' = "-30px"),
                                                  direction = "right",
                                                  textsize = "30px",
                                                  textOnly = TRUE)) 

saveWidget(plot, file = "Öffis_Stage_50_plot.html", 
           selfcontained = FALSE)
