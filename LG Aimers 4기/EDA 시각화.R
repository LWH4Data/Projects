library(dplyr)
library(ggplot2)
library(tidyr)
library(stringr)
library(rcompanion)
library(polycor)
library(psych)

# test의 

# 데이터 로드, chr type의 칼럼을 모두 factor로 변환.
train_df <- read.csv('D:\\LG Aimers\\train.csv')
train_df <- as.data.frame(unclass(train_df), stringsAsFactors = TRUE)
summary(train_df)
str(train_df)

summary(train_df$business_area)
summary(train_df$ver_win_rate_x)

train_df$ver_win_rate_x <- as.factor(train_df$ver_win_rate_x)
summary(train_df$ver_win_rate_x)

# target과 feature를 분리
train_df_target <- train_df['is_converted']
train_df_feature <- train_df[, !names(train_df) %in% c('is_converted')]
str(train_df_target)
str(train_df_feature)
head(train_df_target, 3)

# target 변수의 분포 확인 > False와 True의 차이가 크기에 모델 적용 전 upscailing의 필요성이 있다.
ggplot(data = train_df_target, aes(x = is_converted, fill = is_converted)) +
  geom_histogram(stat = 'count')
summary(train_df_target)

# bent_submit 변수는 응답의 경우가 0, 0.25, 0.5, 0.75, 1.00의 5개이기에 
# 연속형 변수가 아닌 범주형 변수로 처리해 주는 것이 좋다 생각하여 변환한다.
train_df_feature$bant_submit <- as.factor(train_df_feature$bant_submit)
summary(train_df_feature$bant_submit)
str(train_df_feature$bant_submit)

# bant_submit 변수를 시각화하여 확인
ggplot(data = train_df_feature, aes(x = bant_submit, fill = bant_submit)) +
  geom_histogram(stat = 'count') +
  scale_fill_discrete(name="응답비율", 
                       breaks=c("0", "0.25", "0.5", "0.75", "1"), 
                      labels=c("무응답", "1개 항목 응답", "2개 항목 응답", "3개 항목 응답", "모두 응답"))
submit_phi <- xtabs( ~ bant_submit + is_converted, data = train_df) 
cramerV(submit_phi)

# customer_country
train_df_feature$customer_country <- as.character(train_df_feature$customer_country)

train_df_feature$customer_country <- tolower(train_df_feature$customer_country)
train_df_feature$customer_country <- as.factor(train_df_feature$customer_country)



summary(train_df_feature$customer_country)
levels(train_df_feature$customer_country)
str(train_df_feature$customer_country)



# business_unit 확인
train_df_feature$business_unit <- as.factor(train_df_feature$business_unit)
summary(train_df_feature$business_unit)
ggplot(data = train_df_feature, aes(x = business_unit, fill = business_unit)) +
  geom_histogram(stat = 'count')
unit_phi <- xtabs( ~ business_unit + is_converted, data = train_df) 
cramerV(submit_phi)


# com_reg_ver_win_rate 확인
train_df_feature$com_reg_ver_win_rate <- as.numeric(train_df_feature$com_reg_ver_win_rate)
summary(train_df_feature$com_reg_ver_win_rate)
ggplot(data = train_df_feature, aes(y = com_reg_ver_win_rate)) +
  geom_boxplot()
train_df_feature$com_reg_ver_win_rate <- as.factor(train_df_feature$com_reg_ver_win_rate)
summary(train_df_feature$com_reg_ver_win_rate)

A <- train_df %>% 
  filter(train_df$com_reg_ver_win_rate == '0.833333333333333')
B <- train_df %>% 
  filter(train_df$com_reg_ver_win_rate == 1)
C <- train_df %>% 
  filter(train_df$com_reg_ver_win_rate == '0.642857142857143')
D <- train_df %>% 
  filter(train_df$com_reg_ver_win_rate == '0.615384615384615')

cor_test <- train_df %>% 
  filter(train_df$com_reg_ver_win_rate != 1)
cor_test <- cor_test %>% 
  filter(cor_test$com_reg_ver_win_rate != '0.833333333333333')
cor_test <- cor_test %>% 
  filter(cor_test$com_reg_ver_win_rate != '0.642857142857143')
cor_test <- cor_test %>% 
  filter(cor_test$com_reg_ver_win_rate != '0.615384615384615')
summary(cor_test$com_reg_ver_win_rate)

com_phi <- xtabs( ~ com_reg_ver_win_rate + is_converted, data = train_df) 
cramerV(com_phi)

test_phi <- xtabs( ~ com_reg_ver_win_rate + is_converted, data = cor_test) 
cramerV(test_phi)



# customer_idx
summary(train_df_feature$customer_idx)
ggplot(data = train_df_feature, aes(y = customer_idx)) +
  geom_boxplot()
train_df_feature$customer_idx <- as.factor(train_df_feature$customer_idx)
summary(train_df_feature$customer_idx)

