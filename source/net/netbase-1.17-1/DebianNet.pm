# DebianNet.pm: a perl module to add entries to the /etc/inetd.conf file
#
# Copyright (C) 1995 Peter Tobias <tobias@et-inf.fho-emden.de>
#                    Ian Jackson <iwj10@cus.cam.ac.uk>
#
#
# DebianNet::add_service($newentry, $group);
# DebianNet::disable_service($service, $pattern);
# DebianNet::enable_service($service, $pattern);
# DebianNet::remove_service($entry);
#

package DebianNet;

require 5.000;

$inetdcf="/etc/inetd.conf";
$sep = "#<off># ";
$version = "1.00";

sub add_service {
    local($newentry, $group) = @_;
    local($service,$searchentry,@inetd,$inetdconf,$found, $success);
    unless (defined($newentry)) { return(-1) };
    chomp($newentry); chomp($group);
    $group = "OTHER" unless (defined($group));
    $group =~ tr/a-z/A-Z/;
    $newentry =~ s/\\t/\t/g;
    ($service = $newentry) =~ s/\s+.*//;
    ($sservice = $service) =~ s/^#//;
    ($searchentry = $newentry) =~ s/\t/\\s\+/g;
    $searchentry =~ s/^#//;
    $searchentry =~ s@\\s\+/\S+\\s\+/\S+@\\s\+\\S\+\\s\+\\S\+@g;

    if (open(INETDCONF,"$inetdcf")) {
        @inetd=<INETDCONF>;
        close(INETDCONF);
        if (grep(m/$sep$sservice\s+/,@inetd)) {
            &enable_service($sservice);
        } else {
            if (grep(m/^$sservice\s+/,@inetd)) {
                if (grep(m/^$sservice\s+/,@inetd) > 1) {
                    &inetde("There are several entries for $sservice in $inetdcf\n");
                } elsif (!grep(m:^#?$searchentry.*:, @inetd)) {
                    &inetde("There is already an entry for $sservice in $inetdcf,
but I don't recognise it.  Here is what it looks like:
 ".join(' ',grep(m/^$sservice\s+/,@inetd)));
                }
            } elsif (grep(m/^#\s*$sservice\s+/, @inetd) >= 1 or
              (($service =~ s/^#//) and grep(m/^$service\s+/, @inetd)>=1)) {
                &printv("Processing service \`$service' ... not changed\n");
            } else {
                &printv("Processing service \`$sservice' ... added\n");
                $inetdconf=1;
            }
        }
        if ($inetdconf) {
            open(ICWRITE, ">$inetdcf.new") || die "Error creating new $inetdcf: $!\n";
            open(ICREAD, "$inetdcf");
            while(<ICREAD>) {
                chop;
                if (/^#:$group:/) {
                    $found = 1;
                };
                if ($found and !(/[a-zA-Z#]/)) {
                    print (ICWRITE "$newentry\n") || die "Error writing new $inetdcf: $!\n";
                    $found = 0;
                    $success = 1;
                }
                print ICWRITE "$_\n";
            }
            close(ICREAD);
            unless ($success) {
                print (ICWRITE "$newentry\n") || die "Error writing new $inetdcf: $!\n";
            }
            close(ICWRITE) || die "Error closing new inetd.conf: $!\n";

            rename("$inetdcf.new","$inetdcf") ||
                die "Error installing new $inetdcf: $!\n";
            umask(000); chmod(0644, "$inetdcf");

            &wakeup_inetd;
        }
    }

    sub inetde {
        do {
            my($response);
            print @_,
"Do you want to ignore this potential problem and continue, or would
you rather not do so now ?  Continue?  (n/y) ";
            $!=0; defined($response=<STDIN>) || die "netconfig: EOF/error on stdin: $!\n";
        } while ($response !~ m/^\s*[yn]?\s*$/i);
        $response =~ m/y/i || exit(1);
        return(1);
    }
    return(1);
}

sub remove_service {
    my($service) = @_;
    unless(defined($service)) { return(-1) };
    chomp($service);
    if($service eq "") {
         print "DebianNet::remove_service called with empty argument\n";
         return(-1);
    }
    open(ICWRITE, ">$inetdcf.new") || die "Error creating $inetdcf.new";
    open(ICREAD, "$inetdcf");
    while(<ICREAD>) {
        chomp;
        unless(/$service/) {
            print ICWRITE "$_\n";
        } else {
            &printv("Removing line: \`$_'\n");
        }
    }
    close(ICREAD);
    close(ICWRITE);

    rename("$inetdcf.new", "$inetdcf") ||
        die "Error installing new $inetdcf: $!\n";
    umask(000); chmod(0644, "$inetdcf");

    &wakeup_inetd;
    return(1);
}

sub disable_service {
    my($service, $pattern) = @_;
    unless (defined($service)) { return(-1) };
    chomp($service);
    open(ICWRITE, ">$inetdcf.new") || die "Error creating new $inetdcf: $!\n";
    open(ICREAD, "$inetdcf");
    while(<ICREAD>) {
      chop;
      if (/^$service\s+\w+\s+/ and /$pattern/) {
          &printv("Processing service \`$service' ... disabled\n");
          $_ =~ s/^(.+)$/$sep$1/;
      }
      print ICWRITE "$_\n";
    }
    close(ICREAD);
    close(ICWRITE) || die "Error closing new inetd.conf: $!\n";

    rename("$inetdcf.new","$inetdcf") ||
        die "Error installing new $inetdcf: $!\n";
    umask(000); chmod(0644, "$inetdcf");

    &wakeup_inetd;
    return(1);
}

sub enable_service {
    my($service, $pattern) = @_;
    unless (defined($service)) { return(-1) };
    chomp($service);
    open(ICWRITE, ">$inetdcf.new") || die "Error creating new $inetdcf: $!\n";
    open(ICREAD, "$inetdcf");
    while(<ICREAD>) {
      chop;
      if (/^$sep$service\s+\w+\s+/ and /$pattern/) {
          &printv("Processing service \`$service' ... enabled\n");
          $_ =~ s/^$sep//;
      }
      print ICWRITE "$_\n";
    }
    close(ICREAD);
    close(ICWRITE) || die "Error closing new inetd.conf: $!\n";

    rename("$inetdcf.new","$inetdcf") ||
        die "Error installing new $inetdcf: $!\n";
    umask(000); chmod(0644, "$inetdcf");

    &wakeup_inetd;
    return(1);
}

sub wakeup_inetd {
    my($pid);
    if (open(P,"/var/run/inetd.pid")) {
        $pid=<P>;
        if (open(C,sprintf("/proc/%d/stat",$pid))) {
            $_=<C>;
            if (m/^\d+ \(inetd\)/) { kill(1,$pid); }
            close(C);
        }
        close(P);
    }
    return(1);
}

sub printv {
    print @_ if (defined($verbose));
}

1;

