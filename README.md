# Metadata Extractor for Browning Timelapse+ Files

*Gerraty, FD (fgerraty [at] ucsc.edu; frankiegerraty [at] gmail.com)*

------------------------------------------------------------------------

Camera traps are an incredibly useful research tool, and several camera trap models have timelapse features that can be used for a variety of research purposes (for example, when you are taking photos of wildlife beyond the effective detection distance of your camera model). However, several data management and processing issues can arise when camera settings are not optimized for research purposes.

Several Browning cameras have a feature called "Timelapse+" which takes photos at set increments during daytime hours and also takes photos via standard infrared detection during both day and night. However, the daytime photos (both timelapse photos and infrared-triggered photos) are compressed and combined into a .AVI video file. All of the image exif metadata from individual photos are lost in this process, and need to be manually extracted from each image. In addition, because timelapse and infrared-triggered photos are combined into one file, they need to be identified and separated if you plan to analyze the photos separately.

This repository includes solutions to the aforementioned problems I encountered in processing data from Browning's "Timelapse+" feature, which may be of use for various purposes. Hope it will be of help to others!

------------------------------------------------------------------------

# Problem 1: Photo Decompression

Browning's Timelapse+ mode stores videos as a .TLS file, which is actually just an AVI video file. To make these videos viewable on your computer, change the filename suffix from ".TLS" to ".avi". The file should then be viewable by most media players (e.g. VLC media player). Each frame in these videos is a timelapse or infrared-triggered image taken from sunrise-sunset, and each day has its own AVI video file. Infrared-triggered photos taken during nighttime are stored as photos in a separate folder on the SD card.

For most purposes, we would like to extract each image from these videos and have independent photo files (e.g, .png or .jpeg) for each frame. There are several ways to extract the photos from each frame:

1)  Use the tool developed by Saul Greenberg that uses ffmpeg to extract image files, as described here: <https://saul.cpsc.ucalgary.ca/timelapse/pmwiki.php?n=Main.ExtractingTLSFiles>

2)  Extract photos using a media player such as Adobe Premiere Pro (How-to video: <https://www.youtube.com/watch?v=r1nWR8t43gY>) or VLC Media Player (Not recommended because of how the image capture works. How to here: <https://averagelinuxuser.com/video-to-images-with-vlc-media-player/>)

3)  There are likely other methods and I will add them here when I find good ones.

Unfortunately, video files do not store the same metadata as photos do and, as a result, all of the important metadata from the camera trap photos are lost through this compression/extraction process (cue *Problem 2*).

------------------------------------------------------------------------

# Problem 2: Metadata Capture from Images

