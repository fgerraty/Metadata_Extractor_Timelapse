# Metadata Extractor for Browning Timelapse+ Files

*Gerraty, FD (fgerraty\@ucsc.edu; frankiegerraty\@gmail.com)*

------------------------------------------------------------------------

Camera traps are an incredibly useful research tool, and several camera trap models have timelapse features that can be used for a variety of research purposes (such as, for example, when you are taking photos of wildlife beyond the effective detection distance of your camera model). However, several data management and processing issues can arise when camera settings are not designed for research purposes.

Several Browning cameras have a feature called "Timelapse+" which takes photos at set increments during daytime hours and also takes photos via standard infrared detection during both day and night. However, the daytime photos (both timelapse photos and infrared-triggered photos) are combined into a .AVI video file. All of the image exif metadata from individual photos are lost in this process, and need to be manually extracted from each image. In addition, because timelapse and infrared-triggered photos are combined into one file, they need to be identified and separated if you plan to analyze the photos separately.

This repository includes solutions to the aforementioned problems I encountered in processing data from Browning's "Timelapse+" feature, which may be of use for various purposes. Hope it will be of help to others!
