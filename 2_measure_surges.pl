#! /usr/bin/env perl

use strict;
use warnings;

#use POSIX 'ceil';
#use Text::CSV qw(csv);
#use List::Util qw(sum);

use Date::Format;
use DateTime qw( );
use DateTime::Duration;
#use DateTime::Format::Strptime qw( );

#use Spreadsheet::Read qw(ReadData);
#use Spreadsheet::ParseXLSX;	# failed. Crypt::Mode::CBC,Crypt::Mode::ECB
#use DateTime::Format::Excel;
use Time::Piece;
use Time::Local;


use Data::Dumper;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage   .= "Usage: $progname\n";
$usage   .=   "\n";

while (@ARGV) {
  my $arg = shift;
  if ("$arg" eq "-h") {
		die "$usage";
	}
}

my $date_to_use = "surge_start_date";

my %lines_in = ();

my %surge = ();
my %base  = ();

my @colnames = ();
my $linenum  = 0;
my $uid_col = -1;
my $freq_col = -1;

while (my $line = <>) {
	chomp $line;
	next if "$line" =~ /^\s*$/;
	
	my @cols = split "\t", "$line", -1;
	if ($linenum == 0) {
		# First line of the file contains the column names
		# Each row is a hash keyed by the uid
		foreach (my $i=0; $i<scalar(@cols); $i++) {
			push @colnames, lc "$cols[$i]";
			$uid_col = $i if lc "$cols[$i]" eq "surge_id";
			$freq_col = $i if lc "$cols[$i]" eq "sampling_freq";
		}
	} else {
		$lines_in{"$cols[$uid_col]"} = "$line";
		my $target;
		if (lc "$cols[$freq_col]" eq "observed") {
			# If this is an observed surge, store it in the base hash.
			$target = \%base;
		} else {
			# If this is a computed value, store it in the surge hash.
			$target = \%surge;
		}
		$target->{"$cols[$uid_col]"} = {};
		for (my $i=0; $i<scalar(@cols); $i++) {
			if (!defined $colnames[$i]) {
				print "DEBUG:: $cols[$uid_col] col name ($i) does not exist!\n";
				print "$line\n";
				print Dumper(@colnames);
				exit -1;
			}
			if ("$colnames[$i]" eq "surge_start_date" or "$colnames[$i]" eq "surge_end_date") {
				if ("$cols[$i]" =~ /(\d+)\/(\d+)\/(\d+) (\d+):(\d+)$/) {
					my ($m, $d, $y, $h, $min) = ($1, $2, $3, $4, $5);
					$y = "20$y" unless ($y =~ /^20/);
					$cols[$i] = "$m/$d/$y $h:$min";
				} elsif ("$cols[$i]" =~ /(\d+)\/(\d+)\/(\d+)$/) {
					my ($m, $d, $y) = ($1, $2, $3);
					$y = "20$y" unless ($y =~ /^20/);
					$cols[$i] = "$m/$d/$y 23:59";
				} elsif ("$cols[$i]" =~ /^(\d+)-(\d+)-(\d+)$/) {
					my ($y, $m, $d) = split "-", "$cols[$i]";
					$y = "20$y" unless ($y =~ /^20/);
					$cols[$i] = "$m/$d/$y 23:59";
				}
			}
			$target->{"$cols[$uid_col]"}->{"$colnames[$i]"} = "$cols[$i]";

			if ("$colnames[$i]" eq "surge_start_date") {
				$target->{"$cols[$uid_col]"}->{"epoch_t"} = Time::Piece->strptime("$cols[$i]", '%m/%d/%Y %H:%M')->epoch;
			}
		}
	}
	$linenum++;
}
#print Dumper(\%surge);
#die;

# Calculate the distance from every computed surge to each observed surge.
# This adds 15 columns to the table, but is the most flexible for downstream analyses.
# If the surge starts before the observed, the diff is negative.
# If the surge starts after the observed, the diff is positive.
foreach my $surge_uid (keys %surge) {
	my $s_et = $surge{"$surge_uid"}->{"epoch_t"};
	my %diffs = ();
	foreach my $base_uid (keys %base) {
		my $b_et = $base{"$base_uid"}->{"epoch_t"};
		$surge{"$surge_uid"}->{"$base_uid"} = ($s_et - $b_et);
	}
}
#print Dumper(\%surge);
#die;

my @sorted_bids = sort keys %base;
print "surge_id\tsurge_start_date\tsurge_end_date\twindow_size_samples\tsurge_duration_samples";
print "\tsampling_freq\tstart_threshold\texit_threshold\tdelta_threshold_start";
print "\tdelta_threshold_exit\twindow_overlap";
foreach my $bid (@sorted_bids) {
	print "\t$bid";
}
print "\n";

foreach my $sid (keys %lines_in) {
	print "$lines_in{$sid}";
	if (defined $surge{"$sid"}) {
		my %s = %{$surge{"$sid"}};
		foreach my $bid (@sorted_bids) {
			print "\t$s{$bid}";
		}
	} else {
		foreach my $bid (@sorted_bids) {
			print "\tNA";
		}
	}
	print "\n";
}

=cut
# If the surge starts before the observed, the diff is negative.
# If the surge starts after the observed, the diff is positive.
# We use the root squared distance (rsd) for various reasons.
foreach my $surge_uid (keys %surge) {
	my $s_et = $surge{"$surge_uid"}->{"epoch_t"};
	my %raw_diffs = ();
	my %rsd = ();
	foreach my $base_uid (keys %base) {
		my $b_et = $base{"$base_uid"}->{"epoch_t"};
		$rsd{"$base_uid"} = ($s_et - $b_et)*($s_et - $b_et);
		$raw_diffs{"$base_uid"} = $s_et - $b_et;
	}
	my @sorted_rsd = sort {$rsd{"$a"} <=> $rsd{"$b"}} keys %rsd;
	my $closest = shift @sorted_rsd;
	$surge{"$surge_uid"}->{"closest_observed"} = "$closest";
	$surge{"$surge_uid"}->{"rsd_to_closest_observed"} = "$rsd{$closest}";
	$surge{"$surge_uid"}->{"direction_of_diff"} = "+";
	$surge{"$surge_uid"}->{"direction_of_diff"} = "-" if $raw_diffs{"$closest"} < 0;
	$surge{"$surge_uid"}->{"direction_of_diff"} = "0" if $raw_diffs{"$closest"} == 0;
}
#print Dumper(\%surge);
#die;


print "surge_id\tsurge_start_date\tsurge_end_date\twindow_size_samples\tsurge_duration_samples";
print "\tsampling_freq\tstart_threshold\texit_threshold\twindow_overlap\tclosest_observed\trsd_to_closest\tdirection_of_diff\n";

foreach my $sid (keys %lines_in) {
	print "$lines_in{$sid}\t";
	if (defined $surge{"$sid"}) {
		my %s = %{$surge{"$sid"}};
		print "$s{closest_observed}\t$s{rsd_to_closest_observed}\t$s{direction_of_diff}\n";
	} else {
		print "NA\t0\t0\n";
	}
}
=cut

exit 0;



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


