#! /usr/local/bin/R

library(dplyr)
library(tidyverse)
library(lubridate)

library(RcppHungarian)

# Load calculated surge data.
surge_df <- as.data.frame(read.table("data_out/surges.distance_matrix.txt", sep="\t", header=TRUE, check.names=FALSE))
surge_df$surge_start_date <- as.Date(mdy_hm(surge_df$surge_start_date))
surge_df$surge_end_date <- as.Date(mdy_hm(surge_df$surge_end_date))
surge_df$sampling_freq <- as.factor(surge_df$sampling_freq)

out_df<-data.frame(surge_set = character(),
									 surge_count = numeric(),
									 time_to_id_days = numeric(),
									 window_overlap = character(),
									 window_size_samples = numeric(),
									 start_threshold = numeric(),
									 exit_threshold = numeric(),
									 delta_threshold_start = numeric(),
									 delta_threshold_exit = numeric(),
									 match_cost_sec = numeric())

#n <- 1
#s <- 1
#e <- 1
#set_str <- "all"
#overlap_str <- "yes"


sets <- c("all", "1d", "2d", "3d", "4d")
overlaps <- c("yes", "no")
delta_thresholds <- c(0, 0.025, 0.05, 0.075, 0.1)

for (set_str in sets) {
	freq_mult <- case_when(str_detect(set_str, "all") ~ (7/6),
										str_detect(set_str, "1d") ~ (7/1),
										str_detect(set_str, "2d") ~ (7/2),
										str_detect(set_str, "3d") ~ (7/3),
										str_detect(set_str, "4d") ~ (7/4))
	for (overlap_str in overlaps) {
		for (dst in delta_thresholds) {
			for (dex in delta_thresholds) {
				for (s in 1:4) {
					for (e in 1:4) {
						for (n in 1:6) {
							ov_mult <- case_when(overlap_str == "no" ~ (n * s),
																	 overlap_str == "yes" ~ (s + (n-1)))
							this_df <- surge_df %>% filter(str_detect(sampling_freq, set_str) & window_overlap == overlap_str & window_size_samples == n & start_threshold == s & exit_threshold == e & delta_threshold_start == dst & delta_threshold_exit == dex)
							
							if (dim(this_df)[1] > 0) {
								this_df <- this_df %>% select(starts_with("obs"))
								this_ma <- as.matrix(abs(this_df))
								# Need to balance the matrix for the HA to work properly.
								# Do this by padding it with very large scores (maximum score in the matrix). 
								# These represent edges in the bipartite graph that should rarely if ever be 
								# included in a cost min algorithm.
								mdims <- dim(this_ma)	# rows x cols
								fill_val <- max(this_ma)
								if (mdims[1] > mdims[2]) {
									# more rows than cols, so add some rows
									unbal <- mdims[1] - mdims[2]
									for (r in 1:unbal) {
										this_ma <- cbind(this_ma, rep(fill_val, mdims[1]))
									}
								} else if (mdims[2] > mdims[1]) {
									# more cols than rows, so add some cols
									unbal <- mdims[2] - mdims[1]
									for (r in 1:unbal) {
										this_ma <- rbind(this_ma, rep(fill_val, mdims[2]))
									}
								}
								
								has <- HungarianSolver(this_ma)
								out_df <- out_df %>% add_row(surge_set = set_str,
																						 surge_count = nrow(this_df),
																						 time_to_id_days = (freq_mult * ov_mult), 
																						 window_overlap = overlap_str, 
																						 window_size_samples = as.numeric(n), 
																						 start_threshold = as.numeric(s), 
																						 exit_threshold = as.numeric(e), 
																						 delta_threshold_start = as.numeric(dst),
																						 delta_threshold_exit = as.numeric(dex), 
																						 match_cost_sec = as.numeric(has$cost))
							} else {
								paste0("Empty result for set=", set_str,", n=", n, ", s=", s, ", e=", e, "ds=", dst, "de=", dex)
							}
						} # end n loop
					} # end e loop
				} # end s loop
			} # end dex loop
		}	# end dst loop
	} # end overlap loop
} # end set loop

out_df$match_cost_days <- out_df$match_cost_sec / (60 * 60 * 24)
out_df$match_cost_days_per_surge <- out_df$match_cost_days / nrow(surge_df %>% filter(sampling_freq == "observed"))

fn <- paste0("data_out/surgesets.scored.txt")
write.table(out_df %>% arrange(match_cost_sec), file = fn, sep = "\t", row.names = FALSE, quote = FALSE, append = FALSE)

