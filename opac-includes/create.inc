[% USE Koha %]
[% IF whole.error %]
  [% IF whole.status == 'missing_fields' %]
    <p><em>Please Note:</em> Some mandatory fields are missing.</p>
  [% ELSIF whole.status == 'missing_branch' %]
    <p><em>Please Note:</em> Branch is a mandatory field.</p>
  [% ELSIF whole.status == 'invalid_borrower' %]
    <p><em>Please Note:</em> The borrower details you entered are invalid.</p>
  [% ELSIF whole.status == 'invalid_branch' %]
    <p><em>Please Note:</em> The branch you chose is invalid.</p>
  [% ELSIF whole.status == 'api' %]
    <p><em>Please Note:</em> there was an error whilst communicating with the remote service.</p>
  [% ELSIF whole.status == 'missing_query' %]
    <p><em>Please Note:</em> You did not enter a search query.</p>
  [% ELSIF whole.message %]
    <p><em>[% whole.message %]</em></p>
  [% ELSE %]
    <p><em>Unhandled error</em></p>
  [% END %]
[% END %]

[% IF whole.stage == "commit" %]
<p>We have now created your request.</p>

[% ELSIF whole.stage == "init" %]
<h2>Search the British Library</h2>
<form method="POST">
  <fieldset class="rows">
    <legend>Search the British Library</legend>
    <input name="stage" id="stage" value="validate" type="hidden"/>
    <input name="method" id="method" value="create" type="hidden"/>
    <input name="backend" id="method" value="[% whole.value.other.backend %]" type="hidden"/>
    <ol>
      <li>
        <label for="query">Keywords:</label>
        <input type="text" name="query" id="query" value="[% whole.value.other.query %]" />
      </li>
      <li>
        <label for="isbn">ISBN:</label>
        <input type="text" name="isbn" id="isbn" value="[% whole.value.other.isbn %]" />
      </li>
      <li>
        <label for="issn">ISSN:</label>
        <input type="text" name="issn" id="issn" value="[% whole.value.other.issn %]" />
      </li>
      <li>
        <label for="title">Title (book / journal / article):</label>
        <input type="text" name="title" id="title" value="[% whole.value.other.title %]" />
      </li>
      <li>
        <label for="author">Author / editor:</label>
        <input type="text" name="author" id="author" value="[% whole.value.other.author %]" />
      </li>
      <li>
        <label for="type">Type:</label>
        <select name="type" id="type">
          <option value=""/>
          [% FOREACH opt IN [ 'Book' 'Article' 'Journal' ] %]
          [% IF ( whole.value.other.type == opt ) %]
          <option value="[% opt %]" selected="selected">[% opt %]</option>
          [% ELSE %]
          <option value="[% opt %]">[% opt %]</option>
          [% END %]
          [% END %]
        </select>
      </li>
    </ol>
  </fieldset>
  <fieldset class="rows">
    <legend>Patron options</legend>
    <ol>
      <li>
        <label class="required" for="branchcode">Destination library:</label>
        <select id="branchcode" name="branchcode">
          <option value="" />
          [% FOREACH branch IN branches %]
          [% IF ( whole.value.other.branchcode == branch.branchcode ) %]
          <option value="[% branch.branchcode %]" selected="selected">[% branch.branchname %]</option>
          [% ELSE %]
          <option value="[% branch.branchcode %]">[% branch.branchname %]</option>
          [% END %]
          [% END %]
        </select>
      </li>
    </ol>
  </fieldset>
  <fieldset class="action">
    <input type="submit" value="Search"/>
    <a class="cancel" href="/cgi-bin/koha/opac-illrequests.pl">Cancel</a>
  </fieldset>
</form>

[% ELSIF whole.stage == 'search_results' %]
<h2>Search results</h2>
[% IF whole.value.0 %]
<p role="alert" class="bg-info alert alert-success">
  <span id="search-summary" class="pull-left">
    [% whole.records %] Results of search for: &quot;[% whole.userstring %]&quot;
    [% stage = Koha.Preference('ILLModuleCopyrightClearance') ? 'copyrightclearance' : 'init' %]
    [% url = back _ "?method=create&amp;stage=$stage" %]
    [% url = url _ "&amp;backend=" _ whole.backend %]
    [% url = url _ "&amp;borrowernumber=" _ whole.borrowernumber %]
    [% url = url _ "&amp;brw=" _ whole.borrowernumber %]
    [% url = url _ "&amp;branchcode=" _ whole.branchcode %]
    [% url = url _ "&amp;query=" _ whole.params.other.query %]
    [% url = url _ "&amp;issn=" _ whole.params.other.issn %]
    [% url = url _ "&amp;isbn=" _ whole.params.other.isbn %]
    [% url = url _ "&amp;title=" _ whole.params.other.title %]
    [% url = url _ "&amp;author=" _ whole.params.other.author %]
    [% url = url _ "&amp;type=" _ whole.params.other.type %]
  </span>
  <a href="[% url | url %]" title="Restart search" class="btn btn-default pull-right" role="button">Amend your search</a>
