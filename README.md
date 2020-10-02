# Plotting Blood Glucose Data on an html Map

## Aim
Add blood glucose data on top of spatial (latitude and longitudinal) data to show how blood glucose faired during an activity. Used in my blog posts on [pi-cycles.de](https://pi-cycles.de).

## Requirements
1. GPX track from Strava activity, this is downloaded from the Strava activity page.
2. Dexcom blood glucose readings, exported from Dexcom Clarity.

**To Do**

These external files should be input arguments to the final script.

## Strava Data
My first version used the Strava API to get the spatial data but the API request limit has been reduced a lot so I would exceed my request quota before fetching the data for a single activity! So the next solution was to download the gpx file and use that.
The Strava API data included distance as one of the fields but the raw gpx file doesn't. So I used a Haversine function to calculate the distance between each lat/lon value at every second. This does overestimate the distance but it's not that bad for this purpose.

## Blood Glucose Data
The Dexcom readings are at 5 minute intervals while the Strava data is on a second basis. In order to merge these data sets into a single data set, the Dexcom data is transformed to seconds.
Firstly, the five minute readings are interpolated to minutely readings by the `interpolate_dexcom_data.R` script. 
This is done using the Missing Value Imputation by Weighted Moving Average method.
The minutely data is outputted to a new csv file for the final script.

This method works well for expanding the 5 minute to 1 minute values but not to the seconds as there are too many data points to expand to. The interpolation method is too computational expensive and is very slow, plus the results don't make much sense.
So in order to go from minutely to secondly blood glucose values, the main script fits a high-order polynomial to the minutely blood glucose values. 
The polynomial fit is then used to predict the blood glucose values at every second during the activity.

Fitting the polynomial to the five minute Dexcom readings gave some strange fits, so I decided to combine the interpolation to minutely values and then a polynomial fit for the final blood glucose data set to join to the Strava spatial data.

**To Do**

Different blood glucose monitoring devices take readings at different intervals (the Freestyle Libre is minutely). So this step will need to be adapted for the available CGM/FGM options when they differ from 5 minutely readings.

## Combine Spatial and Blood Glucose Data
The lat, lon values and blood glucose values can now be merged into a single data frame since they have the same temporal resolution.
The leaflet library is used to create the map and then this is saved as an html file.

## Plotting
The interactive plot uses the leaflet tool which is written in javascript. I used the R `leaflet` package which enables R scripts to use the javascript functions.
The blood glucose values are labels that show up when the cursor moves over the points.

I added the distance labels based on the activity, so for a longer ride, I would use distance markers at larger intervals than shorter rides otherwise the plot would be too cluttered. So every 20 km or so for longer rides rather than every 10 km for shorter rides.
The emojis for food, coffee, injecting etc were added for extra information so I had to remember where these events happened during the ride so I could add them to the plot later.

**Plotting Notes**

All of these additional labels were added manually to the script for each plot. 
Perhaps these could be a look up file that is another input argument? 

Say a text file with the format:

Input | Distance
------ | -------
10 km | 9.9
Insulin | 20

Then these would be mapped to the distance and emoji icons and placed at the set distance in the leaflet plot. 
