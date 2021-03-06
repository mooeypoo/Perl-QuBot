#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use Term::ANSIColor qw(:constants);
use YAML::XS;

use POE;
use POE::Component::IRC::State;
use POE::Component::Client::DNS;
use POE::Component::IRC::Plugin::AutoJoin;
use IRC::Utils;

use File::Slurp;
use File::Open qw(fopen fopen_nothrow fsysopen fsysopen_nothrow);

use DateTime;
use Text::ParseWords; 
#use Crypt::PasswdMD5;
use Crypt::Passwd::XS;

use Scalar::Util qw(looks_like_number);
use Data::Dumper;

use Email::Valid;

### Defining constants ###
use constant {
    AUTH_ADMIN => 9999,
    AUTH_BOTOP => 500,
    AUTH_CONTRIBUTOR => 100,
    AUTH_USER => 10,
};

##########################

my $configfile = read_file('system/config.yml') if (-e 'system/config.yml');
my $config = Load $configfile if ($configfile);
unless ($config) {
    system 'perl system/installer.pl';
    my $cfile = read_file('system/config.yml') if (-e 'system/config.yml');
    $config = Load $cfile if ($cfile);
}

print Dumper $config;

my $userfile = read_file('system/users.yml') if (-e 'system/users.yml');
my $helpfile = read_file('system/help.yml') if (-e 'system/help.yml');
my $repliesfile = read_file('db/autoreplies.yml') if (-e 'db/autoreplies.yml');
my $quotesfile = read_file('db/quotes.yml') if (-e 'db/quotes.yml');


my $autoreplies = Load $repliesfile if ($repliesfile);
my $users = Load $userfile if ($userfile);
my $bothelp = Load $helpfile if ($helpfile);
my $quotes = Load $quotesfile if ($quotesfile);

my $triggers;
for my $key (keys %{ $autoreplies }) {
    push(@$triggers, $key);
}


my $channels = $config->{settings}->{channels};
my %chans = %$channels;

my $loggedin;

my ($irc) = POE::Component::IRC::State->spawn();
my $dns = POE::Component::Client::DNS->spawn();

my %commands = (
                'refresh' => \&bot_refresh, ##re-read configuration files
                'help' => \&bot_help, ## help files
                'cmdprefix' => \&bot_cmdprefix, ##change command char
                ## BOT ADMINSTRATION ##
                'adduser' => \&bot_adduser, ##add a user to the bot
                'edituser' => \&bot_edituser, ##edit user details
                'login' => \&bot_login, ##log into the bot
                'currops' => \&bot_ops, ##output list of loggedin users
                ## QUOTES ##
                'quote' => \&bot_quote, ##get quote (specific or random)
                'addquote' => \&bot_addquote, ##add a quote to the db
                'delquote' => \&bot_delquote, ##add a quote to the db
                'infoquote' => \&bot_infquote, ##add a quote to the db

                    'q' => \&bot_quote, ##alias for 'quote'
                    'addq' => \&bot_addquote, ##alias for addquote
                    'delq' => \&bot_delquote, ##alias for delquote
                    'infoq' => \&bot_infquote, ##add a quote to the db
                    'voteq' => \&bot_votequote, ##vote a quote up or down
                ## CHAN ADMINISTRATION ##
                'op' => \&bot_chan_op, ## op someoe on the channel
                ## FUN / MISC ##
                'slap' => \&bot_slap,
                );

my $cmdchar = $config->{settings}->{cmdprefix}; ##this is the command prefix (default: !)

POE::Session->create(
	inline_states => {
	  _start     => \&on_start,
	  irc_001    => \&on_connect,
	  irc_join    => \&on_user_join,
	  #irc_part => \&on_user_part,
	  #irc_quit => \&on_user_quit,
	  #irc_ctcp_action => \&on_user_ctcp,
	  irc_public => \&on_public,
	  irc_msg => \&on_pvtmsg,
  },
);

sub on_start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];	
    $irc->plugin_add('AutoJoin', POE::Component::IRC::Plugin::AutoJoin->new( Channels => \%chans ));

    print "Starting bot...\n";
    log_activity("LOG", "Starting bot");
    $irc->yield(register => "all");

    $irc->yield(
		connect => {
                    Nick     => $config->{settings}->{nick},
                    Username => $config->{settings}->{username},
                    Ircname  => $config->{settings}->{ircname},
                    Server   => $config->{settings}->{server},
                    Port     => $config->{settings}->{port},
                }
    );
}