</p>
<table id="ill-opac-results" class="table table-bordered table-striped">
  <thead>
    <tr>
    [% FOREACH field IN whole.value.0 %]
      [% IF field.value.inSummary %]<th class="[% field.key.replace('[^a-zA-Z\d]','_') %]">[% field.value.name %]</th>[% END %]
    [% END %]
    </tr>
  </thead>
  <tbody>
    [% FOREACH record IN whole.value %]
    <tr>
    [% FOREACH field IN record %]
    [% IF field.value.inSummary %]
    [% value = field.value.value || "N/A" %]
      [% IF field.key == './uin' %]
      <td class="ill-action">
      [% url = here _ "?method=create&amp;stage=commit" %]
      [% url = url _ "&amp;backend=" _ whole.backend %]
      [% url = url _ "&amp;borrowernumber=" _ whole.borrowernumber %]
      [% url = url _ "&amp;branchcode=" _ whole.branchcode %]
      [% url = url _ "&amp;query=" _ whole.params.other.query %]
      [% url = url _ "&amp;issn=" _ whole.params.other.issn %]
      [% url = url _ "&amp;isbn=" _ whole.params.other.isbn %]
      [% url = url _ "&amp;title=" _ whole.params.other.title %]
      [% url = url _ "&amp;author=" _ whole.params.other.author %]
      [% url = url _ "&amp;type=" _ whole.params.other.type %]
      [% url = url _ "&amp;uin=" _ value %]
        <a href="[% url | url %]">Request [% value %]</a>
      [% ELSE %]
        <td class="[% field.key.replace('[^a-zA-Z\d]','_') %]">
        [% value %]
      [% END %]
      </td>
    [% END %]
    [% END %]
    </tr>
    [% END %]
  </tbody>
</table>
<p>
  [% IF whole.previous %]
  <a class="nav" title="Previous set of results" href=[% here _ whole.previous | url %]>&lsaquo;&lsaquo; Previous</a>
  [% ELSE %]
  <span> &lsaquo;&lsaquo; Previous</span>
  [% END %]
  [% IF whole.next %]
  <a class="nav" title="Next set of results" href=[% here _ whole.next | url %]>Next &rsaquo;&rsaquo;</a>
  [% ELSE %]
  <span>Next &rsaquo;&rsaquo;</span>
  [% END %]
</p>
[% ELSE %]
<p id="bldss-no-results" role="alert" class="bg-info alert alert-danger">
  <span id="search-summary" class="pull-left">
  No results found for: &quot;[% whole.userstring %]&quot;
  [% stage = Koha.Preference('ILLModuleCopyrightClearance') ? 'copyrightclearance' : 'init' %]
  [% url = back _ "?method=create&amp;stage=$stage" %]
  [% url = url _ "&amp;backend=" _ whole.backend %]
  [% url = url _ "&amp;brw=" _ whole.brw %]
  [% url = url _ "&amp;branchcode=" _ whole.branchcode %]
  [% url = url _ "&amp;query=" _ whole.params.other.query %]
  [% url = url _ "&amp;issn=" _ whole.params.other.issn %]
  [% url = url _ "&amp;isbn=" _ whole.params.other.isbn %]
  [% url = url _ "&amp;title=" _ whole.params.other.title %]
  [% url = url _ "&amp;author=" _ whole.params.other.author %]
  [% url = url _ "&amp;type=" _ whole.params.other.type %]
  </span>
  <a href="[% url | url %]" title="Restart search" class="btn btn-default pull-right" role="button">Amend your search</a>
</p>
[% END %]

