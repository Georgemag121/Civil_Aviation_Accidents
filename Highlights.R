require(tidyverse)
require(lubridate)
require(ggmap)
require(geosphere)

df.civil <- read.csv("data/data_for_vis.csv", stringsAsFactors = F)

p1 <- ggplot(df.civil, aes(x = Hour, col = factor(sabotage), fill = factor(sabotage))) + geom_density(alpha = 0.3) + scale_x_continuous(limits = c(0, 24), expand = c(0, 0)) + ggtitle(label = "Density for Time of day of accidents by sabotage")

p1

# Accidents between the year 1980 and 1985

df1 <- df.civil %>% mutate(geocheck = abs(dep.lon - lon) >= 0.00001 & abs(dep.lat - lat) >= 0.00001 & abs(des.lon - lon) >= 0.00001 & abs(des.lat - lat) >= 0.00001 & abs(des.lon - dep.lon) >= 0.00001 & abs(des.lat - dep.lat) >= 0.00001)

df2 <- df1 %>% filter(geocheck == T, Year >= 1980, Year <= 1985)

worldmap <- borders("world", colour="#f2ffe6", fill="#f2ffe6")
p2 <- ggplot() + worldmap + 
  geom_curve(data = df2, aes(x = dep.lon, y = dep.lat, xend = lon, yend = lat), size = 0.2, col = "#ff9999", curvature = .1) + 
  geom_point(data = df1 %>% filter(Year >= 1980, Year <= 1985), aes(x = lon, y = lat), shape = 13, col = "#ff0000", size = 1) + 
  theme(panel.background = element_rect(fill = "white"), 
        axis.line = element_blank(),
        axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(),
        axis.title.y = element_blank()
  )

p2