#customer_type
summary(train_df_feature$customer_type)
ggplot(data = train_df_feature, aes(x = customer_type, fill = customer_type)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

# enterprise
summary(train_df_feature$enterprise)
ggplot(train_df_feature, aes(x = enterprise, fill = enterprise)) +
  geom_histogram(stat = 'count') +
  scale_fill_discrete(name="기업 종류", 
                      breaks=c('Enterprise', 'SMB'), 
                      labels=c('글로벌 기업', '중/소 기업'))
enterprise_phi <- xtabs( ~ enterprise + is_converted, data = train_df) 
phi(enterprise_phi)

# historical_existing_cnt
summary(train_df_feature$historical_existing_cnt)
ggplot(data = train_df_feature, aes(y = historical_existing_cnt)) +
  geom_boxplot() +
  geom_hline(aes(yintercept=4, color = 'red')) +
  geom_text(aes(0.4, 1,label = 'Median', vjust = -1))

# id_strategic_ver
train_df_feature$id_strategic_ver <- as.factor(train_df_feature$id_strategic_ver)
summary(train_df_feature$id_strategic_ver)
train_df_feature$ver_cus <- as.factor(train_df_feature$ver_cus)
summary(train_df_feature$ver_cus)

# it_strategic_ver
train_df_feature$it_strategic_ver <- as.factor(train_df_feature$it_strategic_ver)
summary(train_df_feature$it_strategic_ver)

# idit_strategic_ver 
train_df_feature$idit_strategic_ver <- as.factor(train_df_feature$idit_strategic_ver)
summary(train_df_feature$idit_strategic_ver)

# customer_job
summary(train_df_feature$customer_job)

# lead_desc_length
summary(train_df_feature$lead_desc_length)
ggplot(train_df_feature, aes(y = lead_desc_length)) +
  geom_boxplot()
lead_phi <- xtabs( ~ lead_desc_length + is_converted, data = train_df) 
cramerV(lead_phi)

# inquiry_type
summary(train_df_feature$inquiry_type)
levels(train_df_feature$inquiry_type)

# product_category
summary(train_df_feature$product_category)
levels(train_df_feature$product_category)

# product_subcategory
summary(train_df_feature$product_subcategory)
levels(train_df_feature$product_subcategory)

# product_modelname 
summary(train_df_feature$product_modelname)
levels(train_df_feature$product_modelname)

# customer_counry.1
str(train_df_feature$customer_counry.1)
summary(train_df_feature$customer_country.1)
levels(train_df_feature$customer_country.1)

# customer_position
summary(train_df_feature$customer_position)
levels(train_df_feature$customer_position)
customer_phi <- xtabs( ~ customer_position + is_converted, data = train_df) 
cramerV(lead_phi)

# expected_timeline
summary(train_df_feature$expected_timeline)

# ver_cus + ver_pro
train_df_feature$ver_cus <- as.factor(train_df_feature$ver_cus)
train_df_feature$ver_pro <- as.factor(train_df_feature$ver_pro)
summary(train_df_feature$ver_cus)
summary(train_df_feature$ver_pro)

# ver_win_rate_x
summary(train_df_feature$ver_win_rate_x)
ggplot(train_df_feature, aes(y = ver_win_rate_x)) +
  geom_boxplot()
train_df_feature$ver_win_rate_x <- as.factor(train_df_feature$ver_win_rate_x)
levels(train_df_feature$ver_win_rate_x)
summary(train_df_feature$ver_win_rate_x)

# ver_win_ratio_per_bu
summary(train_df_feature$ver_win_ratio_per_bu)
train_df_feature$ver_win_ratio_per_bu <- as.factor(train_df_feature$ver_win_ratio_per_bu)
summary(train_df_feature$ver_win_ratio_per_bu)

# business_area
summary(train_df_feature$business_area)

# business_subarea
summary(train_df_feature$business_subarea)

# lead_owner
summary(train_df_feature$lead_owner)
ggplot(train_df_feature, aes(y = lead_owner)) +
  geom_boxplot()
summary(as.factor(train_df_feature$lead_owner))
train_df$lead_owner <- as.factor(train_df$lead_owner)
owner_phi <- xtabs( ~ lead_owner + is_converted, data = train_df) 
cramerV(owner_phi)

# response_corporate
train_df$respons_corporate <- as.factor(train_df$repons_corporate)
levels(train_df$response_corporate)
sum(is.na(train_df$response_corporate))

ggplot(train_df, aes(x = response_corporate)) +
  geom_histogram(stat = 'count') +
  theme(axis.text.x=element_text(angle=90, hjust=1))







summary(train_df$business_area)
summary(train_df$customer_type)

data.matrix(train_df)
oppty <- xtabs ( ~ business_area + business_unit, data = train_df)
oppty

head(train_df_feature$business_area, 1500)





# customer_country
summary(train_df_feature$customer_country)
# 너무 많은 세부지역 정보가 있기에 국가명만 갖도록 처리를 해줄 필요가 있다.
# 우선 문자열로 처리하기 위해 범주형(factor)에서 문자형(character)로 변환
as.character(train_df_feature$customer_country)
# '//'을 기준으로 구체적인 지역명과 국가명이 구분되어 있기에 '/'을 기준으로 문자열을 추출
sep_country <- str_split_fixed(train_df_feature$customer_country, "/", 5)
sep_country <- as.data.frame(sep_country)
head(sep_country, 5)

sep_country <- sep_country[, 3]  
head(sep_country, 5)
sep_country$V4 <- as.factor(sep_country$V4)
sep_country$V3 <- as.factor(sep_country$V3)
levels(sep_country$V4)
levels(sep_country$V3)

# 명목 변수 상관계수 구하기
# Cramer's V 다층 명목 변수
# Phi 이진 명목변수
data.matrix(train_df)
test <- xtabs ( ~ business_area + is_converted, data = train_df)
test

cramerV(test)

head(train_df$customer_country, 200)

polyserial(train_df$com_reg_ver_win_rate, train_df$is_converted)

test1 <- xtabs ( ~ business_unit + is_converted, data = train_df)
cramerV(test1)

test2 <- xtabs ( ~ enterprise + is_converted, data = train_df)
cramerV(test2)

train_df$com_reg_ver_win_rate <- replace(train_df$com_reg_ver_win_rate, is.na(train_df$com_reg_ver_win_rate), 0.09)

summary(train_df$com_reg_ver_win_rate)

train_df$ver_win_ratio_per_bu <- as.factor(train_df$ver_win_ratio_per_bu)
levels(train_df$ver_win_ratio_per_bu)
summary(train_df$ver_win_ratio_per_bu)
