package Koha::Illbackends::BLDSS::BLDSS::XML;

# Copyright 2015 PTFS Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use XML::LibXML;

use base qw(XML::LibXML);

sub load_xml {
  my $self = shift;
  my $doc  = $self->SUPER::load_xml(@_);
  my $root = $doc->documentElement;
  return $self->rebless($root);
}

sub rebless {
  my ($self, $node) = @_;
  my $interesting_elements = {
    apiResponse     => 1,
    availableFormat => 1,
    availability    => 1,

    deliveryFormat  => 1,
    format          => 1,
    price           => 1,
    quality         => 1,
    result          => 1,
    record          => 1,
    numberOfRecords => 1,
    service         => 1,
    speed           => 1,
    deliveryModifier=> 1,

    newOrder => 1,

    orderline       => 1,
    deliveryDetails => 1,
    address         => 1,
    event           => 1,
  };


  my $name = $node->getName;
  return $node
    unless ((ref($node) eq 'XML::LibXML::Element')
    and (exists(${$interesting_elements}{$name})));

  my $class_name = $self->element2class($name);
  bless($node, $class_name);
  return $node;
}

sub element2class {
  my ($self, $class_name) = @_;
  $class_name = ucfirst($class_name);
  $class_name =~ s/-(.?)/uc($1)/e;
  $class_name = "Koha::Illbackends::BLDSS::BLDSS::XML::$class_name";
}

package Koha::Illbackends::BLDSS::BLDSS::XML::Element;

use base qw(XML::LibXML::Element);
use vars qw($AUTOLOAD @elements @attributes);

sub AUTOLOAD {
  my $self = shift;
  my $name = $AUTOLOAD;
  $name =~ s/^.*::(.*)$/$1/;
  my @elements   = $self->elements;
  my @attributes = $self->attributes;
  if (grep (/^$name$/, @elements)) {

    if (my $new_value = $_[0]) {
      my $new_node = XML::LibXML::Element->new($name);
      my $new_text = XML::LibXML::Text->new($new_value);
      $new_node->appendChild($new_text);
      my @kids = $new_node->childNodes;
      if (my ($existing_node) = $self->findnodes("./$name")) {
        $self->replaceChild($new_node, $existing_node);
      }
      else {
        $self->appendChild($new_node);
      }
    }

    if (my ($existing_node) = $self->findnodes("./$name")) {
      if ($existing_node->firstChild) {
        return $existing_node->firstChild->getData;
      }
      else {
        return '';
      }
    }
    else {
      return '';
    }

  }
  elsif (grep (/^$name$/, @attributes)) {

    if (my $new_value = $_[0]) {
      $self->setAttribute($name, $new_value);
    }

    return $self->getAttribute($name) || '';

    # I've skipped creator & destructor (p182).
  }
}

sub get_one_object {
  my ($self, $xpath, $ns) = @_;
  my $results;
  if ($ns) {
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs('x', $ns);
    $results = $xpc->findnodes($xpath, $self);
  }
  else {
    $results = $self->findnodes($xpath);
  }
  if ($results->size > 1) {
    warn "We have more than one result.  This should not have happened.";
    return 0;
  }
  elsif ($results->size == 0) {
    return 0;
  }
  return Koha::Illbackends::BLDSS::BLDSS::XML->rebless($results->shift);
}

# Stubs

sub elements {
  return ();
}

sub attributes {
  return ();
}

# ApiResponse Object

package Koha::Illbackends::BLDSS::BLDSS::XML::ApiResponse;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw(timestamp status message);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('ApiResponse');
}

sub result {
  my $self = shift;
  return $self->get_one_object("./result");
}

# Result Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Result;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw(currency region copyrightVat loanRenewalCost numberOfRecords);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('result');
}

sub availability {
  my $self = shift;
  return $self->get_one_object("./availability");
}

sub newOrder {
  my $self = shift;
  return $self->get_one_object("./newOrder");
}

sub orderline {
  my $self = shift;
  return $self->get_one_object("./orderline");
}

sub records {
  my $self    = shift;
  my @records = $self->findnodes("./records/record");
  return \@records;
}

sub services {
  my $self = shift;
  my @services = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./services/service");
  return \@services;
}

sub get_service {
  #### DEPRECATE: 99% certain this sub is not used
  warn('**DEPRECATED**: BLDSS::XML::get_service in use');
  my ($self, $id) = @_;
  if (!$id) {
    warn "get_service requires an id!";
    return;
  }
  return $self->get_one_object("./services/service[attribute::id='$id']");
}

# Availability Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Availability;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw(loanAvailabilityDate copyAvailabilityDate copyrightFee
    availableImmediately matchedToSpecificItem isOnOrder);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('availability');
}

sub formats {
  my $self = shift;
  my @formats = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./availableFormats/availableFormat");
  return \@formats;
}

# AvailableFormat Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::AvailableFormat;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw(deliveryModifiers);
}

sub attributes {
  return qw(availabilityDate);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('availableFormat');
}

sub deliveryFormat {
  my $self = shift;
  return $self->get_one_object("./deliveryFormat");
}

sub deliveryModifiers {
  my $self = shift;
  my @deliveryModifiers = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./deliveryModifiers/deliveryModifier");
  return \@deliveryModifiers;
}

