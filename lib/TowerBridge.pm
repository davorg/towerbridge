package TowerBridge;

use strict;
use warnings;
use feature 'state';
use builtin 'trim';

use Moo;
use Types::Standard qw[Str ArrayRef InstanceOf];

use DateTime;
use DateTime::Format::Strptime;
use Data::ICal;
use Data::ICal::Entry::TimeZone;
use Data::ICal::Entry::TimeZone::Standard;
use Data::ICal::Entry::TimeZone::Daylight;
use Web::Query;

use TowerBridge::Lift;

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

  my @lifts;

  my $url = 'https://www.towerbridge.org.uk/bridge-lifts/';

  wq($url)
    ->find('.time-table.mb-64')
    ->each(sub { push @lifts, parse_data($_[1]) });

  debug('Returning ' . scalar @lifts . " lift(s) from _build_lifts\n");

  return \@lifts;
}

sub parse_data {
  my ($div) = @_;

  state $dt_parser //= DateTime::Format::Strptime->new(
    time_zone => 'Europe/London',
    pattern => '%A %d %B %Y %H:%M',
  );

  my $date = $div->find('.time-table__heading')->text;

  my $rows = $div->find('.bridge-lift-row');

  debug('parse_data found ', $rows->size, " bridge lift rows on $date\n");

  my @lifts;

  $rows->each(sub {
    my ($first, $desc, $vessel) = map { $_->text } $_->find('.bridge-lift-row__content p');
    my ($time, $direction) = split /\s+/, $first;

    push @lifts,     TowerBridge::Lift->new({
      datetime  => $dt_parser->parse_datetime("$date $time"),
      vessel    => "$desc $vessel",
      direction => ($direction // ''), # Direction is sometimes omitted
    })
  });

  debug('Returning ' . scalar @lifts . " lift(s) from parse_data\n");

  return @lifts;
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

  my @json_lifts = map { $_->json } @{ $self->lifts };

  return $self->json_encoder->encode({
    lifts => \@json_lifts,
  });
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

sub debug {
  return unless $ENV{TOWER_BRIDGE_DEBUG};

  warn @_;
}
1;