In many cases, metadata (date, time, etc.) can be extracted from camera trap images via exif metadata files. There are a variety of excellent tools that allow for you to extract exif data from individual photo files such as [`camtrapR`](https://github.com/jniedballa/camtrapR). However, in some cases (including when working with Browning Timelapse+ files), this exif metadata is lost and we need to retrieve metadata from the images themselves. Fortunately, most camera trap images contain key metadata within the image, which we can extract with OCR (optical character recognition) using the [`tessaract`](https://github.com/tesseract-ocr/tesseract) package.

For this guide, we will use data from one of my research projects examining marine mammal carrion scavenging assemblages along the California coast. Here is an example of a single frame extracted from one the the Browning Timelapse+ video files. Our goal is to extract the photo's date and time from the bottom right corner of the black panel at the bottom of the image. The image sequences we will be using (each is one full day of timelapse photos) are each in their own folder in the `data/extracted_images` directory of this repository.

![Note that the date and time of the photograph are in the bottom right corner.](data/extracted_images/sequence1/CCAM6_D1_00.jpg)

There is an R script titled `Metadata_Extraction.R` in the scripts folder that holds the entire script for this section if raw scripts work better for you. I will walk through that R script here:

1.  First, make sure you have all of the packages we will need downloaded:

    ```{r}
    # Load packages
    packages<- c("tidyverse", "lubridate", "magick", "tesseract")

    pacman::p_load(packages, character.only = TRUE); rm(packages)
    ```

2.  Next, lets start by extracting the metadata from just one of the timelapse image sequences (lets use sequence1). If all of the image files you are pulling data from are in one folder, then this section alone should work well for you! I like to keep all of the images from separate camera trap deployments in separate folders, so we will get into how to do that later.

    ```{r}
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


    # Second, get a list of all image files in the directory you are trying to extract from. This is where we are specifying using photos from sequence1 -------

    image_files <- list.files("data/extracted_images/sequence1", full.names = TRUE, pattern = "\\.jpg$")


    # Finally, apply the function to all image files and combine the results into a dataframe ----
    results <- map_df(image_files, process_image) 
    ```

Tesseract doesn't work perfectly for pulling the dates and times, and made some errors fairly often. For example, it often mistook "AM" for "4M". The errors seemed to occur somewhat consistently, so I usually just identified the error patterns and used the str_replace_all function to fix the errors wherever possible.

```{r}
results <- results %>% 

# Clean and standardize the date_time strings
  mutate(date_time = str_replace_all(date_time, "4M", "AM"),
         date_time = str_replace_all(date_time, "(\\d{2}/\\d{2}/\\d{4})(\\d{2}:\\d{2}:\\d{2})([APM]+)", "\\1 \\2 \\3"),
         # Fix error patterns like 183, 283, etc., instead of 18, 28))
         date_time = str_replace_all(date_time, "(\\d)83", "\\18"),
         #Fix error patterns in which 8:37 was incorrectly interpreted as 3:37
        date_time = str_replace_all(date_time, "(\\d{2}:\\d{1})3(:37)", "\\18\\2")) %>% 
  # Parse the cleaned date_time strings into proper date-time objects
  mutate(date_time_parsed = parse_date_time(date_time, "mdY HMS p"))

# Print the results
print(results)
```

After making a few tweaks, only 2 of 82 the images ended up having issues parsing correctly to date-time format. Since I am not working with massive amounts of data on this project I plan to fix these errors manually, but if you have a better solution you should let me know!

3.  Finally, if you are extracting data from multiple image sequences in separate directories, you will need to make a function to run through the above process in all of the desired directories. For us, all the directories of interest are in the folder `data/extracted_images`

```{r}
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
           date_time = str_replace_all(date_time, "(\\d)83", "\\18"),
           #Fix error patterns in which 8:37 was incorrectly interpreted as 3:37
           date_time = str_replace_all(date_time, "(\\d{2}:\\d{1})3(:37)", "\\18\\2")) %>% 
    # Parse the cleaned date_time strings into proper date-time objects
    mutate(date_time_parsed = parse_date_time(date_time, "mdY HMS p"))
  
  return(results)
}

# List of sequence directories/folders we want to extract images from
sequence_dirs <- list.dirs("data/extracted_images", full.names = TRUE, recursive = FALSE)

# Apply the process_sequence function to all sequence directories and combine the results into a single dataframe
all_results <- map_dfr(sequence_dirs, process_sequence)

# Print the results
print(all_results)

```

Our of the 171 images in the two directories, 3 of them failed to parse correctly to date-time format and several were incorrectly interpreted by tesseract OCR. This process is far from perfect, and I have built a few double-checking steps into my workflow to correct for the errors that arise. First, lets correct the values that failed when parsing to date-time. This typically occurs when tesseract OCR does not interpret the image correctly.

```{r}
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
```

Next, we need to screen for more sneaky errors that arise due to errors in the tesseract OCR character recognition system. Tesseract seems to have trouble mixing up 3s and 8s, as well as 1s and 7s. To flag errors, I first pull data that I have build into the photo file names (ccam_num is the unique carcass ID, day_num identifies the timelapse day of carcass monitoring, and phot_num is the unique photo number) and then double check that the date-time is in the correct order for the photo sequence.

```{r}
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
```

In this case, we identified four addition files that were interpreted incorrectly by tesseract OCR. We will also correct these manually.

```{r}
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
```

That is my current workflow for extracting metadata from images! I would love any tips and improvements, and hope it is useful to others. If it is, please do let me know :)

# Problem 3: Identifying and Separating Timelapse- and Infrared-Triggered Photos

A second problem resulting from Browning's Timelapse+ mode is that timelapse photos and infrared-triggered photos are stored in the same file, which end up in the same directory following the processes outlined above. For my purposes, I primarily work with timelapse photos and prefer for them to be stored separately from infrared-triggered photos because that is most efficient for my photo tagging workflow. In this code block and in the script called `Timelapse_Separation.R`, I outline my process for identifying which images were triggered by timelapse vs infrared triggering mechanisms and then copying those files into one folder (*output/timelapse_photos*) if they were a triggered by the timelapse mechanism or another folder (*output/infrared_photos*) if they were triggered by infrared.

First, we need to identify which photos are timelapse photos vs infrared-triggered:

```{r}
#Import Data
all_results <- read_csv("output/all_results.csv")

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


# Join most_common back to all_results
separated_results <- all_results %>%
  mutate(minute_value = minute(date_time),
         last_digit_minute = minute_value %% 10,
         second_value = second(date_time)) %>%
  left_join(most_common, by = "ccam_num", suffix = c("", "_most_common")) %>% 

# Create the TRUE/FALSE timelapse flag column (Timelapse = TRUE, Infrared = FALSE)
  mutate(flag_timelapse = last_digit_minute == last_digit_minute_most_common & #last digit of the minute must match exactly
                    abs(second_value - second_value_most_common) <= 2) %>%  #seconds value can be up to 2 seconds off because the camera sometimes takes the timelapse photo a few seconds off. 
  
  #Keep relevant columns       
  select(file_name, date_time, ccam_num, day_num, flag_timelapse)
```

Next, now that we have a column `flag_timelapse` that identifies whether or not a photo was timelapse-triggered, we can use that column to decide which folder to copy the file into.

```{r}
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

```

And that is my workflow! Again, let me know if you have better solutions to any of these problems.
