library(tidyverse)
library(lubridate)
library(imputeTS)

setwd("~/Documents/Blood_Glucose_Maps/original_R_scripts/")

#### Blood glucose data ####
bg_data <- read_csv(file = "Blood_Glucose_Data/CLARITY_Export__Jane_Coates_2020-June.csv")

minutely_bg_data <- bg_data %>% 
  filter(!is.na(`Timestamp (YYYY-MM-DDThh:mm:ss)`)) %>% 
  select(Date_Time = `Timestamp (YYYY-MM-DDThh:mm:ss)`,
         Blood_Glucose_mg_dL = `Glucose Value (mg/dL)`) %>% 
  mutate(Date_Time = floor_date(Date_Time, unit = "minutes"), # round readings to minutely value
         Date_Time = force_tz(Date_Time, tzone = "Europe/Berlin")) %>% # force readings to Berlin time zone not UTC
  complete(Date_Time = seq.POSIXt(min(Date_Time), max(Date_Time), by = "1 min")) %>% # expand dataframe to impute the minutely blood glucose data
  mutate(Blood_Glucose_mg_dL = na_ma(x = Blood_Glucose_mg_dL, k = 10, "linear"))

# export interpolated BG data to csv file
write_csv(minutely_bg_data, 
          path = paste0("Blood_Glucose_Data/", 
                        str_remove_all(Sys.Date(), "-"), 
                        "_Minutely_Blood_Glucose_Data.csv"))
