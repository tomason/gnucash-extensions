package Finance::Quote::PioneerInvestments;
require 5.013002;

use strict;

use vars qw($VERSION $BASE_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder;

$VERSION = '0.1';
$BASE_URL = 'http://www.pioneer.cz/Fond/AktualniInfo.asp?fond=';

sub methods {
  return ( pioneer_czk       => \&pioneer_czk,
           pioneer_czkhedged => \&pioneer_czkhedged );
}

{
  my @labels = qw/date isodate method source name currency price/;

  sub labels {
    return ( pioneer_czk       => \@labels ,
             pioneer_czkhedged => \@labels );
  }
}

sub pioneer_czk {
  my $quoter  = shift;
  my @symbols = @_;

  return pioneer($quoter, "CZK", @symbols);
}

sub pioneer_czkhedged {
  my $quoter  = shift;
  my @symbols = @_;

  return pioneer($quoter, "CZK_Hedged", @symbols);
}

sub pioneer {
  my $quoter  = shift;
  my $class   = shift;
  my @symbols = @_;

  return unless @symbols;
  my %funds;

  foreach my $symbol (@symbols) {
    my $name  = $symbol;
    my $url   = $BASE_URL;
    $url   = $url . $name;
    $url   = $url . "&class=" . $class;
    my $ua    = $quoter->user_agent;
    my $reply = $ua->request(GET $url);
    
    unless ($reply->is_success) {
      foreach my $symbol (@symbols) {
        $funds{$symbol, "success"}  = 0;
        $funds{$symbol, "errormsg"} = "HTTP failure";
      }
      return wantarray ? %funds : \%funds;
    }

    my $tree = HTML::TreeBuilder->new_from_content($reply->content);
    my @price_array = $tree -> look_down(_tag=>'table',class=>'datasheet') -> look_down(_tag=>'td');
    my $price = @price_array[0]->as_text =~ s/(\d+),(\d+).K./\1.\2/r;
    my @date_array = $tree -> look_down(_tag=>'h2');
    my $date = @date_array[0]->as_text =~ s/Denn. informace k.(\d+)\.(\d+)\.(\d+)/\3-\2-\1/r;


    $funds{$name, 'method'}   = 'pioneer';
    $funds{$name, 'price'}    = $price;
    $funds{$name, 'currency'} = 'CZK';
    $funds{$name, 'success'}  = 1;
    $funds{$name, 'symbol'}  = $name;
    $funds{$name, 'source'}   = 'Finance::Quote::PioneerInvestments';
    $funds{$name, 'name'}   = $name;
    $funds{$name, 'p_change'} = "";  # p_change is not retrieved (yet?)
    
    #will default to today
    $quoter->store_date(\%funds, $name, {isodate => $date});
  }

  # Check for undefined symbols
  foreach my $symbol (@symbols) {
    unless ($funds{$symbol, 'success'}) {
      $funds{$symbol, "success"}  = 0;
      $funds{$symbol, "errormsg"} = "Fund name not found";
    }
  }

  return %funds if wantarray;
  return \%funds;
}

1;

=head1 NAME

Finance::Quote::Bloomberg - Obtain fund prices the Fredrik way

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %fundinfo = $q->fetch("bloomberg","fund name");

=head1 DESCRIPTION

This module obtains information about fund prices from
www.bloomberg.com.

=head1 FUND NAMES

Use some smart fund name...

=head1 LABELS RETURNED

Information available from Bloomberg funds may include the following labels:
date method source name currency price. The prices are updated at the
end of each bank day.

=head1 SEE ALSO

Perhaps bloomberg?

=cut
