#! /usr/bin/env perl
# http://code.google.com/p/perl-compiler/issues/detail?id=95
# IO::Socket::blocking method found in \@ISA
# methods not found. see t/testc.sh -DCsP,-v -O0 95
use strict;
BEGIN {
  unshift @INC, 't';
  require "test.pl";
}
use Test::More;
use Config;
eval "use IO::Socket::SSL";
if ($@) {
  plan skip_all => "IO::Socket::SSL required for testing issue95" ;
} else {
  plan tests => 5;
}

my $issue = <<'EOF';
use IO::Socket::INET   ();
use IO::Socket::SSL    ('inet4');
use Net::SSLeay        ();
use IO                 ();
use Socket             ();

my $handle = IO::Socket::SSL->new(SSL_verify_mode =>0);
$handle->blocking(0);
print "ok";
EOF

my $typed = <<'EOF';
use IO::Socket::SSL();
my IO::Handle $handle = IO::Socket::SSL->new(SSL_verify_mode =>0);
$handle->blocking(0);
print "ok";
EOF

my $ITHREADS = $Config{useithreads};

sub diagv {
  diag @_ if $ENV{TEST_VERBOSE};
}

sub compile_check {
  my ($num,$b,$base,$script,$cmt) = @_;
  my $name = $base."_$num";
  unlink("$name.c", "$name.pl");
  open F, ">", "$name.pl";
  print F $script;
  close F;
  my $X = $^X =~ m/\s/ ? qq{"$^X"} : $^X;
  $b .= ',-DCsp,-v';
  diagv "$X -Iblib/arch -Iblib/lib -MO=$b,-o$name.c $name.pl";
  my ($result,$out,$stderr) =
    run_cmd("$X -Iblib/arch -Iblib/lib -MO=$b,-o$name.c $name.pl", 20);
  unless (-e "$name.c") {
    print "not ok $num # $name B::$b failed\n";
    exit;
  }
  # check stderr for "blocking not found"
  #diag length $stderr," ",length $out;
  if (!$stderr and $out) {
    $stderr = $out;
  }
  my $notfound = $stderr =~ /blocking not found/;
  ok(!$notfound, $cmt.', no "blocking not found" warning');
  # check stderr for "save package_pv "blocking" for method_name"
  my $found = $stderr =~ /save package_pv "blocking" for method_name/;
  if ($found) {
    $found = $stderr !~ /save method_name "IO::Socket::blocking"/;
  }
  ok(!$found, $cmt.', blocking as method_name saved');
}

compile_check(1,'C,-O3,-UB','ccode95i',$issue,"untyped");
compile_check(2,'C,-O3,-UB','ccode95i',$typed,'typed');

use B::C ();
# see #310: Warning: unable to close filehandle DATA properly
# also: Constant subroutine HUGE_VAL redefined
my $qr = '^(ok|Warning: unable to close filehandle.*\nok)$';
my $todo = ($B::C::VERSION lt '1.42_61') ? "TODO " : "";
if ($IO::Socket::SSL::VERSION ge '1.956' and $IO::Socket::SSL::VERSION lt '1.984') {
  $todo = "TODO [cpan #95452] bad IO::Socket::SSL $IO::Socket::SSL::VERSION, ";
}
ctest(5,$qr,'C,-O3,-UB','ccode95i',$issue, $todo.' run');
