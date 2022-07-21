package TowerBridge::Lift;

use strict;
use warnings;

use Moo;
use Types::Standard qw[InstanceOf Str];

use Data::ICal::Entry::Event;

has datetime => (
  isa => InstanceOf['DateTime'],
  is  => 'ro',
);

has vessel => (
  isa => Str,
  is  => 'ro',
);

has direction => (
  isa => Str,
  is  => 'ro',
);

sub json {
  my $self = shift;

  return {
    datetime  => $self->datetime->iso8601 . $self->datetime->strftime('%z'),
    vessel    => $self->vessel,
    direction => $self->direction,
  };
}

sub ical_event {
  my $self = shift;

  my $event = Data::ICal::Entry::Event->new();
  $event->add_properties(
    summary => 'Tower Bridge Lift',
    description => $self->vessel . ' (' . $self->direction .')',
    dtstart => dt2ical($self->datetime),
    duration => 'PT10M',
    dtstamp => dt2ical(DateTime->now),,
    uid => $self->datetime->epoch . '@towerbridge.dave.org.uk',
  );
}

sub dt2ical {
  my ($dt) = @_;

  return [ $dt->strftime('%Y%m%dT%H%M%S'), { TZID => 'Europe/London' } ];
}

1;
