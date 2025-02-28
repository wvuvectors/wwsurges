#! /usr/bin/env perl

use strict;
use warnings;

use POSIX 'ceil';

use Text::CSV qw(csv);

use List::Util qw(sum);

use Date::Format;
use DateTime qw( );
use DateTime::Duration;
use Time::Piece;
use Time::Local;

use Data::Dumper;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage   .= "Usage: $progname\n";
$usage   .=  "Compares N-sample rolling means from the WaTCH data set on STDIN, finds surges, ";
$usage   .=  "and writes the results in tab-delimited format to STDOUT.\n";
$usage   .=  "[-n N] Size of the rolling window, in samples (3).\n";
$usage   .=  "[-v V] Use V as the key to extract the values for comparison (copies_per_mL).\n";
$usage   .=  "[-f F] Use F as the frequency of sampling label (Daily).\n";
$usage   .=  "[-d D] Subset the input data set by days of the week D. Can be comma-sep list. Default is all days.\n";
$usage   .=  "[-s S] Number of consecutive means to identify the surge start (3).\n";
$usage   .=  "[-e E] Number of consecutive means to identify the surge exit (3).\n";
$usage   .=  "[-ds S] Delta threshold pct (0-1) to define a surge start (0).\n";
$usage   .=  "[-de E] Delta threshold pct (0-1) to define a surge exit (0).\n";
$usage   .=  "[--range] Use consecutive ranges, not means, to calculate the delta (false).\n";
$usage   .=  "[--overlap] Successive rolling windows overlap each other (false).\n";
$usage   .=   "\n";

my $N = 3;
my %obthresholds = ("start" => 3, "exit" => 3);
my %delta_thresholds = ("start" => 0, "exit" => 0);

my $OVERLAP = 0;
my $VALUE = "copies_per_mL";
my $FREQ = "Daily";
my $USE_RANGE = 0;

my %days = ();

while (@ARGV) {
  my $arg = shift;
  if ("$arg" eq "-h") {
		die "$usage";
	} elsif ("$arg" eq "-n") {
		$N = shift;
	} elsif ("$arg" eq "-v") {
		$VALUE = shift;
	} elsif ("$arg" eq "-f") {
		$FREQ = shift;
	} elsif ("$arg" eq "-d") {
		my $dstring = shift;
		foreach my $d (split /,\s*/, $dstring, -1) {
			my $y = lc substr("$d", 0, 2);
			$days{"$y"} = 1;
		}
	} elsif ("$arg" eq "-s") {
		$obthresholds{"start"} = shift;
	} elsif ("$arg" eq "-e") {
		$obthresholds{"exit"} = shift;
	} elsif ("$arg" eq "-ds") {
		$delta_thresholds{"start"} = shift;
	} elsif ("$arg" eq "-de") {
		$delta_thresholds{"exit"} = shift;
	} elsif ("$arg" eq "--range") {
		$USE_RANGE = 1;
	} elsif ("$arg" eq "--overlap") {
		$OVERLAP = 1;
	}
}

# my $today = DateTime->today(time_zone => 'local');
# $today->set_time_zone('UTC');
# 

my %keepers = (
		"collection_end_date" => 1, 
		"$VALUE" 							=> 1,
		"day_of_week"    			=> 1
);


# Read abundance data
my %results = ();

my @colnames = ();
my @all_vals = ();

my $linenum  = 0;
my $day_col = -1;

