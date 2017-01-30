<dl>
  [% FOREACH field IN whole.value %]
  [% IF field.value.1 %]
  <dt>[% field.value.0 %]</dt>
  <dd>
    [% IF field.value.1.0 %]
    <dl>
      [% FOREACH entry IN field.value.1 %]
      [% FOREACH subfield IN entry %]
      [% IF subfield.value.1 %]
      <dt>[% subfield.value.0 %]</dt>
      <dd>[% subfield.value.1 %]</dd>
      [% END %]
      [% END %]
      [% END %]
    </dl>
    [% ELSE %]
    [% field.value.1 %]
    [% END %]
  </dd>
  [% END %]
  [% END %]
</dl>