[% ELSIF whole.stage == 'extra_details' %]
<h2>Refine request</h2>
<form method="POST" action=[% here %]>
  <fieldset class="rows">
    <input name="backend" id="backend" value="[% whole.backend %]" type="hidden"/>
    <input name="method" id="method" value="create" type="hidden"/>
    <input name="stage" id="stage" value="commit" type="hidden"/>
    <input name="complete" id="complete" value="1" type="hidden"/>
    <input name="branchcode" id="branchcode" value="[% whole.branchcode %]" type="hidden"/>
    <input name="borrowernumber" id="borrowernumber" value="[% whole.borrowernumber %]" type="hidden"/>
    <input name="cardnumber" id="cardnumber" value="[% whole.cardnumber %]" type="hidden"/>
    <input name="query" id="query" value="[% whole.params.query %]" type="hidden"/>
    <input name="isbn" id="isbn" value="[% whole.params.isbn %]" type="hidden"/>
    <input name="issn" id="issn" value="[% whole.params.issn %]" type="hidden"/>
    <input name="title" id="title" value="[% whole.params.title %]" type="hidden"/>
    <input name="author" id="author" value="[% whole.params.author %]" type="hidden"/>
    <input name="type" id="type" value="[% whole.params.type %]" type="hidden"/>
    <input name="uin" id="uin" value="[% whole.params.uin %]" type="hidden"/>
    [% IF whole.value.type == 'book' %]
    <legend>Book Details</legend>
    [% ELSIF whole.value.type == 'journal' %]
    <legend>Journal Details</legend>
    [% ELSIF whole.value.type == 'newspaper' %]
    <legend>Newspaper Details</legend>
    [% END %]
    <ol>
      <li>
        <label for="rtitle">Title:</label>
        <input type="text" name="rtitle" id="rtitle" value="[% whole.value.title %]" readonly/>
      </li>
      [% IF whole.value.type == 'book' %]
      <li>
        <label for="rauthor">Author:</label>
        <input type="text" name="rauthor" id="rauthor" value="[% whole.value.author %]" readonly/>
      </li>
      [% END %]
      [% IF whole.value.publisher %]
      <li>
        <label for="rpublisher">Publisher:</label>
        <input type="text" name="rpublisher" id="rpublisher" value="[% whole.value.publisher %]" readonly/>
      </li>
      [% END %]
      [% IF whole.value.type == 'book' %]
      <li>
        <label for="risbn">ISBN:</label>
        <input type="text" name="risbn" id="risbn" value="[% whole.value.isbn %]" readonly/>
      </li>
      [% ELSIF (whole.value.type == 'journal' || whole.value.type == 'newspaper') && whole.value.issn  %]
      <li>
        <label for="rissn">ISSN:</label>
        <input type="text" name="rissn" id="rissn" value="[% whole.value.issn %]" readonly/>
      </li>
      [% END %]
      [% IF (whole.value.type == 'book') && whole.value.edition %]
      <li>
        <label for="redition">Edition:</label>
        <input type="text" name="redition" id="redition" value="[% whole.value.edition %]" readonly/>
      </li>
      <li>
        <label for="ryear">Year:</label>
        <input type="text" name="ryear" id="ryear" value="[% whole.value.year %]" readonly/>
      </li>
      [% END %]
    </ol>
  </fieldset>
  [% IF (whole.value.type == 'journal' || whole.value.type == 'newspaper') %]
  <fieldset class="rows">
    <legend>Issue Details</legend>
    <ol>
      <li>
        <label for="item_year">Year:</label>
        <input type="text" name="item_year" id="item_year" type="text" value=""/>
      </li>
      <li>
        <label for="item_season">Season:</label>
        <input type="text" name="item_season" id="item_season" type="text" value=""/>
      </li>
      <li>
        <label for="item_month">Month:</label>
        <input type="text" name="item_month" id="item_month" type="text" value=""/>
      </li>
      <li>
        <label for="item_day">Day:</label>
        <input type="text" name="item_day" id="item_day" type="text" value=""/>
      </li>
      <li>
        <label for="item_volume">Volume:</label>
        <input type="text" name="item_volume" id="item_volume" type="text" value=""/>
      </li>
      <li>
        <label for="item_part">Part:</label>
        <input type="text" name="item_part" id="item_part" type="text" value=""/>
      </li>
      <li>
        <label for="item_issue">Issue:</label>
        <input type="text" name="item_issue" id="item_issue" type="text" value=""/>
      </li>
      <li>
        <label for="item_special_issue">Special issue:</label>
        <input type="text" name="item_special_issue" id="item_special_issue" type="text" value=""/>
      </li>
    </ol>
  </fieldset>
  [% END %]
  <fieldset class="rows">
    [% IF whole.value.type == 'book' %]
    <legend>Chapter Details</legend>
    [% ELSIF (whole.value.type == 'journal' || whole.value.type == 'newspaper') %]
    <legend>Article Details</legend>
    [% END %]
    <ol>
      <li>
        [% IF whole.value.type == 'book' %]
        <label for="interest_title">Chapter title:</label>
        [% ELSIF (whole.value.type == 'journal' || whole.value.type == 'newspaper') %]
        <label for="interest_title">Article title:</label>
        [% END %]
         <input type="text" name="interest_title" id="interest_title" type="text" value=""/>
      </li>
      <li>
        [% IF whole.value.type == 'book' %]
        <label for="interest_author">Chapter author:</label>
        [% ELSIF (whole.value.type == 'journal' || whole.value.type == 'newspaper') %]
        <label for="interest_author">Article author:</label>
        [% END %]
        <input type="text" name="interest_author" id="interest_author" type="text" value=""/>
      </li>
      <li>
        <label for="pages">Pages:</label>
        <input type="text" name="pages" id="pages" type="text" value=""/>
      </li>
    </ol>
  </fieldset>
  <fieldset class="action">
    <input type="submit" value="Request"/>
    <a class="cancel" href="/cgi-bin/koha/opac-illrequests.pl">Cancel</a>
  </fieldset>
</form>

[% INCLUDE 'datatables.inc' %]
[% BLOCK backend_jsinclude %]
<script>
    //<![CDATA[
        $("#ill-opac-results").dataTable($.extend(true, {}, dataTablesDefaults, {
            "deferRender": true
        }));
    //]]>
</script>
[% END %]

[% END %]
