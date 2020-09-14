package Finance::SEC::EdgarData;
use XML::Bare;
use LWP::UserAgent;
use Carp;
use strict;
use warnings;
use v5.10;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw/
  get_filing_url
  get_xbrl_url
  get_filing_dates
  get_filing
  get_rss_url
  get_rss
/;

our $VERSION = '0.01';

my $BASE_URL = 'https://www.sec.gov';
my $RSS_URL = "$BASE_URL/cgi-bin/browse-edgar?action=getcompany&CIK=%s&type=%s&dateb=&owner=exclude&count=500&output=atom";
my $ua = LWP::UserAgent->new;

sub get_rss_url {
  my ($sym, $t) = @_;
  my $url = sprintf($RSS_URL, $sym, $t);
  return $url;
}

sub parse_rss {
  my $xml = shift;
  my $m = XML::Bare->new(text => $xml);
  my $root = $m->parse();
  return $root;
}

sub get_rss {
  my $url = get_rss_url(@_);
  my $res = $ua->get($url);
  if (!($res->is_success)) {
    say STDERR $res->content;
    return 0;
  }
  my $d = $res->content;
  my $rss = parse_rss($d);
  return $rss;
}

sub get_filing_dates {
  my $rss = get_rss(@_);
  my @dates = ();
  for my $n (@{$rss->{feed}->{entry}}) {
    push @dates, $n->{content}->{'filing-date'}->{value};
  }
  return @dates;
}

sub get_filing_url {
  my ($sym, $t, $date) = @_;
  my $rss = get_rss($sym, $t);
  for my $n (@{$rss->{feed}->{entry}}) {
    my $c = $n->{content};
    if ($c->{'filing-date'}->{value} eq $date) {
      return $c->{'filing-href'}->{value};
    }
  }
  return 0;
}

sub get_xbrl_url {
  my $link = shift;
  my $res = $ua->get($link);
  return 0 unless $res->is_success;
  my $d = $res->content;
  my $found = 0;
  while ($d =~ /<table.*?>(.*?)<\/table>/isg) {
    if ($1) {
      my $n = "<root>$1</root>";
      my $m = XML::Bare->new(text => $n);
      my $root = $m->parse();
      for my $t (@{$root->{root}->{tr}}) {
        for (@{$t->{td}}) {
          if ($found) {
            return $BASE_URL . $_->{a}->{href}->{value};
          }
          next unless $_->{value};
          if ($_->{value} =~ /XBRL INSTANCE DOCUMENT/) {
            $found = 1;
          }
        }
      }
    }
  }
  return 0;
}

sub get_filing {
  my ($sym, $t, $date) = @_;
  my $filing_url = get_filing_url($sym, $t, $date);
  my $xbrl_url = get_xbrl_url($filing_url);
  my $res = $ua->get($xbrl_url);
  return 0 unless $res->is_success;
  my $d = $res->content;
  my $m = XML::Bare->new(text => $d);
  my $root = $m->parse();
  return $root;
}

1;

=pod
my @dates = get_filing_dates('aapl', '10-q');
say join ',', @dates;
my $filing_url = get_filing_url('aapl', '10-q', '2019-07-31');
my $xbrl_url = get_xbrl_url($filing_url);
say $xbrl_url;
=cut

__END__
=head1 NAME

Finance::SEC::EdgarData - scraping edgar for fun and profit

=head1 SYNOPSIS

DO STUFF

=head1 DESCRIPTION

This module is a simple interface to Edgar data.

=head1 AUTHOR

Andrew Shapiro, C<< <trski@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2019 Andrew Shapiro.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.
See http://dev.perl.org/licenses/ for more information.

=cut
