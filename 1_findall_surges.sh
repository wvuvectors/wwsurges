#! /bin/bash
outfile="$1"

#s=3
#e=3

if [[ -z "$outfile" ]];then
	outfile="data_out/surges.computed.txt"
fi

echo "surge_id	surge_start_date	surge_end_date	window_size_samples	surge_duration_samples	sampling_freq	start_threshold	exit_threshold	delta_threshold_start	delta_threshold_exit	window_overlap" > "$outfile"

for ds in $(seq 0 0.025 0.1);do
	for de in $(seq 0 0.025 0.1);do
		for s in $(seq 1 4);do
			for e in $(seq 1 4);do
		
				for n in $(seq 1 6);do
					./1_find_surges.pl -s $s -e $e -n $n -v "copies_per_mL" -d "Mon" -f "1d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.1dpw.win$n.txt"
					tail -n +2 "data_out/surges.1dpw.win$n.txt" >> "$outfile"
					./1_find_surges.pl --overlap -s $s -e $e -n $n -v "copies_per_mL" -d "Mon" -f "1d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.1dpw.win$n.txt"
					tail -n +2 "data_out/surges.1dpw.win$n.txt" >> "$outfile"
					rm "data_out/surges.1dpw.win$n.txt"
				done
				
				for n in $(seq 1 6);do
					./1_find_surges.pl -s $s -e $e -n $n -v "copies_per_mL" -d "Mon,Wed" -f "2d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.2dpw.win$n.txt"
					tail -n +2 "data_out/surges.2dpw.win$n.txt" >> "$outfile"
					./1_find_surges.pl --overlap -s $s -e $e -n $n -v "copies_per_mL" -d "Mon,Wed" -f "2d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.2dpw.win$n.txt"
					tail -n +2 "data_out/surges.2dpw.win$n.txt" >> "$outfile"
					rm "data_out/surges.2dpw.win$n.txt"
				done
				
				for n in $(seq 1 6);do
					./1_find_surges.pl -s $s -e $e -n $n -v "copies_per_mL" -d "Mon,Wed,Sat" -f "3d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.3dpw.win$n.txt"
					tail -n +2 "data_out/surges.3dpw.win$n.txt" >> "$outfile"
					./1_find_surges.pl --overlap -s $s -e $e -n $n -v "copies_per_mL" -d "Mon,Wed,Sat" -f "3d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.3dpw.win$n.txt"
					tail -n +2 "data_out/surges.3dpw.win$n.txt" >> "$outfile"
					rm "data_out/surges.3dpw.win$n.txt"
				done
				
				for n in $(seq 1 6);do
					./1_find_surges.pl -s $s -e $e -n $n -v "copies_per_mL" -d "Mon,Wed,Thur,Sat" -f "4d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.4dpw.win$n.txt"
					tail -n +2 "data_out/surges.4dpw.win$n.txt" >> "$outfile"
					./1_find_surges.pl --overlap -s $s -e $e -n $n -v "copies_per_mL" -d "Mon,Wed,Thur,Sat" -f "4d-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.4dpw.win$n.txt"
					tail -n +2 "data_out/surges.4dpw.win$n.txt" >> "$outfile"
					rm "data_out/surges.4dpw.win$n.txt"
				done
				
				for n in $(seq 1 6);do
					./1_find_surges.pl -s $s -e $e -n $n -v "copies_per_mL" -f "all-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.all.win$n.txt"
					tail -n +2 "data_out/surges.all.win$n.txt" >> "$outfile"
					./1_find_surges.pl --overlap -s $s -e $e -n $n -v "copies_per_mL" -f "all-$n" -ds $ds -ds $de < "data_in/abundance_data.txt" > "data_out/surges.all.win$n.txt"
					tail -n +2 "data_out/surges.all.win$n.txt" >> "$outfile"
					rm "data_out/surges.all.win$n.txt"
				done
			
			done
		done
		
	done
done

