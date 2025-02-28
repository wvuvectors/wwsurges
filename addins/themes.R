base_theme <- function () { 
	theme(axis.text = element_text(size = 12),
				axis.title.x = element_blank(),
				axis.title.y = element_text(size = 12, color="#333333"),
				axis.line.x = element_line(color="#bbbbbb", linewidth=1),
				axis.line.y = element_line(color="#bbbbbb", linewidth=1),
				axis.text.x = element_text(size = 10, color = "#252525"),
				axis.text.y = element_text(size = 12, color = "#252525"),
				axis.ticks.length.x = unit(-0.2, "cm"), 
				axis.ticks.length.y = unit(-0.25, "cm"), 
				strip.text = element_text(size = 12),
# 				panel.grid.major = element_line(color="#efefef", linewidth=1), 
# 				panel.grid.minor.x = element_line(color="#efefef", linewidth=1),
				panel.grid.major = element_blank(),
				panel.grid.minor.x = element_blank(),
				panel.background = element_rect(fill="transparent"), 
				panel.border = element_rect(fill=NA, color="#bbbbbb", linewidth=1), 
				legend.position = "none",
				legend.justification = c("left", "top"),
				#legend.direction = "horizontal",
				legend.box.just = "center",
				#legend.margin = margin(6, 6, 6, 6),
				legend.title = element_blank(),
				legend.background = element_rect(fill="transparent"), 
				legend.text = element_text(size = 12, color = "#333333"),
				plot.background = element_rect(fill="#ffffff"), 
				plot.title = element_text(size = 12, color="#045a8d", hjust=0.5),
)}

wwsurge_colors <- list(
	contrast_pairs_dark = c("#3D844F", "#5D006F", "#011993", "#EC5701"), 
	contrast_pairs_light = c("#96F786", "#B7B1D6", "#CAE9FD", "#FF7E79")
)


wwsurge_palettes <- function(name, n, all_palettes = wwsurge_colors, type = c("discrete", "continuous")) {
  palette <- all_palettes[[name]]
  if (missing(n)) {
    n = length(palette)
  }
  type = match.arg(type)
  out = switch(type,
               continuous = grDevices::colorRampPalette(palette)(n),
               discrete = palette[1:n]
  )
  structure(out, name = name, class = "palette")
}


scale_color_wwsurges_d <- function(name) {
	ggplot2::scale_color_manual(values = wwsurge_palettes(name, type = "discrete"))
}
scale_colour_wwsurges_d = scale_color_wwsurges_d

scale_fill_wwsurges_d <- function(name) {
	ggplot2::scale_fill_manual(values = wwsurge_palettes(name, type = "discrete"))
}


# To use this file, include the following (uncommented) line at the top of your R script:
# source("PATH_TO_FILE/themes.R")

# Then in ggplot, call the function like this:
#
# ggplot(my_data) + geom_point(aes(x=x_col, y=y_col)) + base_theme()
#
