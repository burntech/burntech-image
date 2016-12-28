#!/usr/bin/perl
use strict;

# Copyright 2016 Neil Verplank
#
# I hacked this together to work on my custom image.  It would appear
# to work.  Use at your own risk.
#
# Takes a "stock" burntech.img for the raspberry pi, and configure
# network settings to individualize the server.  Also offer to
# help with disk re-sizing, root password.




my $hostapd 	= "/etc/hostapd/hostapd.conf";
my $dhcp	= "/etc/dhcp/dhcpd.conf";
my $interface	= "/etc/network/interfaces";

my ($ssid, $channel, $password, $ipaddr, $lowrange, $highrange, $nwdomain, $junk);
my ($ssidO, $channelO, $passwordO, $ipaddrO, $lowrangeO, $highrangeO, $nwdomainO);
my ($tup1, $tup2, $tup3, $tup4, $tup1O, $tup2O, $tup3O, $tup4O, $lripO, $hripO);
my ($response, $tmp, $junk);



# need to be root

    if ($< != 0) {
        print "\nMust be run as root!  Try:\n\n\t\$ sudo ./network_config.pl\n\n";
        exit (0);
    }

# disclaimer

    print "\n\nThis script is meant to customize a default BurnTech.img for the Raspberry Pi.\n";
    print "It would seem to work.  It can be re-run.  I wouldn't recommmend it on anything but\n";
    print "your BurnTech server.  I would be dubious about running it if you've significantly\n";
    print "altered your networking configuration files by hand.  I would recommend not attempting\n";
    print "to get creative with your ssid name, or your ssid password, as those strings are passed\n";
    print "directly to the system, and you could probably wreak some havoc using interesting\n";
    print "escaped characters and or embedded system commands.  So don't do that.\n";
    print "\n\nThis script is provided as is, without any warrantee express or implied, and could\n";
    print "with a little creative effort almost certainly be used to destroy your system.\n";
    print "\n\nYou have been warned.\n\n";

    print "Shall we continue? [yes]: ";
    if (!yes_no(1)) { print "\n\n"; exit(0); }

    print "\n\n";


# running on a pi?

    my $pi = pi_detect();

    if (!$pi) {
        print "\n\nThis does not appear to be a Raspberry Pi?\n\n";
        print "I would recommend not running this (says the guy who wrote it).\n\n";
        print "Are you prepared to continue? (yes) [no]: ";    
        if (!yes_no()) {

            print "\n\nTry me on a BurnTech image running on a raspberry pi!\n\n\n";
            exit(0);
        }
    } else {
        print "\n\nCongrats - you appear to be on a Raspberry Pi of some kind.\n\n"; 
    }

# Get current settings


    open(FILE,"<",$hostapd) || die "can't open $hostapd";
    while (my $row = <FILE>) {
        chop($row);
        if ($row =~ 'ssid' && $row !~ 'ignore_broadcast') { 
           ($junk,$ssid) = split(/=/,$row);
        } elsif ($row =~ 'channel') {
           ($junk,$channel) = split(/=/,$row);
        } elsif ($row =~ 'wpa_passphrase') {
           ($junk,$password) = split(/=/,$row);
        }
    }
    close FILE;
    
    open(FILE,"<",$dhcp) || die "can't open $dhcp";
    while (my $row = <FILE>) {
        chop($row);
        if ($row =~ 'subnet' && $row !~ '#subnet') { 
    
            $row = <FILE>;
            chop($row);
            chop($row);
            $row =~ s/.*range //;
            ($lowrange,$highrange) = split(/ /,$row);

            for (my $i=0; $i<3; $i++) {
                $row = <FILE>;
            }
            chop($row);
            $row =~ s/.*domain-name "//;            
            $row =~ s/";//;            
 
            $nwdomain = $row;
            last;
        }
    }
    close FILE;

    open(FILE,"<",$interface) || die "can't open $interface";
    while (my $row = <FILE>) {
        chop($row);
        if ($row =~ 'iface wlan0') { 
            $row = <FILE>;
            chop($row);
            $row =~ s/.*address //;
            $ipaddr = $row;
        }
    }


    ($ssidO, $channelO, $passwordO, $ipaddrO, $lowrangeO, $highrangeO, $nwdomainO) = 
        ($ssid, $channel, $password, $ipaddr, $lowrange, $highrange, $nwdomain);

    ($tup1O,$tup2O,$tup3O,$tup4O) = split(/\./,$ipaddr);
    ($junk,$junk,$junk,$tmp) = split(/\./,$lowrange);
    $lowrange = $lripO = $tmp;
    ($junk,$junk,$junk,$tmp) = split(/\./,$highrange);
    $highrange = $hripO = $tmp;


# Ask for new settings

ip:
    print  "\nWhat is the new IP address of your wireless router? [$ipaddr]:  ";
    $response = <STDIN>;
    chop($response);

    if ($response) { 
        $response = check_ip($response);
        if ($response > 0) {
            $ipaddr = $response; 
        } else {
            goto ip;
        }
    } 

    ($tup1,$tup2,$tup3,$tup4) = split(/\./,$ipaddr);

    if (!$tup4 || !$tup1) { 
        print "first and last octets can't be 0\n"; 
        goto ip; 
    }


    my $lrip;
