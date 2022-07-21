package TowerBridge;

use strict;
use warnings;

use Moo;
use Types::Standard qw[Str ArrayRef InstanceOf];

use DateTime;
use DateTime::Format::Strptime;
use Data::ICal;
use Data::ICal::Entry::TimeZone;
use Data::ICal::Entry::TimeZone::Standard;
use Data::ICal::Entry::TimeZone::Daylight;
use Web::Query;

has dir => (
  is => 'lazy',
  builder => '_build_dir',
  isa => Str,
);

sub _build_dir {
  return 'docs';
}

has filename => (
  is => 'lazy',
  builder => '_build_filename',
  isa => Str,
);

sub _build_filename {
  return 'towerbridge';
}

has ics_path => (
  is => 'lazy',
  builder => '_build_ics_path',
  isa => Str,
);

sub _build_ics_path {
  my $self = shift;

  return $self->dir . '/' . $self->filename . '.ics';
}

has json_path => (
  is => 'lazy',
  builder => '_build_json_path',
  isa => Str,
);

sub _build_json_path {
  my $self = shift;

  return $self->dir . '/' . $self->filename . '.json';
}

has index_path => (
  is => 'lazy',
  builder => '_build_index_path',
  isa => Str,
);

sub _build_index_path {
  my $self = shift;

  return $self->dir . '/index.html';
}

has now => (
  is => 'ro',
  isa => InstanceOf['DateTime'],
  default => sub { DateTime->now(time_zone => 'Europe/London') },
);

has lifts => (
  is => 'lazy',
  isa => ArrayRef[InstanceOf['TowerBridge::Lift']],
  builder => '_build_lifts',
);

sub _build_lifts {
  my $self = shift;

  my $qry_date_fmt = '%d-%m-%Y';
  my $lift_times_from = $self->now->strftime($qry_date_fmt);
  my $lift_times_to   = $self->now->clone->add(years => 1)->strftime($qry_date_fmt);

  my @lifts;

  my $url = 'https://www.towerbridge.org.uk/lift-times/';
  my $params = "lift_times_from=$lift_times_from&lift_times_to=$lift_times_to";

  wq("$url?$params")
    ->find('table.views-table tbody tr')
    ->each(sub { push @lifts, [ map { trim($_->text) } $_[1]->contents ] });

  my $dt_parser = DateTime::Format::Strptime->new(
    time_zone => 'Europe/London',
    pattern => '%H:%M %d %b %Y',
  );

  @lifts = map {
    TowerBridge::Lift->new({
    datetime  => $dt_parser->parse_datetime("$_->[2] $_->[1]"),
    vessel    => $_->[3],
    direction => $_->[4],
  })
  } @lifts;

  return \@lifts;
}

has ical => (
  is => 'lazy',
  isa => InstanceOf['Data::ICal'],
  builder => '_build_ical',
);

sub _build_ical {
  my $self = shift;

  my $ical = Data::ICal->new();

  my $tz = Data::ICal::Entry::TimeZone->new;
  $tz->add_properties(
    tzid => 'Europe/London',
  );

  my $std = Data::ICal::Entry::TimeZone::Standard->new;
  $std->add_properties(
    dtstart => '19710101T020000',
    tzoffsetto => '+0000',
    tzoffsetfrom => '+0100',
    rrule => 'FREQ=YEARLY;WKST=MO;INTERVAL=1;BYMONTH=10;BYDAY=-1SU',
  );
  $tz->add_entry($std);

  my $daylight = Data::ICal::Entry::TimeZone::Daylight->new;
  $daylight->add_properties(
    dtstart => '19710101T010000',
    tzoffsetto => '+0100',
    tzoffsetfrom => '+0000',
    rrule => 'FREQ=YEARLY;WKST=MO;INTERVAL=1;BYMONTH=3;BYDAY=-1SU',
  );
  $tz->add_entry($daylight);

  $ical->add_entry($tz);

  $ical->add_entry($_->ical_event) for @{ $self->lifts };

  return $ical;
}

has json_encoder => (
  is => 'lazy',
  isa => InstanceOf['JSON'],
  builder => '_build_json_encoder',
);

sub _build_json_encoder {
  return JSON->new->pretty->canonical;
}

has simple_json => (
  is => 'lazy',
  isa => Str,
  builder => '_build_simple_json',
);

sub _build_simple_json {
  my $self = shift;

  return $self->json_encoder->encode([ map {
    $_->json
  } @{ $self->lifts } ]);
}

has json_ld => (
  is => 'lazy',
  isa => Str,
  builder => '_build_json_ld',
);

sub _build_json_ld {
  my $self = shift;

  return $self->json_encoder->encode([ map {
    $_->json_ld
  } @{ $self->lifts } ]);
}

sub make_html {
  my $self = shift;

  my $tt = Template->new(OUTPUT_PATH => $self->dir);
  $tt->process('index.tt', { json_ld => $self->json_ld,
                             lifts   => $self->lifts,
                             builtat => $self->now, }, 'index.html')
    or die $tt->error;

  return;
}

## NOT METHODS ##

sub trim {
  return map {
    s/^\s+//;
    s/\s+$//;
    $_
  } @_;
}

1;
