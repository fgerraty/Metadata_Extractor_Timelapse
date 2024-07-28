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
         date_time = str_replace_all(date_time, "(\\d)83", "\\18")) %>%   
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
           # Fix patterns like 183, 283, etc., instead of 18, 28))
           date_time = str_replace_all(date_time, "(\\d)83", "\\18")) %>%   
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