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
$rootDir = $ARGV[0];
$rootDir =~ s/\\*$//g;

print "Scanning logs in folder: $rootDir\n";

$filter = $ARGV[1] if  ( defined $ARGV[1] );
$filter = 0 if ( $filter eq "" );

my $rangeStart = 0; #str2time("2019-11-08 00:00:00");
my $rangeEnd = 0; #str2time("2019-12-28 10:30:00");

$rangeStart = str2time( $ARGV[2] ) if ( defined $ARGV[2] );
$rangeEnd = str2time( $ARGV[3] ) if ( defined $ARGV[3] );
$rangeEnd = time() if ( $rangeStart != 0 && $rangeEnd == 0 );

my @files = `dir /s /b $rootDir`;
my $fname = $rootDir;
$fname =~ s/[^a-zA-Z0-9]//g;


open (OUT, ">combined-$fname.csv");
print OUT "sep=;\n";
print OUT "Time;Host;Message;\n";

my %timestamps;



print "Showing only ". $rangeStart ." to ". $rangeEnd ."\n" if ( $rangeStart ne 0 || $rangeEnd ne 0 );

foreach my $line (@files) {	
	chomp( $line );
    
	if ( $line =~ /log(\.\d)?$/ ) {
        my $file = $line;
        $file =~ s/.*?\\$rootDir\\//;
        parseFile( $file ) ;
    }
}

foreach my $timestamp ( sort keys %timestamps ) {
#	print "Timestamp: $timestamp\n";
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
	$host =~ s/\.log.*$//;
    #$host =~ s/\-\d{8}$//;
	#print "$file, $host\n";
    
	print "Parsing $rootDir\\$file\n";
	open (IN, "<$rootDir\\$file");
	
	my ( $timestamp, $description ) = ( "", "", "" );
	
	while ( my $line = <IN> ) {
        chomp($line);
        #print "$line\n";
        
		next if ( $line =~ /^\s*$/ or $line =~ /^\w:/ );
        #print $line;
		if ( $line =~ /^([0-9\-:, .]{8,})\s+(.*)$/ ) {
            #print "Normal event? $line\n";
			if ( $timestamp ne "" ) {
				#print OUT "$timestamp;$host;\"$description\"\n";
				addEvent( $timestamp, $host, $description );
			} 
			$timestamp = $1; $description = $2;

		} elsif ( $line =~ /^([0-9\- :\.]+) (\d+\.\d+.*)\s*$/  ) {
			#print "IIS? $line\n";
			
			$timestamp = $1; $description = $2;
			my $dt = str2time( $timestamp );
			$timestamp = time2str( "%Y-%m-%d %H:%M:%S,000", $dt + 1 * 60 * 60 );
			
			addEvent( $timestamp, $host, $description );			
		} else {
            #print "Adding to decription: $line\n";
			$description .= "\n".$line;
		}
			
	}
	
	addEvent( $timestamp, $host, $description );
	
	close IN;
}

sub addEvent {
	my ( $time, $src, $desc ) = ( shift, shift, shift, shift );
	#print "Adding event from $src at $time - $desc\n";	
	$desc =~ s/"/'/g;
	return if ( ($filter ne 0 && $desc !~ /$filter/) || $desc =~ /^\s*$/ || $time =~ /^\s*$/ );
	
    $time =~ s/,/\./g;
	my $parse_time = $time;
	$parse_time =~ s/
    .\d\d\d$//;
	my $dt = str2time( $parse_time );
    
	if ( ($rangeStart eq 0 && $rangeEnd eq 0 ) || (( $dt >= $rangeStart )&&( $dt <= $rangeEnd )) ) {
		if ( defined $timestamps{"$time"} ) {
            my $matches = 0;
            my $log_message = "$src;\"$desc\"\n";
            foreach my $stored ( @{$timestamps{"$time"}} ) {
                $matches ++ if ( $stored eq $log_message );
            }
			push @{$timestamps{"$time"}}, $log_message if ( $matches == 0 );
		} else {
			$timestamps{"$time"} = [ "$src;\"$desc\"\n" ];
		}
	}
	
}