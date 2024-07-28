# Metadata Extractor for Browning Timelapse+ Files

*Gerraty, FD (fgerraty\@ucsc.edu; frankiegerraty\@gmail.com)*

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

In many cases, metadata (date, time, etc.) can be extracted from camera trap images via exif metadata files. There are a variety of excellent tools that allow for you to extract exif data from individual photo files such as `camtrapR` (<https://github.com/jniedballa/camtrapR>). However, in some cases (including when working with Browning Timelapse+ files), this exif metadata is lost and we need to retrieve metadata from the images themselves. Fortunately, most camera trap images contain key metadata within the image, which we can extract using optical character recognition using the `tessaract` package (<https://github.com/tesseract-ocr/tesseract>).

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
         # Fix patterns like 183, 283, etc., instead of 18, 28))
         date_time = str_replace_all(date_time, "(\\d)83", "\\18")) %>%   
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
           date_time = str_replace_all(date_time, "(\\d)83", "\\18")) %>%   
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

Our of the 171 images in the two directories, 3 of them failed to parse correctly to date-time format. So far, that is the best I have been able to do, but I am currently on the search for a better solution!
