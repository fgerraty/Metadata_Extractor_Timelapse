#Scraps


# Figure out problems: 


# Create Tesseract engines with the desired options
time_engine <- tesseract("eng", options = list(
  tessedit_char_whitelist = "0123456789:APM",
  tessedit_pageseg_mode= '7' # Assume a single text line
))

# Create Tesseract engines with the desired options
date_engine <- tesseract("eng", options = list(
  tessedit_char_whitelist = "0123456789/",
  tessedit_pageseg_mode= '7' # Assume a single text line
))



# Create Tesseract engines with the desired options
time_engine <- tesseract("eng", options = list(
  tessedit_char_whitelist = "0123456789:APM",
  tessedit_pageseg_mode= '7' # Assume a single text line
))





photo  <- magick::image_read("data/extracted_images/sequence2/CCAM12_D3_34.jpg") # import image

photo

date_options <- tesseract_params(
  list(tessedit_pageseg_mode=7))

, # Assume a single text line
list()
tessedit_char_whitelist = "0123456789/APM" # Expected characters in date
)


date_time_crop <- magick::image_crop(image = photo, geometry = "330x40+2335+1480")
date_time_crop



date_time <- tesseract::ocr_data(date_time_crop, engine = date_time_engine)
date_time


date_crop <- magick::image_crop(image = photo, geometry = "160x45+2330+1480")
date_crop

date <- tesseract::ocr_data(date_crop)
date

time_crop <- magick::image_crop(image = photo, geometry = "160x45+2500+1480")
time_crop

time <- tesseract::ocr_data(time_crop, engine = date_engine)
time



date_crop <- magick::image_crop(image = photo, geometry = "160x45+2330+1480")
date <- tesseract::ocr_data(date_crop, engine = date_engine)$word

#Repeat for the time. 
time_crop <- magick::image_crop(image = photo, geometry = "160x45+2500+1480")
time <- tesseract::ocr_data(time_crop, engine = time_engine)$word


# Example string
example_string <- "183 283 383 483 583 683 783 883 983"

# Replace the pattern with the desired format
cleaned_string <- str_replace_all(example_string, "(\\d)83", "\\18")

# Print the result
print(cleaned_string)




# Create a Tesseract engine with options to recognize specific characters and treat the input as a single line of text
date_time_engine <- tesseract("eng", options = list(
  tessedit_char_whitelist = "0123456789/:APM",  # Only allow these characters
  tessedit_pageseg_mode = '7'  # Assume a single text line
))

photo  <- magick::image_read("data/extracted_images/sequence2/CCAM12_D3_11.jpg") # import image

date_time_crop <- magick::image_crop(image = photo, geometry = "350x40+2330+1480")

date_time_crop

date_time <- tesseract::ocr_data(date_time_crop, engine = date_time_engine)
date_time