sub speeds {
  my $self = shift;
  my @speeds = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./availableSpeeds/speed");
  return \@speeds;
}

sub qualities {
  my $self = shift;
  my @qualities = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./availableQuality/quality");
  return \@qualities;
}

# DeliveryFormat Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::DeliveryFormat;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub attributes {
  return qw(key);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('deliveryFormat');
}

# Delivery Modifier Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::DeliveryModifier;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub attributes {
  return qw(key);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('deliveryModifier');
}

# Speed Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Speed;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub attributes {
  return qw(key);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('speed');
}

# Quality Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Quality;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub attributes {
  return qw(key);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('quality');
}

# Service Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Service;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw();
}

sub attributes {
  return qw(id);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('service');
}

sub formats {
  my $self = shift;
  my @formats = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./format");
  return \@formats;
}

sub get_format {
  my ($self, $id) = @_;
  if (!$id) {
    warn "get_format requires an id!";
    return;
  }
  return $self->get_one_object("./format[attribute::id='$id']");
}

# Record Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Record;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw();
}

sub attributes {
  return qw();
}

sub new {
  my $class = shift;
  return $class->SUPER::new('record');
}

# Format Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Format;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw();
}

sub attributes {
  return qw(id vat);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('format');
}

sub prices {
  my $self = shift;
  my @prices = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./price");
  return \@prices;
}

sub get_price {
  my ($self, $speed, $quality) = @_;
  if (!$speed) {
    warn "get_price: whilst quality is optional, speed is mandatory!";
    return;
  }
  return $self->get_one_object(
    "./price[attribute::speed='$speed' and attribute::quality='$quality']")
    || $self->get_one_object("./price[attribute::speed='$speed']");
}

# Price Object.

package Koha::Illbackends::BLDSS::BLDSS::XML::Price;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw();
}

sub attributes {
  return qw(speed quality);
}

sub new {
  my $class = shift;
  return $class->SUPER::new('price');
}

# newOrder Object

# This is based on the assumption of Synchroneous requests.

package Koha::Illbackends::BLDSS::BLDSS::XML::NewOrder;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw( orderline customerReference service format speed quality
    quantity totalCost estimatedDespatchDate downloadUrl
    copyrightState note );
}

sub new {
  my $class = shift;
  return $class->SUPER::new('NewOrder');
}

# orderline Object

package Koha::Illbackends::BLDSS::BLDSS::XML::Orderline;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw( customerRef note requestor overallStatus metadata
    serviceDetails costDetails history );
}

sub cost {
  my $self = shift;
  return $self->get_one_object('./costDetails/cost')->getAttribute('total')
    || '';
}

sub historyEvents {
  my $self = shift;
  my @events = map { Koha::Illbackends::BLDSS::BLDSS::XML->rebless($_) }
    $self->findnodes("./history/event");
  return \@events;
}

sub deliveryDetails {
  my $self = shift;
  return $self->get_one_object("./deliveryDetails");
}

sub new {
  my $class = shift;
  return $class->SUPER::new('Orderline');
}

# deliveryDetails Object

package Koha::Illbackends::BLDSS::BLDSS::XML::DeliveryDetails;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw( type email );
}

sub address {
  my $self = shift;
  return $self->get_one_object("./address");
}

sub new {
  my $class = shift;
  return $class->SUPER::new('deliveryDetails');
}

# address Object

# Tricky because of the namespace.  Write custom accessors to fetch the
# values.

package Koha::Illbackends::BLDSS::BLDSS::XML::Address;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub _cscore_get_one_object {
  my ($self, $fragment) = @_;
  return $self->get_one_object('./x:' . $fragment,
    'http://www.bl.uk/namespaces/schema/customer/core/v0');
}

sub AddressLine1 {
  my $self = shift;
  return $self->_cscore_get_one_object('AddressLine1')->textContent;
}

sub AddressLine2 {
  my $self = shift;
  return $self->_cscore_get_one_object('AddressLine2')->textContent;
}

sub AddressLine3 {
  my $self = shift;
  return $self->_cscore_get_one_object('AddressLine3')->textContent;
}

sub Country {
  my $self = shift;
  return $self->_cscore_get_one_object('Country')->textContent;
}

sub CountyOrState {
  my $self = shift;
  return $self->_cscore_get_one_object('CountyOrState')->textContent;
}

sub Department {
  my $self = shift;
  return $self->_cscore_get_one_object('Department')->textContent;
}

sub PostOrZipCode {
  my $self = shift;
  return $self->_cscore_get_one_object('PostOrZipCode')->textContent;
}

sub ProvinceOrRegion {
  my $self = shift;
  return $self->_cscore_get_one_object('ProvinceOrRegion')->textContent;
}

sub TownOrCity {
  my $self = shift;
  return $self->_cscore_get_one_object('TownOrCity')->textContent;
}

sub new {
  my $class = shift;
  return $class->SUPER::new('address');
}

# event Object

package Koha::Illbackends::BLDSS::BLDSS::XML::Event;

use base qw(Koha::Illbackends::BLDSS::BLDSS::XML::Element);

sub elements {
  return qw( eventType additionalInfo );
}

sub attributes {
  return qw( time );
}

sub new {
  my $class = shift;
  return $class->SUPER::new('event');
}

1;