low:
    if ($lowrange > $tup4) { $lrip = $lowrange; }
    else { $lrip = $tup4; }

    print  "\nWhat's the lowest IP address to assign (last octet of $tup1.$tup2.$tup3.$lrip)? [$lrip]:  ";
    $response = <STDIN>;
    chop($response);
    if ($response) {
        $response = check_octet($response);
        if (!$response)  { goto low; }
        $lrip = $response;
    }
    if ($lrip <= $tup4) { print "$response must be greater than $tup4\n"; goto low; } 
    $lowrange = "$tup1.$tup2.$tup3.$lrip"; 


    my $hrip;
high:
    if ($lrip == $lripO) { 
        $hrip = $hripO;
    } else {
        $hrip = $lrip+1;
    }
    print  "\nWhat's the highest IP address to assign (last octet of $tup1.$tup2.$tup3.$hrip)? [$hrip]:  ";
    $response = <STDIN>;
    chop($response);
    if ($response) {
        $response = check_octet($response);
        if (!$response)  { goto high; }
        if ($response < $hrip) { print "$response must be equal or greater than $hrip\n"; goto high; }
        $hrip = $response;
    } else {
        $hrip = $hripO;
    }
    $highrange = "$tup1.$tup2.$tup3.$hrip"; 

nwd:
    print  "\nWhat is your new subnet domain name? [$nwdomain]:  ";
    $response = <STDIN>;
    chop($response);
    if ($response) {
        if ($response =~ ' ') { print "invalid characters\n"; goto nwd; }
        elsif ($response =~ '\.') { print "invalid characters\n"; goto nwd; }
        elsif ($response =~ '\/') { print "invalid characters\n"; goto nwd; }
        else { 
            $nwdomain= $response; 
        }
    }

ssid:
# NOTE - this could contain literally any characters under the sun....
    print  "\nWhat is your new wireless ssid? [$ssid]:  ";
    $response = <STDIN>;
    chop($response);
    if ($response) {
        if ($response =~ ' ') { print "invalid characters\n"; goto ssid; }
        elsif ($response =~ '\.') { print "invalid characters\n"; goto ssid; }
        elsif ($response =~ '\/') { print "invalid characters\n"; goto ssid; }
        else { 
            $ssid = $response; 
        }
    }

ch:
    print  "\nWhat wireless channel should I use (1,3,6,11 recommended)? [$channel]:  ";
    $response = <STDIN>;
    chop($response);
    if ($response) {
        if ($response ne $response+0) {
            print "$channel must be an integer between 1 and 11\n";
            goto ch;
        } else { 
            $channel= $response; 
        }
    }

    print  "\nWhat's the new wireless password? [$password]:  ";
    $response = <STDIN>;
    chop($response);
    if ($response) { $password= $response; }



#confirm

    print "\nThese will be your new wireless network settings:\n";

    my $chcount=0;
    my $chg;
    my $uchg = "UNCHANGED";
    if ($ssid eq $ssidO) { $chg = $uchg; } else { $chg = ""; $chcount++; }
    print "\n\tssid:       \t$ssid\t$chg";
    if ($channel eq $channelO) { $chg = $uchg; } else { $chg = ""; $chcount++; }
    print "\n\tchannel:    \t$channel\t\t$chg";
    if ($password eq $passwordO) { $chg = $uchg; } else { $chg = ""; $chcount++; }
    print "\n\tpassword:   \t$password\t$chg";
    if ($ipaddr eq $ipaddrO) { $chg = $uchg; } else { $chg = ""; $chcount++; }
    print "\n\tIP address: \t$ipaddr\t$chg";
    if ($lowrange eq $lowrangeO) { $chg = $uchg; } else { $chg = ""; $chcount++; }
    print "\n\tlow ip:     \t$lowrange\t$chg";
    if ($highrange eq $highrangeO) { $chg = $uchg; } else { $chg = ""; $chcount++; }
    print "\n\thigh ip:    \t$highrange\t$chg";
    if ($nwdomain eq $nwdomainO) { $chg = $uchg; } else { $chg = ""; $chcount++; }
    print "\n\tsubnet name:\t$nwdomain\t\t$chg\n\n";

    if (!$chcount) {
        print "You made no changes! I will also make no changes to any files.\n\n";
        other_things(0);
        exit (0);
    } else  { 
       my $s = "";
       if ($chcount>1) { $s="s"; }
       print "You made $chcount change$s\n\n"; } 

    print "Shall I proceed to alter the network settings (type yes to proceed)? [no]:  ";

    if (!yes_no()) {
        print "\n\n\nCopy That.\n"; 
        other_things(0);
        exit (0); 
    }