while (my $line = <>) {
	chomp $line;
	next if "$line" =~ /^\s*$/;
	my @cols = split "\t", "$line", -1;
	if ($linenum == 0) {
		# First line of the file contains the column names
		# Each row is a hash keyed by the uid
		foreach (my $i=0; $i<scalar(@cols); $i++) {
			push @colnames, "$cols[$i]";
			$day_col = $i if lc "$cols[$i]" eq "day_of_week";
		}
	} else {
		# Ignore results that are not for the given day(s), if defined.
		if (scalar keys %days > 0 and $day_col > -1) {
			my $y = lc substr("$cols[$day_col]", 0, 2);
			next unless defined $days{"$y"};
		}
		
		# Extract the data for this row.
		my $uid = "entry-$linenum";
		$results{"$uid"} = {};
		for (my $i=0; $i<scalar(@cols); $i++) {
			if (!defined $colnames[$i]) {
				print "DEBUG: index $i does not exist in colnames array!\n";
				print "$line\n";
				print Dumper(@colnames);
				exit -1;
			}
			next unless defined $keepers{"$colnames[$i]"};

			# date format hack area to make sure all times are in 24-hour format.
			# Also calculate a collection week as year.week (eg, 2023.1) in case we need that.
			if ("$colnames[$i]" eq "collection_end_date") {
				my ($m, $d, $y, $h, $min) = ("", "", "", "", "");
				if ("$cols[$i]" =~ /^(\d+)\/(\d+)\/(\d+) (\d+):(\d+) PM$/) {
					($m, $d, $y, $h, $min) = ($1, $2, $3, $4, $5);
					$y = "20$y" unless ($y =~ /^20/);
					$h += 12;
					$cols[$i] = "$m/$d/$y $h:$min";
				} elsif ("$cols[$i]" =~ /^(\d+)\/(\d+)\/(\d+) (\d+):(\d+)$/) {
					my ($date, $time) = split " ", "$cols[$i]";
					($m, $d, $y) = split "/", "$date";
					$y = "20$y" unless ($y =~ /^20/);
				} elsif ("$cols[$i]" =~ /^(\d+)-(\d+)-(\d+)$/) {
					($y, $m, $d) = split "-", "$cols[$i]";
					$y = "20$y" unless ($y =~ /^20/);
					$cols[$i] = "$m/$d/$y 23:59";
				}
				my $epoch = timelocal( 0, 0, 0, $d, $m - 1, $y - 1900 );
				my $week  = strftime( "%U", @{localtime($epoch)} );
				$y = "20$y" unless ($y =~ /^20/);
				$results{"$uid"}->{"collection_week"} = "$y.$week";
				#print "$uid\t$cols[$i]\n";
				#$results{"$uid"}->{"epoch_time"} = Time::Piece->strptime("$cols[$i]", '%m/%d/%Y %H:%M')->epoch;
			
			}
			$results{"$uid"}->{"$colnames[$i]"} = "$cols[$i]";
			push(@all_vals, $cols[$i]) if "$colnames[$i]" eq "$VALUE";
		}
	}
	$linenum++;
}
#print Dumper(\%results);
#die;

# Calculate the median for use as a threshold.
# Mean values that fall below 5% of the data set median will be ignored.
# This ensures that jitter does not artifically add surges.
my $median = calcMedian(\@all_vals);
#print "median is $median\n";
#die;

# Sort the values by date of collection and store the uids in a separate array.
# Samples are oldest (0) to newest.
# 
my @ordered_uids = sort {Time::Piece->strptime($results{$a}->{"collection_end_date"}, '%m/%d/%Y %H:%M')->epoch <=> Time::Piece->strptime($results{$b}->{"collection_end_date"}, '%m/%d/%Y %H:%M')->epoch} keys %results;
#print Dumper(\@ordered_uids);
#die;

# Build numeric array of target copies ordered by date.
# Array is ordered same as @ordered_uids (ie, oldest (0) to newest).
# Don't need any uid info associated with them at this point.
#
my @ordered_copies = ();
foreach my $uid (@ordered_uids) {
	push @ordered_copies, $results{"$uid"}->{"$VALUE"};
}
#print Dumper(\@ordered_copies);
#die;


my @deltas = ();

my $start = 0;
my $prev_mean = -1;
while ($start < scalar(@ordered_copies)) {
	my $end = $start + ($N - 1);
	last if $end >= scalar(@ordered_copies);
	
	my $start_datetime = $results{"$ordered_uids[$start]"}->{"collection_end_date"};
	my $end_datetime   = $results{"$ordered_uids[$end]"}->{"collection_end_date"};
	
	my @window = @ordered_copies[$start..$end];
	@window = @ordered_copies[$start,$end] if $USE_RANGE == 1;

	my $this_mean = calcMean(\@window);
	my $delta = 0;
	$delta = calcDelta($prev_mean, $this_mean) if $prev_mean > $median * 0.05 and $this_mean > $median * 0.05;
	
	push @deltas, {"INTERVAL_START" => "$start_datetime", 
								 "INTERVAL_END" => "$end_datetime", 
								 "INTERVAL_MEAN" => "$this_mean", 
								 "DELTA" => "$delta"};
	$prev_mean = $this_mean;
	if ($OVERLAP == 0) {
		$start = $start + $N;
	} else {
		$start++;
	}
}

my ($start_counter, $exit_counter) = (0, 0);
my ($obstart_indx, $obexit_indx) = (0, 0);
my @surges = ();