sub on_connect {
    print "Connected to ", $irc->server_name(), "\n";
    log_activity("LOG", "Connecting to server");
}

sub on_user_join {
	my ($sender, $kernel, $heap, $who, $where, $msg) = @_[SENDER, KERNEL, HEAP, ARG0 .. ARG2];
	my $nick    = (split /!/, $who)[0];
	my $channel = $where;
	my $me = $irc->nick_name();
	my $hostname =  (split /!/, $who)[1];
	my $ts      = scalar localtime;
	print "[$ts] --- $nick JOINED $channel ($hostname)\n";

	# check if it's the bot itself that just entered the chan:
	if ($hostname eq $irc->nick_long_form($me)) {
            log_activity("LOG","Bot entered channel ".$channel);
	}

}
sub on_public {
    my ($sender, $kernel, $heap, $who, $where, $msg) = @_[SENDER, KERNEL, HEAP, ARG0 .. ARG2];
    my $nick    = (split /!/, $who)[0];
    my $channel = $where->[0];
    my $me = $irc->nick_name();
    my $src = $who;
    my $hostname = (split /!/, $who)[1];
    my $ts      = scalar localtime;
    $msg =~ s/\s+$//;
    print YELLOW ON_BLACK, " [$ts] <$nick:$channel> $msg", RESET, "\n";
        
    ### Auto Replies ###        
    my @trig = grep { $msg =~ /(?i)$_/ } @{ $triggers };
    if (@trig) {
        
        my $num = rand(@{$autoreplies->{$trig[0]}}); 
        my $reply = $autoreplies->{$trig[0]}->[$num];

        $reply =~ s/%nick%/$nick/ if ($reply);
        $reply =~ s/%chan%/$channel/ if ($reply);

        #print "num: $num\n";
        #print "reply: $reply\n";
        

        if ($reply =~ /^\/me/) {
            $reply =~ s/^\/me //;
            $irc->yield(ctcp => $channel => 'ACTION '.$reply);
        } else {
            $irc->yield(privmsg => $channel, $reply);
        }
    }
    
    ## ANALYZE COMMANDS:
    my $cmd = is_cmd($msg);
    if ($cmd) {
        my @params = split(" ", $cmd);
        my $cmdword = $params[0];
        shift(@params); ##now $cmdword is not part of params


        if ($cmdword eq 'op') {
            if ((defined $params[0] && $params[0] !~ /#/) or (!$params[0])) {
                unshift(@params, $channel);
            }
        }
        unshift(@params, $who);

        my $cmdresult = $commands{$cmdword}->(@params[0..$#params]) if defined $commands{$cmdword};

        if ($cmdresult) {
            my $restarget = $channel;
               $restarget = $cmdresult->{target} if (defined $cmdresult->{target} && $cmdresult->{target} ne 'chan');
               
            my $restype = 'privmsg';
               $restype = $cmdresult->{type} if $cmdresult->{type};
                
            
            print "[$restarget/$restype]".$cmdresult->{output}."\n";
            $irc->yield($restype => $restarget => $cmdresult->{output});
        }
    }
    
}



sub on_pvtmsg {
	my ($sender, $heap, $kernel, $hostmask, $where, $msg) = @_[SENDER, HEAP, KERNEL,  ARG0 .. ARG2];
	my $nick    = (split /!/, $hostmask)[0];
	my $me = $irc->nick_name();
	my $hostname = (split /!/, $hostmask)[1];
	my $ts      = scalar localtime;
	$msg =~ s/\s+$//;
	print ON_BLUE, "[$ts] <$nick:(private)> $msg", RESET, "\n";

    ## ANALYZE COMMANDS:
    my $cmd = is_cmd($msg);
    if ($cmd) {
        my @params = split(" ", $cmd);
        my $cmdword = $params[0];
        shift(@params); ##now $cmdword is not part of params
        unshift(@params, $hostmask);
        

        my $cmdresult = $commands{$cmdword}->(@params[0..$#params]) if defined $commands{$cmdword};

        if ($cmdresult) {
            my $restarget = $nick;
                $restarget = $cmdresult->{target} unless ($cmdresult->{target} eq 'user');
            my $restype = 'privmsg';
                $restype = $cmdresult->{type} if $cmdresult->{type};
                
            
            print "[$restarget/$restype]".$cmdresult->{output}."\n";
            $irc->yield($restype => $restarget => $cmdresult->{output});
        }
    }
	
}
################################
######### BOT COMMANDS #########
################################
sub is_cmd {
    my $txt = shift || return;
    
    if (index($txt, $cmdchar) == 0) {
        my $ncmd = substr($txt, 1, length($txt)-1);
        return $ncmd;
    }
    return;
}

sub bot_refresh {
    my $hostmask = shift;
    
    $config = {};
    $autoreplies = {};
    $quotes = {};
    $triggers = [];
    
    my $nick    = (split /!/, $hostmask)[0];
    my $hostname = (split /!/, $hostmask)[1];
    ## Check auth:
    return output("Unauthorized request.","privmsg","user") unless (check_auth($hostname, AUTH_ADMIN));

    my $cfile = read_file('system/config.yml');
    my $ufile = read_file('system/users.yml');
    my $rfile = read_file('db/autoreplies.yml');
    my $qfile = read_file('db/quotes.yml');
    $users = Load $ufile;
    $config = Load $cfile;
    $autoreplies = Load $rfile;
    $quotes = Load $qfile;
    
    for my $key (keys %{ $autoreplies }) {
        push(@$triggers, $key);
    }        
    my $result;
        
    $result->{output} = "All files updated.";
    return $result;
    

}


sub bot_cmdprefix {
    my $hostmask = shift || return;
    my $newchar = shift || '';
    
    my $nick    = (split /!/, $hostmask)[0];
    my $hostname = (split /!/, $hostmask)[1];

    unless ($newchar) {
        ##say what it is:
        return output("Command prefix: [".$config->{settings}->{cmdprefix}."]", "privmsg");
    }
    
    ## Check auth:
    return output("Unauthorized request.","privmsg") unless (check_auth($hostname, AUTH_ADMIN));
    
    ##replace:
    $config->{settings}->{cmdprefix} = $newchar;
    $cmdchar = $newchar;
    ##save the yml again:
    save_yml($config,'config.yml','system');
    return output("New command prefix: [$newchar]", "privmsg");
}

sub bot_help {
    my $hostmask = shift || return;
    my $command = shift || '';
    my @params = @_;

    my $nick    = (split /!/, $hostmask)[0];
    my $hostname = (split /!/, $hostmask)[1];

    my @cmdlist;
    unless ($command) { ##show a list of commands:
        while (my ($cmdlevel, $value) = each(%$bothelp)) {
            $irc->yield('privmsg' => $nick => "[ $cmdlevel ]");
            while (my ($cmdname, $val) = each(%{ $value})) {
                $irc->yield('privmsg' => $nick => $cmdchar.$cmdname." : ".$val->{desc}) if $val->{desc};
            }
        }
        $irc->yield('privmsg' => $nick => "End command list.");
        return;
    } else { ## show help for the particular command:
        if (($bothelp->{admin}->{$command}) or ($bothelp->{op}->{$command}) or ($bothelp->{general}->{$command})) {
            $irc->yield('privmsg' => $nick => "Command: ".$cmdchar.$command);
            my $response;
            if ($bothelp->{admin}->{$command}) {
                $response = $bothelp->{admin}->{$command};
            } elsif ($bothelp->{op}->{$command}) {
                $response = $bothelp->{op}->{$command};
            } elsif ($bothelp->{general}->{$command}) {
                $response = $bothelp->{general}->{$command};
            }
            $irc->yield('privmsg' => $nick => $response->{desc});
            $irc->yield('privmsg' => $nick => "Usage: ".$response->{syntax}) if $response->{syntax};
        } else {
            $irc->yield('privmsg' => $nick => "Unrecognized command: $command");
            return;
        }
    }
    
    return;
}

sub bot_ops {
    my @plist = @_;
    my @syntax = qw/hostmask/;

    my $params;
    
    for my $synt (@syntax) {
        $params->{$synt} = shift @plist;
    }

    my $nick    = (split /!/, $params->{hostmask})[0];
    my $hostname = (split /!/, $params->{hostmask})[1];

    ## Check auth:
    return output("Unauthorized request.","privmsg","user") unless (check_auth($hostname, AUTH_CONTRIBUTOR));
        
    ##see who's "online" from logged in users:
    unless ($loggedin) {
        return output("No users logged in at the moment.",'privmsg','user');
    }
    
    my @lnusers;
    while (my ($key, $value) = each(%$loggedin)){
        push(@lnusers, $loggedin->{$key}->{username}." [".$loggedin->{$key}->{nick}."|LEVEL:".$loggedin->{$key}->{access_level}."] ");
    }

    return output("Logged in users: ".join(", ",@lnusers),'privmsg','user');

}

sub bot_login {
    my @plist = @_;
    my @syntax = qw/hostmask username pass/;
    my @required = qw/hostmask username pass/;
    my $params;
    
    for my $synt (@syntax) {
        $params->{$synt} = shift @plist;
    }
    
    for my $req (@required) {
        unless ($params->{$req}) {
            return output("Missing parameter: $req.","privmsg","user");
        }
    }

    my $nick    = (split /!/, $params->{hostmask})[0];
    my $hostname = (split /!/, $params->{hostmask})[1];

    ### Check if username is already logged in from this hostname:
    #   NOTE: if the username is logged in through a different username,
    #         the bot will ignore that and log the user in again from 
    #         the current hostmask.
    if ($loggedin->{$hostname}->{hostname}) {
        if ($loggedin->{$hostname}->{hostname} eq $hostname) {
            return output("You are already logged in.","privmsg","user");
        }
    }
    
    ##check if username exists:
    unless ($users->{$params->{username}}) {
        return output("Username unrecognized.","privmsg","user");
    }
    
    ##check if pass is right:
    unless (pwd_compare($params->{pass},$users->{$params->{username}}->{pass})) {
        return output("Bad password.","privmsg","user");
    }
    
    ## all good, add to hash:
    $loggedin->{$hostname}->{access_level} = $users->{$params->{username}}->{access_level};
    $loggedin->{$hostname}->{hostname} = $hostname;
    $loggedin->{$hostname}->{nick} = $nick;
    $loggedin->{$hostname}->{username} = $params->{username};
        
    ##update users:
    $users->{$params->{username}}->{last_login} = time();
    $users->{$params->{username}}->{last_nick} = $nick;
    save_yml($users,'users.yml','system');
    
    ##spit it out, bot:
    return output("Login successful.","privmsg","user");

}

sub bot_adduser {
    my @plist = @_;
    my @syntax = qw/hostmask username pass access_level email/;
    my @required = qw/hostmask username pass/;
    my $params;
    
    for my $synt (@syntax) {
        $params->{$synt} = shift @plist;
    }
    
    for my $req (@required) {
        unless ($params->{$req}) {
            return output("Missing parameter: $req.");
        }
    }

    my $nick    = (split /!/, $params->{hostmask})[0];
    my $hostname = (split /!/, $params->{hostmask})[1];

    ## Check auth:
    return output("Unauthorized request.") unless (check_auth($hostname, AUTH_BOTOP));

    ## Make sure that the username doesn't already exist:
    if ($users->{$params->{username}}) {
        return output("Username already exists.");
    }
    
    my $udetails;
    
    $udetails->{username} = $params->{username};
    $udetails->{pass} = #unix_md5_crypt($params->{pass});

    my $salt = create_salt();
    $udetails->{pass} = Crypt::Passwd::XS::crypt($params->{pass}, $salt);
    
    if (looks_like_number($params->{access_level}) and check_auth($hostname, $params->{access_level})) {
        $udetails->{access_level} = $params->{access_level};
    } else {
        $params->{access_level} = 10;
    }
    $udetails->{access_level} = $params->{access_level};

    $udetails->{hostname} = $hostname if ($hostname);
    $udetails->{email} = $params->{email} if (defined $params->{email} && Email::Valid->address($params->{email}));

    ## Save $udetails into the users yml:
    
    $users->{$params->{username}} = $udetails;

    ##resave the yml file, too:
    save_yml($users,'users.yml','system');

    return output("User ".$params->{username}." added with access level ".$params->{access_level}.".");

}

sub bot_edituser {
    my $hostmask = shift || return;
    my $username = shift || return;
    my @params = @_;
    
    

    my $nick    = (split /!/, $hostmask)[0];
    my $hostname = (split /!/, $hostmask)[1];

    ## Make sure that the username exists:
    unless ($users->{$username}) {
        return output("Username doesn't exist.");
    }

    ## Check auth (editing user must be higher-level than edited user):
    return output("You don't have enough authority for this.","privmsg","user") unless (check_auth($hostname, ($users->{$username}->{access_level}+100)));
    

    ## go over params:
    my @ans;
    for my $p (@params) {
        my @pm = split(":",$p);
        if (($pm[0]) && ($pm[1])) {
            ##is the param valid?
            if ($pm[0] eq 'access_level') {
                if ((looks_like_number($pm[1])) and ($pm[1] < $loggedin->{$hostname}->{access_level})) {
                    $users->{$username}->{access_level} = $pm[1];
                    push(@ans, "access_level updated to ".$pm[1]);
                }
            }
            if ($pm[0] eq 'pass') {
                $users->{$username}->{pass} = unix_md5_crypt($pm[1]);
                push(@ans, "password updated");
            }
            if ($pm[0] eq 'email') {
                if (Email::Valid->address($pm[1])) {
                    $users->{$username}->{email} = $pm[1];
                    push(@ans, "email updated");
                } else {
                    push(@ans, "email not updated (Error: invalid email)");
                }
            }
        }
    }    
   
    ##resave the yml file:
    save_yml($users,'users.yml','system');

    return output("User $username edited: ".split(", ",@ans));

}


### QUOTE DB COMMANDS ###
sub bot_addquote {
    my $hostmask = shift || return;
    
    my $quote = join(" ",@_);
    
    return output("USE: ".$cmdchar."addquote [quote]") unless ($quote);

    ## check auth:
    my $nick    = (split /!/, $hostmask)[0];
    my $hostname = (split /!/, $hostmask)[1];

    ## Check auth:
    return output("Unauthorized request.") unless (check_auth($hostname, AUTH_CONTRIBUTOR));

    my $counter;
    ##add to quotes:
    if ($quotes) {
        $counter = scalar(keys $quotes) + 1;
    }else{
        $counter = 1;
    }

    ##verify counter doesn't already exist:
    while ($quotes->{$counter}->{text}) {
        $counter++;
    }
    
    $quotes->{$counter}->{text} = $quote;
    $quotes->{$counter}->{user} = $loggedin->{$hostname}->{username};
    $quotes->{$counter}->{date} = time();
    $quotes->{$counter}->{rating} = 0;
    
    ##save to yml:
    save_yml($quotes,'quotes.yml','db');
    
    return output("Quote #".$counter." saved.");

}
sub bot_quote {
    my $hostmask = shift || return;
    my $quoteid = shift || '';
    
    $quoteid = 0 unless looks_like_number($quoteid);
    my $rating = 0;

    if ($quoteid) { ## get specific quote
        $rating = $quotes->{$quoteid}->{rating} if $quotes->{$quoteid}->{rating};
        return output("[#$quoteid] ".$quotes->{$quoteid}->{text}." ($rating)") if $quotes->{$quoteid}->{text};
        ## if quote doesn't exist:
        return output("Can't find quote #$quoteid");
    }
    
    
    ##get random quote:
    my @keys = keys %{ $quotes };
    my $num = $keys[rand @keys];
    
    ##check if there are quotes at all:
    return output("No quotes in the database.") unless (@keys);

    $rating = $quotes->{$num}->{rating} if $quotes->{$num}->{rating};

    return output("[#$num] ".$quotes->{$num}->{text}." ($rating)");


}
sub bot_delquote {
    my $hostmask = shift || return;
    my $quoteid = shift || '';
    
    ## check auth:
    my $nick    = (split /!/, $hostmask)[0];
    my $hostname = (split /!/, $hostmask)[1];

    ## Check auth:
    return output("Unauthorized request.") unless (check_auth($hostname, AUTH_BOTOP));

    ## if quoteid is bad:
    return ("To do that, I need an actual quote ID.") unless looks_like_number($quoteid);
    
    ## if quote doesn't exist:
    return output("Can't find quote #$quoteid") unless $quotes->{$quoteid};

    ## delete quote:
    delete $quotes->{$quoteid};
    
    ##save the yml again:
    save_yml($quotes,'quotes.yml','db');
    
    return output("Quote #".$quoteid." deleted.");
    
}
sub bot_infquote {
    my $hostmask = shift || return;
    my $quoteid = shift || '';
    
    return output("Must supply quote id.") unless $quoteid;
    
    $quoteid = 0 unless looks_like_number($quoteid);
    
    ## if quote doesn't exist:
    return output("Can't find quote #$quoteid") unless ($quotes->{$quoteid}->{date});

    ###my $dt = DateTime->from_epoch( $quotes->{$quoteid}->{date} );
    my $fulldate = scalar gmtime $quotes->{$quoteid}->{date};
    return output("Quote #$quoteid submitted by ".$quotes->{$quoteid}->{user}." (on ".$fulldate.") current rating: ".$quotes->{$quoteid}->{rating}) if $quotes->{$quoteid}->{text};
    
}

sub bot_votequote {
    my $hostmask = shift || return;
    my @params = @_;
    
    ##missing params
    return output("USAGE: vote [up|down] [quoteid]") if ($#params < 1);
    
    my $vote = 0;
    $vote = 1 if ($params[0] eq 'up');
    $vote = -1 if ($params[0] eq 'down');

    if (!looks_like_number($params[1]) || !$vote) {
        return output("USAGE: vote [up|down] [quoteid]");
    }
    
    ## if quote doesn't exist:
    return output("Can't find quote #".$params[1]) unless ($quotes->{$params[1]}->{text});

    ##change rating:
    my $currvote = $quotes->{$params[1]}->{rating};
    $quotes->{$params[1]}->{rating} = $currvote + $vote;
    
    ##save yml:
    save_yml($quotes,'quotes.yml','db');
    return output("Quote #".$params[1]." rating updated (".$params[0].")");
}


### GENERAL COMMANDS ####
sub bot_slap {
    my $hostmask = shift || '';
    my $slapee = shift || '';

    my $result;
    
    my $whois = $irc->nick_long_form($slapee);
    if ($whois) {
        return output("ACTION slaps ".$slapee." around with a large fluffy brick.", 'ctcp', 'chan');
    }
    return output("Who?", 'privmsg', 'chan');
    
}

sub bot_chan_op {
    my $hostmask = shift || '';
    my $chan = shift || '';
    my $nick = shift || '';
    
    ##check auth:
    my $hostname = (split /!/, $hostmask)[1];
    return output("Unauthorized request.","privmsg") unless (check_auth($hostname, AUTH_BOTOP));
    
    my $mynick = $irc->nick_name();
    print $mynick;
    
    ##check if bot is op in the channel:
    if ($irc->is_channel_operator($chan,$mynick)) {
        ##check if the requested nick is in the channel:
        if ($irc->is_channel_member($chan,$nick)) {
            $irc->yield(mode => $chan." +o ".$nick);
            return output("There's a new sherrif in town.", 'privmsg', 'chan');
        }
        
        return output("Who?", 'privmsg', 'chan');
    } else {
        return output("I would've considered complying, if I had the power.", 'privmsg', 'chan');
    }
}



#############################
######### FUNCTIONS #########
#############################
sub output {
    my $output = shift || return;
    my $type = shift || '';
    my $target = shift || '';
    
    my $r;
    
    $r->{output} = $output;
    $r->{type} = $type if ($type);
    $r->{target} = $target if ($target);
        
    return $r;
}

sub check_auth {
    my $user_hostname = shift || return;
    my $required_level = shift || 0;
    
    if ((defined $loggedin->{$user_hostname}) && ($loggedin->{$user_hostname}->{access_level} >= $required_level)) {
        ## authorized
        return 1;
    } else {
        ## unauthorized
        return 0;
    }
    
}

sub log_activity {
	my $activity = shift || "LOG";
	my $logmsg = shift || return;
	my $who = shift || "SYSTEM"; ##either a channel or a person, if neither, will be SYSTEM
	
	my $td = DateTime->now;
	my $timestamp = $td->mdy('/')." ".$td->hms;

	my $logfile = "logs/ircbot_log_".$td->mdy('-');

	my $message = "($timestamp) [$activity] (by $who) $logmsg\n";
	
	my $fh = fopen $logfile, 'a' or die "cannot open $logfile: $!";

	print $fh $message;

        if ($activity eq "ERR") {
            print BOLD, RED, $message, RESET;
        } elsif ($activity eq "MINOR") {
            print BOLD, BLUE, $message, RESET;
        } else {
            print $message;
        }
        print RESET;
}

sub save_yml {
	my $ymlhash = shift || return;
	my $ymlfilename = shift || return;
        my $ymlfolder = shift || '';
	
	my $yaml = ();
	
	$yaml = Dump $ymlhash;  ## YAML
	
        my $fullpath;
        
        if ($ymlfolder) {
            $fullpath = $ymlfolder."/".$ymlfilename ;
        } else {
            $fullpath = $ymlfilename;
        }
        
	write_file($fullpath, $yaml) if $yaml;
}

sub create_salt {
    my @chars = ('a' .. 'z', 0 .. 9, '.', '/' );
    my $salt = join '', map { $chars[rand @chars] } 1 .. 8;
    return '$5$'.$salt.'$';
}

sub pwd_compare {
	my $plain_pwd = shift || return;
	my $crypt_pwd = shift || return;
        
        return 1 if $crypt_pwd eq Crypt::Passwd::XS::crypt($plain_pwd, $crypt_pwd);
	return 0;
}


# Run the bot until it is done.
$poe_kernel->run();
exit 0;