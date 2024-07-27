##########################################################################
# Camera Trap Metadata Extractor from Images  ############################
# Author: Frankie Gerraty (frankiegerraty@gmail.com; fgerraty@ucsc.edu) ##
##########################################################################
# Script 00: Load packages ###############################################
#-------------------------------------------------------------------------

# Part 1: Load Packages --------------------------------------------------

# Load packages
packages<- c("tidyverse", "lubridate", "magick", "tesseract")

pacman::p_load(packages, character.only = TRUE); rm(packages)


# Part 2: Load Packages --------------------------------------------------


photo  <- magick::image_read("data/extracted_images/sequence1/CCAM6_D1_00.jpg") # import image

date_time_crop <- magick::image_crop(image = IMAGE, geometry = "330x40+2330+1480")

date_time <- tesseract::ocr_data(DATE_TIME_CROP)
date_time

date_crop <- magick::image_crop(image = IMAGE, geometry = "160x45+2330+1480")
date_crop

date <- tesseract::ocr_data(date_crop)
date

time_crop <- magick::image_crop(image = IMAGE, geometry = "160x45+2500+1480")
time_crop

time <- tesseract::ocr_data(time_crop)
time
