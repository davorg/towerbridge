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

sub name {
  my $self = shift;

  return 'Tower Bridge lift: '
    . $self->vessel
    . ' (' . $self->direction . ')';
}

sub description {
  my $self = shift;

  return 'Watch Tower Bridge raise as '
    . $self->vessel . ' '
    . 'travels ' . lc $self->direction
}

sub json {
  my $self = shift;

  return {
    datetime  => $self->datetime->iso8601 . $self->datetime->strftime('%z'),
    vessel    => $self->vessel,
    direction => $self->direction,
  };
}

sub json_ld {
  my $self = shift;

  return {
    '@context' => 'http://schema.org',
    '@type'    => 'Event',
    location   => {
      '@type'  => 'Place',
      'name'   => 'Tower Bridge',
      address  => {
        '@type'         => 'PostalAddress',
        streetAddress   => 'Tower Bridge Road',
        addressLocality => 'Southwark',
        postalCode      => 'SE1 2UP',
        addressRegion   => 'London',
        addressCountry  => 'United Kindgom',
      },
    },
    offers     => {
      '@type'       => 'Offer',
      price         => '0.00',
      priceCurrency => 'GBP',
      availability  => 'http://schema.org/InStock',
      validFrom     => '1970-01-01',
      url           => 'https://towerbridge.dave.org.uk',
    },
    performer  => {
      '@type'  => 'Organization',
      name     => 'Tower Bridge',
    },
    organizer  => {
      '@type'  => 'Organization',
      name     => 'Tower Bridge',
      url      => 'https://towerbridge.org.uk/',
    },
    image      => 'towerbridge.jpg',
    name       => $self->name,
    startDate  => $self->datetime->iso8601,
    endDate    => $self->datetime->add( minutes => 10 )->iso8601,
    description => $self->description,
    eventStatus => 'http://schema.org/EventScheduled',
    eventAttendanceMode => 'http://schema.org/OfflineEventAttendanceMode',
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
