# #! /usr/local/bin/R

library(dplyr)
library(tidyverse)
library(ggplot2)
library(lubridate)

source("addins/themes.R")


# Load surge data.
surge_df <- as.data.frame(read.table("data_out/surges.all.txt", sep="\t", header=TRUE, check.names=FALSE))
surge_df$surge_start_date <- as.Date(mdy_hm(surge_df$surge_start_date))
surge_df$surge_end_date <- as.Date(mdy_hm(surge_df$surge_end_date))

# Assign a surgeset ID to each surge to allow easier extraction of sets.
# This is already part of the unique surge ID for each.
surge_df$surgeset_id <- paste0(surge_df$sampling_freq, ".n", 
															 surge_df$window_size_samples, ".s", 
															 surge_df$start_threshold, ".e", 
															 surge_df$exit_threshold, ".ds", 
															 surge_df$delta_threshold_start, ".de", 
															 surge_df$delta_threshold_exit, ".ov_", 
															 surge_df$window_overlap)

# Isolate the observed surges into their own dataframe.
#
observed_df <- surge_df %>% filter(str_detect(surgeset_id, "obs"))

# Load the scored surgeset data.
#
surgeset_df <- as.data.frame(read.table("data_out/surgesets.scored.txt", sep="\t", header=TRUE, check.names=FALSE))
# Create a surgeset ID for easier df merging.
# These SSIDs should mesh seamlessly with the SSIDs assigned to individual surges (above).
#
surgeset_df$surgeset_id <- paste0(surgeset_df$surge_set, "-", 
																	surgeset_df$window_size_samples, ".n", 
																	surgeset_df$window_size_samples, ".s", 
																	surgeset_df$start_threshold, ".e", 
																	surgeset_df$exit_threshold, ".ds", 
																	surgeset_df$delta_threshold_start, ".de", 
																	surgeset_df$delta_threshold_exit, ".ov_", 
																	surgeset_df$window_overlap)

# Merge the surgeset dataframe with the dataframe containing the individual surges.
# This effectively annotates each individual surge with its surgeset metrics.
# Match cost, time to identify, etc.
#
merged_df <- merge(surge_df, surgeset_df, by="surgeset_id")

SURGE_COUNT_TARGET <- length(observed_df$surge_id)

#######
# Everything below this line works from the above dataframes!
# It can be tweaked to change what is visualized.
# I know this is kludgy; we will parameterize it and expose user arguments at some point.
#######

COLOR_LIMITS <- c("#24693D", "#B3E0A6")
COLOR_LIMITS_2 <- c("#7C4D79", "#EEC9E5")

TARGET_SETS <- c("all", "1d", "2d", "3d", "4d")
MAX_RESPONSE_DAYS <- c(7, 14, 21)
#TARGET_SETS <- c("all")
#MAX_RESPONSE_DAYS <- c(14)
SURGE_COUNT_LIMITS <- c(SURGE_COUNT_TARGET-2, SURGE_COUNT_TARGET+2)

for (RESPONSE_TIME_MAX in MAX_RESPONSE_DAYS) {
	min_df <- merged_df %>% 
	filter(time_to_id_days > RESPONSE_TIME_MAX-7 & time_to_id_days <= RESPONSE_TIME_MAX) %>% 
	filter(surge_count >= SURGE_COUNT_LIMITS[1] & surge_count <= SURGE_COUNT_LIMITS[2])
	if (nrow(min_df) < 1) {
		next
	}
	
	for (TARGET_SET in TARGET_SETS) {
		base_df <- observed_df
		base_df$surge_count <- SURGE_COUNT_TARGET

		# Extract the target data subset.
		xtract_df <- min_df %>% filter(str_detect(surgeset_id, TARGET_SET))
		if (nrow(xtract_df) < 1) {
			next
		}
		xtract_df <- xtract_df %>% group_by(surgeset_id) %>% arrange(as.numeric(surge_count), time_to_id_days)

		# Add category columns for efficient sorting on the ggplot.
		surgeset_id <- as.vector(unique((xtract_df %>% arrange(desc(as.numeric(match_cost_sec))))$surgeset_id))
		category <- as.vector(1:length(surgeset_id))
		category_df <- data.frame(surgeset_id, category)
		catted_df <- merge(xtract_df, category_df, by="surgeset_id", all.x = TRUE)

		base_df$category <- max(category_df$category)+1
		base_df$surgeset_id <- observed_df$surge_id
		base_df$time_to_id_days <- 0
		base_df$match_cost_days_per_surge <- 0

		vis_df <- rbind(catted_df %>% select("surgeset_id", "category", "surge_start_date", "surge_end_date", "time_to_id_days", "match_cost_days_per_surge", "surge_count"), 
										base_df %>% select("surgeset_id", "category", "surge_start_date", "surge_end_date", "time_to_id_days", "match_cost_days_per_surge", "surge_count"))
		
		sum_df <- vis_df %>% 
#			filter(str_detect(surgeset_id, "ob", negate = TRUE)) %>% 
			distinct(surgeset_id, category, time_to_id_days, match_cost_days_per_surge, surge_count) %>% 
			arrange(desc(category))
		
		fnt <- paste0("data_out/", TARGET_SET, "_surgeset.", RESPONSE_TIME_MAX, "d_response.txt")
		write.table(sum_df, file = fnt, sep = "\t", row.names = FALSE)


		plot_start <- as.Date(mdy("11/01/2020"))
		plot_end <- as.Date(mdy("11/20/2024"))
		DATE_BREAKS <- "2 months"
		DATE_LABELS <- "%m/%y"
		DATE_LIMITS <- c(plot_start, plot_end)
		
		grid_top <- max(vis_df$category)

		p1 <- ggplot(vis_df, aes(x = category, y = surge_start_date, fill = category)) +
					geom_rect(aes(ymin = surge_start_date, ymax = surge_end_date, xmin = category-0.2, xmax = category+0.2),
										stat = "identity") +
					scale_fill_gradient(high = COLOR_LIMITS[1], low = COLOR_LIMITS[2]) +
					scale_y_date(breaks = DATE_BREAKS, date_labels = DATE_LABELS, limits=DATE_LIMITS) + 
					scale_x_continuous(minor_breaks = seq(1, grid_top, 1)) + 
					base_theme() + 
					theme(axis.title.x = element_blank(), axis.title.y = element_blank(), 
								axis.text.x = element_text(size = 5), axis.text.y = element_text(size = 5), 
								panel.grid.major.y = element_line(color="#efefef", linewidth=0.8), 
								panel.grid.minor.y = element_line(color="#efefef", linewidth=0.5),
								legend.position = "none", aspect.ratio = 1/4) +
					coord_flip()


		fn <- paste0("data_out/", TARGET_SET, "_surgemap.", RESPONSE_TIME_MAX, "d_response.png")
		ggsave(fn, plot = p1, width = 5695, height = 3350, units = c("px"))
	}
}
