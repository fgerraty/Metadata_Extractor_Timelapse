##########################################################################
# Camera Trap Metadata Extractor from Images  ############################
# Author: Frankie Gerraty (frankiegerraty@gmail.com; fgerraty@ucsc.edu) ##
##########################################################################

############################
# Part 1: Load Packages ####
############################

# Load packages
packages<- c("tidyverse", "lubridate", "magick", "tesseract")

pacman::p_load(packages, character.only = TRUE); rm(packages)

####################################################################
# Part 2: Extract data from one photo sequence/folder ##############
####################################################################

# If you have all of your files in one folder/directory, than this section alone will work for you! You shouldn't have to modify the "process_image" function, but you will have to tweak the "image_files" object to reflect your own dataset. 


# First, define a function to process a single image file ----------------------
process_image <- function(file_path) {
  # Read the image file
  photo <- magick::image_read(file_path)
  
  # Create a Tesseract engine with options to recognize specific characters and treat the input as a single line of text
  date_time_engine <- tesseract("eng", options = list(
    tessedit_char_whitelist = "0123456789/:APM",  # Only allow these characters
    tessedit_pageseg_mode = '7'  # Assume a single text line
  ))
  
  # Crop the section of the image that contains the date and time
  date_time_crop <- magick::image_crop(image = photo, geometry = "330x40+2334+1480")
  
  # Use Tesseract OCR to extract text from the cropped image
  date_time <- tesseract::ocr_data(date_time_crop, engine = date_time_engine)$word

  # Return a tibble with the file name and extracted date-time text
  tibble(
    file_name = basename(file_path),  # Get the base name of the file (without the directory path)
    date_time = date_time  # The extracted date-time text
  )
}


# Second, get a list of all image files in the directory you are trying to extract from ----
image_files <- list.files("data/extracted_images/sequence1", full.names = TRUE, pattern = "\\.jpg$")


# Finally, apply the function to all image files and combine the results into a dataframe ----
results <- map_df(image_files, process_image) %>% 

# Clean and standardize the date_time strings
  mutate(date_time = str_replace_all(date_time, "4M", "AM"),
         date_time = str_replace_all(date_time, "(\\d{2}/\\d{2}/\\d{4})(\\d{2}:\\d{2}:\\d{2})([APM]+)", "\\1 \\2 \\3"),
         # Fix patterns like 183, 283, etc., instead of 18, 28))
         date_time = str_replace_all(date_time, "(\\d)83", "\\18"),  
        #Fix error patterns in which 8:37 was incorrectly interpreted as 3:37
        date_time = str_replace_all(date_time, "(\\d{2}:\\d{1})3(:37)", "\\18\\2")) %>% 
  
  # Parse the cleaned date_time strings into proper date-time objects
  mutate(date_time_parsed = parse_date_time(date_time, "mdY HMS p"))

# Print the results
print(results)



#############################################################
# Part 3: Extract data from multiple sequences ##############
#############################################################

#If you are extracting data from multiple image sequences in separate folders/directories, you will need to repeat the methods above several times (once for each folder). 


# Define a function to process all images in a given directory
process_sequence <- function(sequence_dir) {
  # Get a list of all image files in the directory
  image_files <- list.files(sequence_dir, full.names = TRUE, pattern = "\\.jpg$")
  
  # Apply the process_image function to all image files and combine the results into a dataframe
  results <- map_df(image_files, process_image) %>%
    # Clean and standardize the date_time strings
    mutate(date_time = str_replace_all(date_time, "4M", "AM"),
           date_time = str_replace_all(date_time, "(\\d{2}/\\d{2}/\\d{4})(\\d{2}:\\d{2}:\\d{2})([APM]+)", "\\1 \\2 \\3"),
           
    #Fix errors specific to the photo sequences we are processing. In these sequences, there were two common errors: (1) There were several cases when the optical character recognition added a 3 after an 8 where there was no characters present in the second/minute columns. (2) There were several cases where 8s were incorrectly interpreted as 3s (and, because each timelapse photo occurred at XX:X8:37, I noticed the pattern.). We will fix those here     
           
           # Fix error patterns like 183, 283, etc., instead of 18, 28))
           date_time = str_replace_all(date_time, "(\\d)83", "\\18"),   
           #Fix error patterns in which 8:37 was incorrectly interpreted as 3:37
            date_time = str_replace_all(date_time, "(\\d{2}:\\d{1})3(:37)", "\\18\\2")) %>% 
  
    
    # Parse the cleaned date_time strings into proper date-time objects
    mutate(date_time_parsed = parse_date_time(date_time, "mdY HMS p"))
  
  return(results)
}

