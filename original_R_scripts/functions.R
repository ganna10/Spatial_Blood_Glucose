# find row closest to certain km mark
row_closest_to_distance <- function (df, dist) {
  df %>% 
    rowid_to_column() %>% 
    mutate(Distance_diff = abs(cumulative_distance_km - dist)) %>% 
    filter(Distance_diff == min(Distance_diff)) %>% 
    pull(rowid)
}

latlon_to_city_district_state <- function (lat, lon) {
  require(httr)
  
  here_api_key <- Sys.getenv("HERE_API_KEY")

  reverse_geocode_url <- "https://reverse.geocoder.ls.hereapi.com/6.2/reversegeocode.json?"

  url_reqest <- str_c(reverse_geocode_url,
                      "prox=", lat, "%2C", lon, "%2C150&",
                      "mode=retrieveAreas&gen=9&apiKey=",
                      here_api_key)
  r <- GET(url_reqest)

  # stop if GET request not successful
  if (http_status(r)$category != "Success") return (str_c("HTTR Request for", lat, "and", lon, "not successful", sep = " "))

  result <- content(r, as = "parsed")
  city <- result$Response$View[[1]]$Result[[1]]$Location$Address$City
  district <- result$Response$View[[1]]$Result[[1]]$Location$Address$District
  if (is.null(district)) district <- city
  state <- result$Response$View[[1]]$Result[[1]]$Location$Address$State

  return(tibble(District = district, City = city, State = state))
}