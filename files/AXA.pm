package Finance::Quote::AXA;
require 5.013002;

use strict;

use vars qw($VERSION $BASE_URL);

use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder;

$VERSION = '0.1';
$BASE_URL = 'https://www.axainvestice.cz/investicni-fondy/';

sub methods {
  return ( axa_dynamic      => \&axa_dynamic,
           axa_balanced     => \&axa_balanced,
           axa_conservative => \&axa_conservative );
}

{
  my @labels = qw/date isodate method source name currency price/;

  sub labels {
    return ( axa_dynamic       => \@labels,
             axa_balanced      => \@labels,
             axa_conservative  => \@labels );
  }
}

sub axa_dynamic {
  my $quoter  = shift;
  my @symbols = @_;

  return pioneer($quoter, "dynamicke-fondy", @symbols);
}

sub axa_balanced {
  my $quoter  = shift;
  my @symbols = @_;

  return pioneer($quoter, "balancovane-fondy", @symbols);
}

sub axa_conservative {
  my $quoter  = shift;
  my @symbols = @_;

  return pioneer($quoter, "konzervativni-fondy", @symbols);
}

sub pioneer {
  my $quoter  = shift;
  my $type    = shift;
  my @symbols = @_;

  return unless @symbols;
  my %funds;

  foreach my $symbol (@symbols) {
    my $name  = $symbol;
    my $url   = $BASE_URL . $type . "/" . $name;
    my $ua    = $quoter->user_agent;
    my $reply = $ua->request(GET $url);
    
    unless ($reply->is_success) {
      foreach my $symbol (@symbols) {
        $funds{$symbol, "success"}  = 0;
        $funds{$symbol, "errormsg"} = "HTTP failure";
      }
      return wantarray ? %funds : \%funds;
    }

    my $tree = HTML::TreeBuilder -> new_from_content($reply->content);
    my @price_array = $tree -> look_down(_tag=>'span',class=>'value') -> look_down(_tag => 'span');
    # first the date
    my $date = @price_array[1] -> as_text =~ s/(\d+)\.[ ]?(\d+)\.[ ]?(\d+):/\3-\2-\1/r;
    # then the price
    my $price = @price_array[2] -> as_text =~ s/(\d+),(\d+) CZK/\1.\2/r;


    $funds{$name, 'method'}   = 'axa';
    $funds{$name, 'price'}    = $price;
    $funds{$name, 'currency'} = 'CZK';
    $funds{$name, 'success'}  = 1;
    $funds{$name, 'symbol'}  = $name;
    $funds{$name, 'source'}   = 'Finance::Quote::AXA';
    $funds{$name, 'name'}   = $name;
    
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
