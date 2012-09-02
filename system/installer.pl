#!/usr/bin/perl

use File::Slurp;
use File::Open qw(fopen fopen_nothrow fsysopen fsysopen_nothrow);
use Data::Dumper;
use YAML::XS;
use Crypt::PasswdMD5;

my $config;

my $configfile = read_file('system/config.yml') if (-e 'system/config.yml');
$config = Load $configfile if ($configfile);


if ($config) {
    ##file already exists and has some info, verify installer override:
    print "There's already a configuration file in the system.\n";
    print "Are you sure you want to proceed recreating configurations? Y|N\n";
    my $doover = <>;
    if (lc $doover ne 'y') {
        print "Resuming bot.\n";
        exit 0;
    } 
}

## recreate config:
print '...................................................'."\n";
print '.....#####...........######........................'."\n";
print '....#.....#..........#.....#.......................'."\n";
print '...#.......#...#...#.#.....#...###....#............'."\n";
print '...#.......#...#...#.######...#...#..####..........'."\n";
print '...#.....#.#...#...#.#.....#..#...#...#............'."\n";
print '....#.....###..#...#.#.....#..#...#...#..#.........'."\n";
print '.....#####..##..###..######....###.....##..........'."\n";
print '...................................................'."\n";
print '     By Moriel Schottlender (mooeypoo)                    '."\n";
print '              August 2012                     '."\n";
print '...................................................'."\n\n";
print "This installer will help you configure your QuBot.\n";
print "Please make sure the 'system/config.yml' folder is writeable.\n";
print "....................................................\n\n\n";

#### IRC Settings:
print "-------------\n";
print "IRC Settings:\n";
print "-------------\n";

my $conf_server = getinput("IRC Server",6);
my $conf_port = getinput("IRC Server Port",5,"6667");
my $conf_nickname = getinput("Your Bot's Nickname",1,"QuBot");
my $conf_username = getinput("Your Bot's Username",1,"QuBot");
my $conf_ircname = getinput("Your Bot's 'full name'",1,"QuBot 2012");
##chans
print "Autojoin Channels:\n";
print "(One per line, including # prefix. To end the list, type 'quit')\n";

my $chans;
    print ">> ";
    my $chinput = <STDIN>;
    chomp $chinput;
    while (lc $chinput ne 'quit') {
        #print $chinput;
        if ($chinput=~ /^#/) {
            $config->{settings}->{channels}->{$chinput} = '';
            print "Channel $chinput added.\n";
            print ">> ";
        } else {
            print "Channel names must contain # prefix (example: #chatroom)\n";
        }
        $chinput = <STDIN>;
        chomp $chinput;
    }

### ADMINISTRATION ###

my $cmd_prefix = getinput("Bot Commands Prefix",1,"!");


my $userfile = read_file('system/users.yml') if (-e 'system/users.yml');
$users = Load $configfile if ($userfile);
## admin pass:
ADMINPASS:
    print "Choose an administrator password:\n";
    my $admin_pass = <STDIN>;
    chomp $admin_pass;
    if (length($admin_pass) < 5) {
        print "Admin pass must be 5 or more characters long.";
        goto ADMINPASS;
    }
    print "Verify your password:\n";
    my $admin_verify = <STDIN>;
    chomp $admin_verify;
    if ($admin_pass ne $admin_verify) {
        print "Passwords do not match.";
        goto ADMINPASS;
    }

    ## crypt:
    $users->{admin}->{username} = 'admin';
    $users->{admin}->{pass} = unix_md5_crypt($admin_pass);
    $users->{admin}->{access_level} = 9999;
    my $useryaml = ();
    $useryaml = Dump $users;  ## YAML
    write_file('system/users.yml', $useryaml) if $useryaml;
    
    
$config->{settings}->{server} = $conf_server;
$config->{settings}->{port} = $conf_port;
$config->{settings}->{nick} = $conf_nickname;
$config->{settings}->{username} = $conf_username;
$config->{settings}->{ircname} = $conf_ircname;
$config->{settings}->{cmdprefix} = $cmd_prefix;

## save to yml:
my $yaml = ();
$yaml = Dump $config;  ## YAML
write_file('system/config.yml', $yaml) if $yaml;

print "=================================================\n";
print "============[ INSTALLATION COMPLETE ]============\n";
print "=================================================\n";

sub getinput {
    my $title = shift || return;
    my $minlength = shift || 5;
    my $default = shift;

    print ">> ".$title. ": \n";
    print "(Default: ".$default.")\n" if $default;
    
    my $conf_value = <STDIN>;			# Get input
    chomp $conf_value;			# Remove the newline at end
    
    if (length($conf_value)==0) {
        return $default if ($default);
    }
    
    while (length($conf_value) < $minlength) {
#        $config->{settings}->{$conf_hash_name} = $conf_value;
        print "Invalid input. Must be at least $minlength characters long.\n";
        print ">> ".$title. ": ";
        $conf_value = <STDIN>;
    }
    return $conf_value;    
}


#print Dumper $config;
exit 0;