#ok, do it

    print "\n\n";

    my ($cmd,$command);

    if ($ssid ne $ssidO || $channelO ne $channel || $password ne $passwordO) {

        doback($hostapd);

        if ($ssidO ne $ssid) {
            doit("perl -pi -e 's/ssid=$ssidO/ssid=$ssid/' $hostapd");
        }
    
        if ($channelO ne $channel) {
            doit("perl -pi -e 's/channel=$channelO/channel=$channel/' $hostapd");
        }
    
        if ($passwordO ne $password) {
            doit("perl -pi -e 's/passphrase=$passwordO/passphrase=$password/' $hostapd");
        }
    } else {
        print "$hostapd left unchanged.\n\n";
    }

    my $ipO = "$tup1O.$tup2O.$tup3O.0";
    my $ip = "$tup1.$tup2.$tup3.0";

    if ($lowrangeO ne $lowrange || $highrangeO ne $highrange || $ipO ne $ip || $nwdomain ne $nwdomainO) {

        doback($dhcp);


        if ($ipO ne $ip) {
            doit("perl -pi -e 's/subnet $ipO/subnet $ip/' $dhcp");
        }

        if ($lowrangeO ne $lowrange || $highrangeO ne $highrange) {
            doit("perl -pi -e 's/range $lowrangeO $highrangeO/range $lowrange $highrange/' $dhcp");
            doit("perl -pi -e 's/routers $ipaddrO/routers $ipaddr/' $dhcp");
        }
       
        if ($nwdomainO ne $nwdomain) {
            doit("perl -pi -e 's/domain-name \"$nwdomainO/domain-name \"$nwdomain/' $dhcp");
        }

    } else {
        print "$dhcp left unchanged.\n\n";
    }



    if ($ipaddrO ne $ipaddr) {

        doback($interface);


        doit("perl -pi -e 's/address $ipaddrO/address $ipaddr/' $interface");

    } else {
        print "$interface left unchanged.\n\n";
    }

    print "\n\nAll changes to networking files complete.\n\n";

    other_things($chcount);
    

exit (0);

### end main code






sub yes_no {

    my $default =  @_[0];
    
    my $response = <STDIN>;
    chop($response);
    $response =~ tr/A-Z/a-z/;

    if ($response eq "yes" || (!$response && $default == 1)) { return 1; }

    return 0;

}


sub pi_detect {

    open my $file, '<', "/proc/cmdline";
    my $firstline = <$file>;
    close $file;
    if ($firstline =~ /bcm2708.boardrev=(0x[0123456789abcdef]*) / ||
        $firstline =~ /bcm2709.boardrev=(0x[0123456789abcdef]*) /) {
        return 1; 
    } else { 
        return 0; 
    }

}


sub doit {

    my $command =  @_[0];

    my $cmd;
    $cmd = `$command`;

    return $cmd;

}


sub doback {

    my $file =  @_[0];

    my $bak = "$file.bak";
    my $cnt = 0;
    while (-f $bak) {
        $bak = "$file.$cnt.bak";
    }
 
    print "\nModifying $file (backup made: $bak)...\n\n";

    doit("cp $file $bak");

}



sub other_things {

    my $changes =  @_[0];
    
    my $cmdd;

    print "\n\n\n\n\n\n";

    print "You may wish to resize your partition to fit your SD card:\n";
    $cmdd = "sudo raspi-config";
    print "\n\t\$ $cmdd\n";
    print "\n\t(choose option 1)\n";

    print "\n\n\n";

    print "Would you like to do that... right now? (yes) [no]:";

    if (yes_no()) {
        print "\n\n";
        doit($cmdd);
        print "\n\n";
    }
    print "\n\n\n\n\n\n";

    print "You should really, really, really change your default 'pi' password if you haven't already:\n";
    $cmdd = "passwd pi";
    print "\n\t\$ $cmdd\n";
    print "\n\n\n";
    print "Would you like to do that... right now? (yes) [no]:";

    if (yes_no()) {
        print "\n\n";
        doit($cmdd);
        print "\n\n";
    }
    print "\n\n";

#    if ($changes) {

        print "\n\n\n\n\n\n";

        print "You need to reboot for the network changes to take effect.\n";
        print "Do note that if you changed anything, you will have to manually\n";
        print "re-connect to the new network!  You wrote that all down, right?\n";

        $cmdd = "sudo shutdown -r now & exit";
        print "\n\t\$ $cmdd\n\n";

        print "Would you like to do that... right now? (yes) [no]:";
        if (yes_no()) {
            print "\n\n";
            print "Note: you will be logged off, and the wireless network is going down....\n";
            print "Depending on what changes you made, you may need to log into a new network!\n\n";
            doit($cmdd);
        }

#    }
}


sub check_octet {

    my $oct =  @_[0];

    my $int =  $response;
    $int    =~ s/[0123456789]//g;
    if ($int ne "") {
        print "$oct not an integer\n";
        return 0;
    }
    if ($response < 1 || $response > 255) { 
        print "$response out of bounds!!\n";
        return 0;
    } 

    return $oct;
}


sub check_ip {

    my $ipadd = @_[0];

ip:
    if( $ipadd =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)$/ ) {
 
        if ($1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255) {
        } else {
            print("$ipadd All octets must contain a number between 0 and 255 \n");
            $ipadd = 0;
        }
    } else  {
        print("IP Address $ipadd  -->  NOT IN VALID FORMAT! \n");
        $ipadd = 0;
    }

    return $ipadd;

}
