library(dplyr)
library(ggplot2)
library(tidyr)
library(stringr)
library(rcompanion)
library(polycor)
library(psych)
library(gridExtra)

mining <- read.csv('D:\\LG Aimers\\mining.csv')
mining <- as.data.frame(unclass(mining),                     # Convert all columns to factor
                       stringsAsFactors = TRUE)
mining <- select(mining, -c('customer_country', 
                            'customer_country.1', 
                            'customer_type',
                            'customer_job',
                            'customer_position',
                            'inquiry_type',
                            'business_subarea',
                            'product_category',
                            'product_subcategory',
                            'product_modelname',
                            'response_corporate',
                            'enterprise',
                            'X'))
summary(mining)
str(mining)

# True인 데이터만 추출
levels(mining$is_converted)
mining_t <- mining %>% 
  filter(mining$is_converted == 'True')
summary(mining_t$is_converted)

# False인 데이터만 추출
mining_f <- mining %>% 
  filter(mining$is_converted == 'False')
summary(mining_t$is_converted)

# country 부터 확인
# T
country_t <- ggplot(mining_t, aes(x = country)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
country_t
# F
country_f <- ggplot(mining_f, aes(x = country)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
grid.arrange(country_t, country_f, ncol = 1)
str(mining)
country_total <- ggplot(mining, aes(x = country)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
country_total
mining$country_total<-as.factor(mining$country)
summary(mining$country)

# corporate
corporate_t <- ggplot(mining_t, aes(x = corporate_group)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
corporate_t

corporate_f <- ggplot(mining_f, aes(x = corporate_group)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
corporate_f
grid.arrange(corporate_t, corporate_f, ncol = 1)

ggplot(mining, aes(x = corporate_group)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))

# idx
# T
idx_t <- ggplot(mining_t, aes(y = customer_idx)) +
  geom_boxplot() +
  theme(axis.text.x=element_text(angle=90, hjust=1))
idx_t
# F
idx_f <- ggplot(mining_f, aes(y = customer_idx)) +
  geom_boxplot() +
  theme(axis.text.x=element_text(angle=90, hjust=1))
idx_f
grid.arrange(idx_t, idx_f, ncol = 1)
str(mining)

#inquiry_topic
#T
inquiry_t <- ggplot(mining_t, aes(x = inquiry_topic)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
inquiry_t
# F
inquiry_f <- ggplot(mining_f, aes(x = inquiry_topic)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
inquiry_f
grid.arrange(inquiry_t, inquiry_f, ncol = 1)
str(mining)

#business_area 
#T
area_t <- ggplot(mining_t, aes(x = business_area)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
area_t
# F
area_f <- ggplot(mining_f, aes(x = business_area)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
area_f
grid.arrange(area_t, area_f, ncol = 1)
str(mining)


#c_position_group
#T
position_t <- ggplot(mining_t, aes(x = c_position_group)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
position_t
# F
position_f <- ggplot(mining_f, aes(x = c_position_group)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
position_f
grid.arrange(position_t, position_f, ncol = 1)
str(mining)

#expected_timeline
#T
time_t <- ggplot(mining_t, aes(x = expected_timeline)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
time_t
# F
time_f <- ggplot(mining_f, aes(x = expected_timeline)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
time_f
grid.arrange(time_t, time_f, ncol = 1)
str(mining)

#business_unit
#T
unit_t <- ggplot(mining_t, aes(x = business_unit)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
unit_t
# F
unit_f <- ggplot(mining_f, aes(x = business_unit)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
unit_f
grid.arrange(unit_t, unit_f, ncol = 1)
str(mining)

# c_type_group
summary(mining$c_type_group)
# T
type_t <- ggplot(mining_t, aes(x = c_type_group)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
type_t
# F
type_f <- ggplot(mining_f, aes(x = c_type_group)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))
type_f
grid.arrange(type_t, type_f, ncol = 1)
str(mining)

#customer_idx
# T
idx_t <- ggplot(mining_t, aes(y = customer_idx)) +
  geom_boxplot() +
  theme(axis.text.x=element_text(angle=90, hjust=1))
idx_t
summary(mining_t$customer_idx)
# F
idx_f <- ggplot(mining_f, aes(y = customer_idx)) +
  geom_boxplot() +
  theme(axis.text.x=element_text(angle=90, hjust=1))
idx_f
grid.arrange(idx_t, idx_f, ncol = 1)
str(mining)
