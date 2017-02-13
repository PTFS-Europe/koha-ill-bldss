<h2>Request British Library status</h2>
[% request_url = "/cgi-bin/koha/ill/ill-requests.pl?method=status&" %]
[% request_url = request_url _ "stage=commit&illrequest_id=" _ request.illrequest_id %]
<p><a href="[% request_url %]" title="Return to request.">Return to ILL request.</a></p>
[% orderDetails = whole.value.result.orderline %]
<h3>Delivery details</h3>
[% delDetails = orderDetails.deliveryDetails %]
<dl>
  <dt>Delivery type</dt>
  <dd>[% delDetails.type %]</dd>
  [% IF delDetails.email %]
  <dt>Delivery email</dt>
  <dd>[% delDetails.email %]</dd>
  [% ELSIF delDetails.address %]
  <dt>Address line 1</dt>
  <dd>[% delDetails.address.AddressLine1 %]</dd>
  <dt>Address line 2</dt>
  <dd>[% delDetails.address.AddressLine2 %]</dd>
  <dt>Address line 3</dt>
  <dd>[% delDetails.address.AddressLine3 %]</dd>
  <dt>Country</dt>
  <dd>[% delDetails.address.country %]</dd>
  <dt>County or state</dt>
  <dd>[% delDetails.address.CountyOrState %]</dd>
  <dt>Department</dt>
  <dd>[% delDetails.address.Department %]</dd>
  <dt>Postcode</dt>
  <dd>[% delDetails.address.PostOrZipCode %]</dd>
  <dt>Province or region</dt>
  <dd>[% delDetails.address.ProvinceOrRegion %]</dd>
  <dt>Town or City</dt>
  <dd>[% delDetails.address.TownOrCity %]</dd>
  [% END %]
<dl>
<h3>Order details</h3>
<dl>
  <dt>Total cost</dt>
  <dd>[% orderDetails.cost %]</dd>
  <dt>Customer reference</dt>
  <dd>[% orderDetails.customerRef %]</dd>
  <dt>Note</dt>
  <dd>[% orderDetails.note %]</dd>
  <dt>Requestor</dt>
  <dd>[% orderDetails.requestor %]</dd>
  <dt>Status</dt>
  <dd>[% orderDetails.overallStatus %]</dd>
<dl>
<h3>Order history</h3>
[% history = orderDetails.historyEvents %]
[% FOREACH entry IN history %]
<h4>[% entry.eventType %] [[% entry.time %]]</h4>
<p>[% entry.additionalInfo %]</p>
[% END %]