for (my $i=1; $i<scalar(@deltas); $i++) {
	#my $prev = $deltas[$i-1];
	my $this = $deltas[$i];
	
	if ($start_counter >= $obthresholds{"start"}) {
		# if we're in an surge already, look for an exit signal
		# only exit if the threshold is met
		#
		if ($this->{"DELTA"} < $delta_thresholds{"exit"}) {
			$obexit_indx = $i-1 if $exit_counter == 0;
			$exit_counter++;
		} else {
			# If this entry is not a decrease, reset the exit counter
			$exit_counter = 0;
		}
		
		if ($exit_counter >= $obthresholds{"exit"}) {
			# Time to exit this surge
			# Record the start, exit, and duration
			#
			my $dur = $N * ($i - $obstart_indx + 1);	# length of period in samples
			push @surges, {"surge_start" 						=>, $deltas[$obstart_indx]->{"INTERVAL_START"}, 
										 "surge_end" 							=>, $deltas[$obexit_indx]->{"INTERVAL_END"}, 
										 "surge_duration_samples" => $dur};
			# Reset the counters so we're ready to look for another surge
			$start_counter = 0;
			$exit_counter = 0;
			$obstart_indx = $i;
		}

		# Do nothing unless the threshold for exiting an surge is met
		# We'll just move on to the next interval and check for exit signal

	} else {
		# If we're not in an surge, see if we should start one
		if ($this->{"DELTA"} > $delta_thresholds{"start"}) {
			# If we see an increase, record this entry index in case we meet the threshold
			$obstart_indx = $i-1 if $start_counter == 0;
			# Then increase the start counter
			$start_counter++;
		} else {
			# If this is not an increase, reset the start counter to 0
			$start_counter = 0;
		}
	}
	
}

print "surge_id\tsurge_start_date\tsurge_end_date\twindow_size_samples\tsurge_duration_samples";
print "\tsampling_freq\tstart_threshold\texit_threshold\tdelta_threshold_start";
print "\tdelta_threshold_exit\twindow_overlap\n";

# Get a printable overlap setting
my $ov = "no";
$ov = "yes" if $OVERLAP == 1;

for (my $i=0; $i<scalar(@surges); $i++) {
	my $sid = "${FREQ}.n${N}.s${obthresholds{start}}.e${obthresholds{exit}}.ds${delta_thresholds{start}}.de${delta_thresholds{exit}}.ov_${ov}-" . ($i+1);
	print "$sid\t$surges[$i]->{surge_start}\t$surges[$i]->{surge_end}";
	print "\t$N\t$surges[$i]->{surge_duration_samples}\t$FREQ\t$obthresholds{start}\t$obthresholds{exit}";
	print "\t$delta_thresholds{start}\t$delta_thresholds{exit}\t$ov\n";
}

exit 0;



sub calcMean {
	my $aref = shift;
	
	return 0 if scalar @{$aref} == 0;
	return $aref->[0] if scalar @{$aref} == 1;
	
	my $sum = 0;
	foreach my $val (@{$aref}) {
		$sum += $val;
	}
	my $mean = $sum / scalar @{$aref};

	return $mean;
}


sub calcDelta {
	my $pmean = shift;
	my $tmean = shift;
	
	my $pctd = 0;
	$pctd = ($tmean - $pmean)/($pmean + 0.1) unless $pmean == -1;
	
	# Snap delta to 0 if it is within the threshold range provided for starting & exiting a surge.
	$pctd = 0 if $pctd > 0 and $pctd <= $delta_thresholds{"start"};
	$pctd = 0 if $pctd < 0 and $pctd >= $delta_thresholds{"exit"};
	
	return $pctd;
}


sub calcMedian {
	my $arr = shift;
	
	my @sorted = sort {$a <=> $b} @$arr;
  my $m = ($sorted[$#sorted/2 + 0.1] + $sorted[$#sorted/2 + 0.6])/2;
	
# 	if (scalar(@sorted) % 2 == 1) {
# 		# array contains odd number of elements.
# 		$m = ;
# 	} else {
# 		# array contains odd number of elements.
# 		$m = ;
# 	}
	
	return $m;
}


sub trim {
	my $val = shift;
	
	my $trimmed = $val;
	$trimmed =~ s/ +$//;
	$trimmed =~ s/^ +//;
	
	return $trimmed;
}


sub isEmpty {
	my $val = shift;
	
	my $is_empty = 0;
	$is_empty = 1 if "$val" eq "NaN" or "$val" eq "-" or "$val" eq "none" or "$val" eq "" or "$val" eq "TBD" or "$val" eq "NA";
	
	return $is_empty;
}

=cut
sub makeDT {
	my $dtstr = shift;
	
	my $dformat1 = DateTime::Format::Strptime->new(
		pattern   => '%Y-%m-%d %H:%M',
		time_zone => 'local',
		on_error  => 'croak',
	);
	my $dformat2 = DateTime::Format::Strptime->new(
		pattern   => '%m/%d/%Y %H:%M',
		time_zone => 'local',
		on_error  => 'croak',
	);
	
	#print "$dtstr\n";
	my $dtobj;
	if ("$dtstr" =~ /-/) {
		$dtobj = $dformat1->parse_datetime("$dtstr");
	} elsif ("$dtstr" =~ /\//) {
		$dtobj = $dformat2->parse_datetime("$dtstr");
	} else {
		$dtobj = "";
	}
	
	return $dtobj;
}
=cut


