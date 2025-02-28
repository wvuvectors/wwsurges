#! /bin/bash

if [ -d "data_out" ];then
	mv "data_out" "data_out_OLD"
fi

mkdir "data_out/"
cp "data_in/surges.observed.txt" "data_out/surges.observed.txt"

# Calculate all possible surges over a range of parameters (all units in samples):
# Surge start delta threshold as percent (ds) 0 to 0.1 by 0.025
# Surge exit delta threshold as percent (de) 0 to 0.1 by 0.025
# Window size for calculating means, in number of samples (n) 1-6
# Start cost, in consecutive positive deltas (s) 1-4
# Exit cost, in consecutive negative deltas (e) 1-4
# Window of mean calculation overlapping or not.
#
./1_findall_surges.sh "data_out/surges.computed.txt"

# Combine computed surges with observed set.
#
cp "data_out/surges.computed.txt" "data_out/surges.all.txt"
tail -n +2 "data_out/surges.observed.txt" >> "data_out/surges.all.txt"

# Measure the distance in seconds from each computed surge to each observed surge.
#
./2_measure_surges.pl < "data_out/surges.all.txt" > "data_out/surges.distance_matrix.txt"

# Scores every set by computing minimum path through the C->O WCBPG.
# Writes data_out/surgesets.scored.txt containing all surges.
Rscript 3_score_surgesets.R


# Slices the models into various sub-sections and writes to both png and tab-delimited text.
# The observed set is always the very top surgeset, to facilitate visual comparison.
# Surgesets are binned by range of days required to identify, and the underlying data set.
# For example, "1d_surgeset.14d_response" is the set of surgesets with a 8-14 day time to identify
# and based on the data set of 1 sample per week (1d).
# 
# All files are written to the data_out/ directory.
#
Rscript 4_explore_surgesets.R



