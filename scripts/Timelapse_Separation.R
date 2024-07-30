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

#Create a dataframe of the most common combinations of minute(only second digit) and second values for determining the combination associated with the timelapse photos. This code depends on the fact that these will be the most common minute-second values in the dataset, which may not always be the case but, in most cases, will be. 

common_combinations <- all_results %>% 
  mutate(minute_value = minute(date_time), 
         last_digit_minute = minute_value %% 10, 
         second_value = second(date_time)) %>% 
  group_by(ccam_num) %>% 
  count(last_digit_minute, second_value) %>%
  arrange(desc(n)) 
 
# Extract the most common combinations (one for each ccam_num)
most_common <- common_combinations %>%
  group_by(ccam_num) %>% 
  slice(1)

print(most_common)


# Join most_common back to all_results
separated_results <- all_results %>%
  mutate(minute_value = minute(date_time),
         last_digit_minute = minute_value %% 10,
         second_value = second(date_time)) %>%
  left_join(most_common, by = "ccam_num", suffix = c("", "_most_common")) %>% 


# Create the TRUE/FALSE timelapse flag column (Timelapse = TRUE, Infrared = FALSE)
  mutate(flag_timelapse = last_digit_minute == last_digit_minute_most_common & #last digit of the minute must match exactly
                    abs(second_value - second_value_most_common) <= 2) %>%  #seconds value can be up to 2 seconds off because the camera sometimes takes it a few seconds off. 
         
  select(file_name, date_time, ccam_num, day_num, flag_timelapse)



#################################################################################
# Part 3: Copy Timelapse vs. Infrared-Triggered Photos into Separate Folders ####
#################################################################################

#We will put all the timelapse photos from both sequences into the same folder, as this is what is best for my workflow. This section should be tweaked according to your workflow and project goals. 


# Define a function to map ccam_num to its respective source directory (sequence 1 or 2)
get_source_dir <- function(ccam_num) {
  if (ccam_num == 6) {
    return("data/extracted_images/sequence1/")
  } else if (ccam_num == 12) {
    return("data/extracted_images/sequence2/")
  } else {
    stop("Unknown ccam_num")
  }
}

# Create destination directories
true_dir <- "output/timelapse_photos/"
false_dir <- "output/infrared_photos/"

#Add directories to separated_results df based on ccam_num
separated_results <- separated_results %>%
  mutate(source_dir = map_chr(ccam_num, get_source_dir)) %>% 

# Copy files based on the flag_timelapse value
  rowwise() %>% #Work row-by-row
  mutate(
    source_path = path(source_dir, file_name),
    dest_path = if_else(flag_timelapse, 
                        path(true_dir, file_name), 
                        path(false_dir, file_name))) 

# Convert source_path and dest_path to vectors
source_paths <- separated_results$source_path
dest_paths <- separated_results$dest_path

# Copy files based on the flag_timelapse value
purrr::walk2(source_paths, dest_paths, ~ file_copy(.x, .y, overwrite = TRUE))



# Copy files based on the flag_timelapse value into new folders in the "output" directory: infrared_photos or timelapse_photos

separated_results %>%
  rowwise() %>%
  mutate(
    source_path = path(source_dir, file_name),
    dest_path = if_else(flag_timelapse, 
                        path(true_dir, file_name), 
                        path(false_dir, file_name))) %>%
  ungroup() %>%  # Ensure ungrouping before using pmap
  pmap(~ {
    file_copy(..1, ..2, overwrite = TRUE)
  })
