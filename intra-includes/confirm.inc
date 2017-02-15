[% rspValue = whole.value %]

[% IF whole.stage == "availability" %]
<dl>
  <dt id="availableImmediately">[% rspValue.availableImmediately.0 %]</dt>
  <dd>[% rspValue.availableImmediately.1 %]</dd>
  <dt id="copyrightFee">[% rspValue.copyrightFee.0 %]</dt>
  <dd>[% rspValue.copyrightFee.1 %]</dd>
</dl>
<h3>[% rspValue.formats.0 %]</h3>
[% FOREACH format IN rspValue.formats.1 %]
<form method="POST" action=[% here %]>
  <fieldset class="format">
    <input type="hidden" name="format" value="[% format.key.1 %]" />
    <input type="hidden" name="illrequest_id" value="[% rspValue.illrequest_id %]" />
    <input type="hidden" name="method" value="[% whole.method %]" />
    <input type="hidden" name="stage" value="[% whole.future %]" />
    <h4>[% format.format.0 %]: [% format.format.1 %]</h4>
    <h5>[% format.speeds.0 %]</h5>
    <ul>
      [% FOREACH speed IN format.speeds.1 %]
      <li>
        <input name="speed" id="speed" type="radio"
               value=[% speed.key.1 %] />
        <span id="speed">
          [% speed.speed.0 %]: [% speed.speed.1 %]
        </span>
      </li>
      [% END %]
    </ul>
    <h5>[% format.qualities.0 %]</h5>
    <ul>
      [% FOREACH quality IN format.qualities.1 %]
      <li>
        <input name="quality" id="quality" type="radio"
               value=[% quality.key.1 %] />
        <span id="quality">
          [% quality.quality.0 %]: [% quality.quality.1 %]
        </span>
      </li>
      [% END %]
    </ul>
    <br/>
    <input class="btn btn-default" type="submit" value="Check this price" />
  </fieldset>
</form>
[% END %]
[% ELSIF whole.stage == "pricing" %]
<form method="POST" action=[% here %]>
  <p>[% rspValue.price.0 %]: [% rspValue.currency.1 %] [% rspValue.price.1 %]</p>
  <p>[% rspValue.copyrightVat.0 %]: [% 100 * rspValue.copyrightVat.1 %]%</p>
  <p>[% rspValue.loanRenewalCost.0 %]: [% rspValue.currency.1 %] [% rspValue.loanRenewalCost.1 %]</p>
  <input name="format" id="format"
         value="[% rspValue.coordinates.format %]" type="hidden"/>
  <input name="speed" id="speed"
         value="[% rspValue.coordinates.speed %]" type="hidden"/>
  <input name="quality" id="quality"
         value="[% rspValue.coordinates.quality %]" type="hidden"/>
  <input name="service" id="service"
         value="[% rspValue.service.1 %]" type="hidden"/>

  <input type="hidden" name="illrequest_id" value="[% rspValue.illrequest_id %]" />
  <input type="hidden" name="method" value="[% whole.method %]" />
  <input type="hidden" name="stage" value="[% whole.future %]" />
  <input class="btn btn-default" type="submit" value="Place request" />
</form>
[% ELSIF whole.stage == "commit" %]
<!-- Final stage! We simply emit the summary returned in ill -->
<!-- Though this is currently handled by the `message` section of ill-manage.tt:
     This bit is currently entirely ignored. -->
<ol>
  [% FOREACH field IN ill %]
  [% IF field.value.1 and field.key != 'id' %]
  <li>
    <label id=[% field.key %]>[% field.value.0 _ ":" %]</label>
    [% IF field.key == 'borrower' %]
    [% IF field.value.1.deleted %]
    Deleted borrower
    [% ELSE %]
    [% brw = field.value.1 %]
    <a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=[% brw.borrowernumber %]"
    title="View borrower details">
      [% brw.firstname _ " " _ brw.surname _ ", " _ brw.cardnumber %]
    </a>
    [% END %]
    [% ELSIF field.key == 'primary_notes_staff' or field.key == 'primary_notes_opac' %]
    <span id="[% field.key %]"><pre>[% field.value.1 %]</pre></span>
    [% ELSIF field.key == 'status' %]
    <span id="[% field.key %]">
      [% AuthorisedValues.GetByCode( 'ILLSTATUS', field.value.1 ) %]
    </span>
    [% ELSE %]
    <span id=[% field.key %]>[% field.value.1 %]</span>
    [% END %]
  </li>
  [% END %]
  [% END %]
</ol>
<p><a href=[% forward %] title="View all requests">View requests.</a></p>
[% ELSE %]
<h3>Unknown Stage of Confirm method</h3>
[% END %]
