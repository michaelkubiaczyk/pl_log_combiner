use Date::Parse;
use Date::Format;


my $rootDir = "Logs";
my $filter = 0;

if ( !defined $ARGV[0] ) {
	print "Run with 2-4 params: combinelogs.pl logfolder logfilter_regex [start date] [end date]\n";
	print "For no filter, use 0 or \"\" (all lines returned)\n";
	print "Dates use the format YYYY-MM-DD HH:MM:SS";
	exit;
}
$rootDir = $ARGV[0] ."\\";
print "Scanning logs in folder: $rootDir\n";

$filter = $ARGV[1] if  ( defined $ARGV[1] );

my $rangeStart = 0; #str2time("2019-11-08 00:00:00");
my $rangeEnd = 0; #str2time("2019-12-28 10:30:00");

$rangeStart = str2time( $ARGV[2] ) if ( defined $ARGV[2] );
$rangeEnd = str2time( $ARGV[3] ) if ( defined $ARGV[3] );


my @files = `dir /b $rootDir\\`;
my $fname = $rootDir;
$fname =~ s/[^a-zA-Z0-9]//g;


open (OUT, ">combined-$fname.csv");
print OUT "Time;Host;Code;Description;\n";

my %timestamps;



print "Showing only ". $rangeStart ." to ". $rangeEnd ."\n" if ( $rangeStart ne 0 || $rangeEnd ne 0 );

foreach my $line (@files) {	
	chomp( $line );
	parseFile( $line );
}

foreach my $timestamp ( sort keys %timestamps ) {
	#print "Timestamp: $timestamp\n";
	next if ( $timestamp =~ /^HASH/ );
	
	my @events = @{$timestamps{$timestamp}};
	foreach my $event ( @events ) {
		print OUT "$timestamp;$event";
	}
}

close OUT;


sub parseFile {
	my $file = shift;
	my $host = $file;
	$host =~ s/\..+$//;
	
	print "Parsing $rootDir\\$file\n";
	open (IN, "<$rootDir\\$file");
	
	my ( $timestamp, $code, $description ) = ( "", "", "" );
	
	while ( my $line = <IN> ) {
		next if ( $line =~ /^\s*$/ );
		chomp($line);
		if ( $line =~ /^([0-9\-:, .]+)\s+(\[\d+\])\s+(.*)$/ ) {
			if ( $timestamp ne "" ) {
				#print OUT "$timestamp;$host;$code;\"$description\"\n";
				addEvent( $timestamp, $host, $code, $description );
			} 
			$timestamp = $1; $code = $2; $description = $3;

		} elsif ( $line =~ /^([0-9\- :]+) (\d+\.\d+.*?) (\d+)(\s+\d+){3}\s*$/  ) {
			#print "IIS? $line\n";
			
			$timestamp = $1; $code = $3; $description = $2;
			my $dt = str2time( $timestamp );
			$timestamp = time2str( "%Y-%m-%d %H:%M:%S,000", $dt + 1 * 60 * 60 );
			
			addEvent( $timestamp, $host, $code, $description );			
		} else {
			$description .= "\n".$line;
		}
			
	}
	
	addEvent( $timestamp, $host, $code, $description );
	
	close IN;
}

sub addEvent {
	my ( $time, $src, $code, $desc ) = ( shift, shift, shift, shift );
	#print "Adding event from $src at $time\n";	
	$desc =~ s/"/'/g;
	return if ( $filter ne 0 && $desc !~ /$filter/ );
	
	my $parse_time = $time;
	$parse_time =~ s/,\d\d\d$//;
	my $dt = str2time( $parse_time );
	
	if ( ($rangeStart eq 0 && $rangeEnd eq 0 ) || (( $dt >= $rangeStart )&&( $dt <= $rangeEnd )) ) {
		if ( defined $timestamps{"$time"} ) {
			push @{$timestamps{"$time"}}, "$src;$code;\"$desc\"\n";
		} else {
			$timestamps{"$time"} = [ "$src;$code;\"$desc\"\n" ];
		}
	}
	
}