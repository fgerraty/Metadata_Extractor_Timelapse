##########################################################################
# Separating Timelapse from Infrared-Triggered Images  ###################
# Author: Frankie Gerraty (frankiegerraty@gmail.com; fgerraty@ucsc.edu) ##
##########################################################################\

############################################
# Part 1: Load Packages and Import Data ####
############################################

# Load packages
packages<- c("tidyverse", "lubridate", "magick", "tesseract")

pacman::p_load(packages, character.only = TRUE); rm(packages)

#Import 

all_results <- read_csv("output/all_results.csv")

#####################################################################
# Part 2: Distinguishing Timelapse vs. Infrared-Triggered Photos ####
#####################################################################

temp <- all_results %>% 
  mutate(minute_value = minute(date_time), 
         last_digit_minute = minute_value %% 10, 
         second_value = second(date_time))

common_combinations <- temp %>%
  group_by(ccam_num) %>% 
  count(last_digit_minute, second_value) %>%
  arrange(desc(n)) 
 
#NOTE: 3:37 is occassional and is a result of a OCR misread :( need to fix)


# Extract the most common combinations (one for each ccam_num)
most_common <- common_combinations %>%
  group_by(ccam_num) %>% 
  slice(1)


