# This file makes sure that wd can be setup properly and should be called once to install and setup wd.
# We work out of HOME/.config/.wd/
# Step 1 create HOME/.config/.wd if it DNE
use File::HomeDir; # Install with cpan -i File::HomeDir if DNE.
use File::Spec;
# For creating recursive paths
use File::Path qw(make_path);
use Cwd;
# my $wd_dir = File::Spec->catfile(File::HomeDir->my_home, ".config", ".wd");
# We test its existence:
# if (! -d $wd_dir){
#     print "The directory needs to be created: $wd_dir\n";
#     make_path $wd_dir or die "Failed to create the path: $!\n";
#     print "Successfully created the directory!\n"
# }
# Now we need to put this function as an ln -s <wd_bash> /opt/homebrew/bin/
# If they call this up to this point without mac I skip them! if they pass -l <target> I will link there for them.
# It should create a script file wd which gets stored there, script file refernces cwd for here!
# ~/.local/bin/
my $script_location = File::Spec->catfile(File::HomeDir->my_home, ".local", "bin");
# Test for the existance of this dir
die "Failed to located ~/.local/bin\n" if ! -d $script_location;
# Else we know it exists so we put a script together there:
my $cwd = getcwd();
my $cwd_wd = File::Spec->catfile($cwd, "wd.pl");
die "Failed to find wd.pl, call the script from the installer directory!\n" if ! -f $cwd_wd;
# On fail of cwd_wd, return the cwd so you go nowhere!
my $script_text = "perl $cwd_wd $cwd \"\$\@\" \n"; # ARGS[0] is the directory with the wd.database
my $wdfile = File::Spec->catfile($script_location, "wd");
open my $wd_exe, '>', $wdfile or die "Could not open $wdfile\n";
# Put the data in the file
print $wd_exe $script_text;
close($wd_exe);
# Update the file to be executable + readable (its a script not a binary)!
# rwx,421,ugw, u: rwx~7,
chmod 0755, $wdfile; # 0 in front for octal, rwx, rx, rx
print "Updated ~/.local/bin with wd program: make sure ~/.local/bin is in \$PATH\n"
