# wd manages a file called WD_DATABASE, which is a whitespace seperated style file.
# Check these two: (pg 86), Getopt::Long and Getopt::Std
# Part of this project is using perl 5 so I will try and use a lot.
use File::Touch;
use File::Spec;
use List::Util qw(any);
use strict;
use Cwd;

sub explain_help {
    print qq{
    wd (Working Directory) is designed to help manage where working directories are!
    Here are a list of useful options:
    \t-h ~ Print this help
    \t-l [word] ~ List all currently stored working directories, match against [word] if it is passed.
    \t-a <name> <dir path> [Assist string] ~ Add <name> to the list of working directories.
    \t-r <name> ~ Remove a tracked directory from wd

    For standard use refer to the following:
    \twd <name> ~ Change to the directory registered under <name>. Make sure to wrap this to cd for the actual switch.

    remember to pass the results to cd if you really want to change:
    wd <args> | cd
};
    exit 0;
}
# Get the directory with wd_dir in it!
my $wd_dir = shift @ARGV;
my $len = scalar @ARGV;
# Now @ARGV just has cmd line vars!

# Open the dictionary if it exists
my $wd_database = File::Spec->catfile($wd_dir, "wd_database");
if (! -f $wd_database){
    print "First time creating:\n\t$wd_database\n";
    touch($wd_database) or die "Could not create database!\n";
}
# Currently I rewrite all of the database each time, but it should be fast, so idc.
# In future I should inplace edit

# Define what valid format is!
# name is (?<name>\A[-\w+])
# path is (?<path>[\w\/-]+)
# anno is (?<anno>(?:\s|.)*)
my $name_re = qr/[-\w]+/;
my $path_re = qr/[-\w\/]+/;
my $anno_re = qr/(?:\s|.)*/;
my $format = qr/(?<name>\A$name_re)\s+(?<path>$path_re)(?<anno>$anno_re)/;
my @appends = ();
my @removes = ();

sub read_open_write {
    open TXTDATABASE, "<", $wd_database or die "Could not open database for read: $!\n";
    my @lines = <TXTDATABASE>;
    close(TXTDATABASE);
    open my $database, ">", $wd_database or die "Could not open database for write: $!\n";
    my %result = (
        lines => \@lines,
        file => $database,
        close => sub {close($database)},
        hi => "potato",
        );
    return %result;
}

# These functions update lines
sub list_entries{
    my %database_data = %{$_[0]};
    my $name = $_[1];
    foreach (@{$database_data{lines}}){
        print $_ if /$name/i;
    }
}

sub add_entry{
    my %database_data = %{$_[0]};
    my $name = $_[1] // ' '; # Set and invalid default.
    my $path = $_[2] // ' ';
    unless ($name =~ /$name_re/) {
        print "name is invalid: $name\n";
        return;
    }
    foreach (@{$database_data{lines}}){
        if(/$format/){
            if ($+{name} eq $name){
                print "name is already used: $name\n";
                return;
            }
        }
    }
    unless (-d $path and ($path =~ /$path_re/)){ # Redundant, -d catches
        print "The path is invalid: $path\n";
        return;
    }
    my $anno = '';
    foreach (3..$len-1){
        $anno .= "$ARGV[$_] ";
    }
    unless ($anno =~ /$anno_re/){
        print "The annotation is invalid: $anno\n";
        return;
    }
    # Check the annotation is correct
    print "Creating entry for:\nname: $name\npath: $path\n(optional)anno: $anno\n";
    my $total = "$name $path $anno\n";
    push @appends, $total;
    # print "\nname: $name :", $name =~ $name_re, "\n";
    # print "path: $path :", $path =~ $path_re, "\n";
    # print "anno: $anno :", $anno =~ $anno_re, "\n";
    # print "full: $total : ", $total =~ $format, "\n\n";
}

sub remove_entry{
    my %database_data = %{$_[0]};
    my $name = $_[1] // ' ';
    unless ($name =~ /$name_re/) {
        print "name is invalid: $name\n";
        return;
    }
    foreach (@{$database_data{lines}}){
        if(/$format/){
            if ($+{name} eq $name){
                print "Queuing removal of $name!\n";
                push @removes, $name;
                return;
            }
        }
    }
    print "name: $name could not be found and thus removed!\n"
}

sub print_dest{
    my %database_data = %{$_[0]};
    my $name = $_[1] // ' ';
    unless ($name =~ /$name_re/) {
        print "name is invalid: $name\n";
        return;
    }
    foreach (@{$database_data{lines}}){
        if(/$format/){
            if ($+{name} eq $name){
                print "$+{path}\n";
                return;
            }
        }
    }
    my $cwd = getcwd();
    print "$cwd\n";
}

# This function prints what is passed then closes the file handle.
sub write_updates{
    my %database_data = %{$_[0]}; # de-refed, opposed to shift into $database_data then using -> to access?
    foreach (@{$database_data{lines}}){
        if (/$format/){
            # Remeber to {} wrap a $scalar print and $_ supplies manually!
            print {$database_data{file}} $_ unless any {$+{name} eq $_} @removes;
        }
        else{
            chomp;
            print "Removing due to failure to match format:\n$_\n";
        }
    }
    # Write our appended data.
    foreach (@appends){
        print {$database_data{file}} $_;
    }
    close($database_data{file});
    exit 0;
}


# $#ARGS is the position of last elem?
if ($len >= 1){
    my $arg = $ARGV[0];
    if ($arg eq '-h'){
        explain_help;
    }
    # Core program, writes/reads happen
    my %database_data = read_open_write;
    # Helper to test regexes
    sub test_regex{
        my $re_test = $_[0];
        my $regex_test = eval {/$re_test/};
        if (! defined($regex_test)){
            print "Failure in passed regex: ", $ARGV[1], "\n";
            write_updates \%database_data;
        }
    }
    # pass references around to above!
    if ($arg eq '-l'){
        &test_regex($ARGV[1]);
        &list_entries(\%database_data, $ARGV[1]);
    }
    elsif ($arg eq '-a'){
        # Add working directory, ARGV[1], ARGV[2] should exist and ARGV[3+] is a string to put in.
        &add_entry(\%database_data, $ARGV[1], $ARGV[2]);
    }
    elsif ($arg eq '-r'){
        &remove_entry(\%database_data, $ARGV[1]);
    }
    else{
        # Just want to print based on name: wd <name>, to be passed to cd with a pipe!
        &print_dest(\%database_data, $arg);
    }
    write_updates \%database_data;
}
else{
    explain_help;
}
