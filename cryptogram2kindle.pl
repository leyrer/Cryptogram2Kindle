#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  cryptogram2kindle.pl
#
#        USAGE:  ./cryptogram2kindle.pl  
#
#  DESCRIPTION:  Cryptogram2Kindle is a small script I wrote to send Bruce
#                Schneiers Crypto-Gram Newsletter <http://www.schneier.com/crypto-gram.html>
#                to my Kindle for easier reading.
#
#      OPTIONS:  None
# REQUIREMENTS:  See "use" below. They are rather moderate and even on a Debian
#                Lenny system available.
#                Debian: sudo aptitude install libxml-rss-feed-perl libmime-lite-perl 
#         BUGS:  None that I know of ;)
#        NOTES:  The work of "remembering", which feed items it has already seen
#                is done by the XML::RSS::Feed object :)
#       AUTHOR:  Martin Leyrer (leyrer), leyrer@gmail.com
#      COMPANY:  ----
#      VERSION:  1.1
#      CREATED:  2011-08-21 01:47:44
#===============================================================================

use strict;
use warnings;
use XML::RSS::Feed;
use LWP::UserAgent;
use MIME::Lite;
use File::Temp qw/ tempdir /;


# ===============================================
# VARIABLES TO MODIFY -- START
# ===============================================

# The (free) mail address of your Kindle:
my $kindle_address = '[YOUR_KINDLES_NAME]@free.Kindle.com';

# The sender mail address. This has to be one that you have you have authorized
# on the "Manage Your Kindle" page may send personal documents to your Kindle
my $sender_address = 'Dr_Kindle@example.com';

# Working directory where we can store some info between runs
my $work_dir = '~/.crpytogram2kindle';

# URL to Paolo Bernarid's RSS feed with the mobi files.
my $rss_feed = 'https://paolobernardi.wordpress.com/feed/';

# ===============================================
# VARIABLES TO MODIFY -- END
# ===============================================


# Variables & Initialisation
# ==========================
my $tmp_dir = tempdir( CLEANUP => 1 );	# Get me a temporary directory and destroy it once I'm finished.

# Get me an LWP-object with a special user agent set, as we are good netizenz.
my $ua = LWP::UserAgent->new (
			agent => "cryptogramfetcher",
);

# And an RSS object
my $feed = XML::RSS::Feed->new(
	url    => $rss_feed,
	name   => "cryptogram",	# name of the persistent .sto file
	delay  => 10,
	debug  => 0,
	tmpdir => $work_dir, # where to store persisten infos between sessions
);


# Fetch the RSS feed and parse it.
$feed->parse($ua->get($feed->url)->decoded_content);

# Let's iterate through the feeds content and see, if we can find a .mobi-file
# The late_breaking_news method returns only headlines it hasn't seen.
# To do that, it stores data in between calls in the $work_dir.

foreach my $item ($feed->late_breaking_news) {
	if($item->headline =~ /Crypto-Gram.+?\(in EPUB and MOBI format\)/i ) {
		# .mobi file found!
		
		$item->headline =~ /^(.*?)\s\(/i;	# Fetch the RSS headline as the subject of our mail
		my $subject = $1;
	
		# Fetch the actual .mobi file
		my $content = $ua->get($item->url)->decoded_content;
		die "Couldn't get " . $item->url . " !" unless defined $content;
		# Get Filenames
		$content =~ /href\s*=\s*\"(http:\/\/.*?([^\/]+\.mobi))\"/i;
		my $mobi = $1;
		my $fn = $2;
		my $file = $ua->get($mobi)->content;
		if(defined $file) {
			# We got a -mobi file, so write it to disk
			open(OUT, ">$tmp_dir/$fn") or die "Error writing '$fn' - $!\n";
			binmode OUT;
			print OUT $file;
			close(OUT);
		
			# Let's create & send the mail.
			my $msg = MIME::Lite->new(
				From    => $sender_address,
				To      => $kindle_address,
				Subject => $subject,
				Type    => 'multipart/mixed',
			);
			$msg->attach(
				Type     => 'application/x-mobipocket-ebook',
				Path     => "$tmp_dir/$fn",
				Filename => "$fn",
			);
			$msg->send;
			unlink("$tmp_dir/$fn");	# clean up the temp-file
		} else {
			warn"Couldn't get " . $mobi . " !";
		}
	}
}