# List of sequence directories/folders
sequence_dirs <- list.dirs("data/extracted_images", full.names = TRUE, recursive = FALSE)

# Apply the process_sequence function to all sequence directories and combine the results into a single dataframe
all_results <- map_dfr(sequence_dirs, process_sequence) 

# Print the results
print(all_results)


#As you can see, there are a few errors that we will have to manually correct, but most of the data was extracted successfully! 


####################################################
# Part 4: Manual Correction of Errors ##############
####################################################

#The process I outlined above is far from perfect, and I have built a few double-checking steps into my workflow to correct for the errors that arise. First, lets correct the values that failed when parsing to date-time. This typically occurs when tesseract OCR does not interpret the image correctly. 

# Identify rows where parsing failed
failed_rows <- all_results %>% filter(is.na(date_time_parsed))

# Manually corrected date-time values
corrected_date_times <- c(
  "07/06/2023 11:15:06 AM",
  "07/06/2023 11:18:03 AM",
  "10/05/2023 08:18:37 AM"
  # Add more corrected values as needed
)

# Assign corrected values back to the dataframe
all_results <- all_results %>%
  mutate(date_time = replace(date_time, which(is.na(date_time_parsed)), corrected_date_times)) %>% 
  # Re-parse the corrected date-time values
  mutate(date_time_parsed = parse_date_time(date_time, "mdY HMS p"))


#Next, we need to screen for more sneaky errors that arise due to errors in the tesseract OCR character recognition system. Tesseract seems to have trouble mixing up 3s and 8s, as well as 1s and 7s. To flag errors, I first pull data that I have build into the photo file names (ccam_num is the unique carcass ID, day_num identifies the timelapse day of carcass monitoring, and phot_num is the unique photo number) and then double check that the date-time is in the correct order for the photo sequence

out_of_order <- all_results %>% 
  mutate(
    ccam_num = str_extract(file_name, "(?<=CCAM)\\d+"),
    day_num = str_extract(file_name, "(?<=D)\\d+"),
    photo_num = str_extract(file_name, "(?<=_)\\d+(?=\\.jpg)")) %>% 
  mutate(photo_num = as.numeric(photo_num)) %>% # Convert photo_num to numeric
  arrange(ccam_num, day_num, photo_num) %>% 
  group_by(ccam_num, day_num) %>%
  mutate(is_out_of_order = date_time_parsed < lag(date_time_parsed, default = first(date_time_parsed))) %>%
  ungroup()

#As you can see, there are four errors thrown here (value in column is_out_of_order = TRUE) that are much more stealthy than the prior "failure to parse" error. Fixing these errors usually involve checking the original images that throw an error AND adjacent photos. These are the files to check:

files_to_check <- out_of_order %>%
  filter(is_out_of_order) 

#In this case, we flagged four additional files that were incorrect (and they were not all the ones identified in the files_to_check dataframe...the real error associated with the file CCAM6_D1_72.jpg was actually a mis-read in the previous image file CCAM6_D1_71.jpg)

out_of_order_corrections <- tibble(
  file_name = c("CCAM12_D3_10.jpg", "CCAM12_D3_13.jpg", 
                "CCAM12_D3_42.jpg", "CCAM6_D1_71.jpg"),
  date_time = c("10/05/2023 08:08:36 AM", "10/05/2023 08:38:37 AM", 
                "10/05/2023 11:48:37 AM", "07/06/2023 05:21:05 PM"))

# Join the dataframes
all_results <- left_join(all_results, out_of_order_corrections, by = "file_name", suffix = c("", "_corrected")) %>% 
  #Override incorrect date time with corrected one, where applicable
  mutate(date_time = if_else(!is.na(date_time_corrected), date_time_corrected, date_time),
         #re-parse date-time
         date_time_parsed = parse_date_time(date_time, "mdY HMS p")) %>%
  #Remove temporary columns
  select(-date_time_corrected, -date_time) %>% 
  #Change parsed to "date-time"
  rename(date_time = date_time_parsed) %>% 
  #Pull valable metadata from file name
  mutate(
    ccam_num = str_extract(file_name, "(?<=CCAM)\\d+"),
    day_num = str_extract(file_name, "(?<=D)\\d+"),
    photo_num = str_extract(file_name, "(?<=_)\\d+(?=\\.jpg)"))

#Together, these double-checking steps help to minimize errors that are introduced in the optical character recognition process. Let's save the all_results dataframe as a .csv for future use. 

write_csv(all_results, "output/all_results.csv")

