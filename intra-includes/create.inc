[% USE Koha %]
[% USE Asset %]
[% USE raw %]
[% SET koha_version = Koha.Version %]
<style>
    #interlibraryloans #search-summary {
        left: 15px;
        max-width: 70%;
    }
</style>

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
<form method="POST" action="[% here %]" id="create_form">
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
          [% FOREACH opt IN [ 'Book' 'Article' 'Journal' 'Newspaper' 'Conference' 'Thesis' 'Score' ] %]
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
        <label class="required" for="cardnumber">Card number, username or surname:</label>
        <input type="text" autocomplete="off" name="cardnumber" id="cardnumber" type="text"
           value="[% whole.value.other.cardnumber %]" />
      </li>
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
    <input id="search_submit" disabled type="submit" value="Search"/>
    <a class="cancel" href="/cgi-bin/koha/ill/ill-requests.pl">Cancel</a>
  </fieldset>
</form>

[% ELSIF whole.stage == "borrowers" %]
<!-- We need to clarify the borrower that has been requested. -->
<h2>Borrower selection</h2>
<form method="POST" action=[% here %]>
  <fieldset class="rows">
    <legend>Available borrowers for surname [% surname %]</legend>
    <input name="stage" id="stage" value="validate" type="hidden"/>
    <input name="method" id="method" value="create" type="hidden"/>
    <input name="backend" id="backend" value="[% whole.value.other.backend %]" type="hidden"/>
    <input name="branchcode" id="branchcode" value="[% whole.value.other.branchcode %]" type="hidden"/>
    <input name="query" id="query" value="[% whole.value.other.query %]" type="hidden"/>
    <input name="isbn" id="isbn" value="[% whole.value.other.isbn %]" type="hidden"/>
    <input name="issn" id="issn" value="[% whole.value.other.issn %]" type="hidden"/>
    <input name="title" id="title" value="[% whole.value.other.title %]" type="hidden"/>
    <input name="author" id="author" value="[% whole.value.other.author %]" type="hidden"/>
    <input name="type" id="type" value="[% whole.value.other.type %]" type="hidden"/>
    [% FOREACH opt IN whole.value %]
    [% IF opt.key == "brw" %]
    <ol>
      <li>
        <label class="required" for="borrowernumber">Borrower</label>
        <select name="cardnumber" id="cardnumber">
          <option value=""></option>
          [% FOREACH brw IN opt.value %]
          <option value="[% brw.cardnumber %]">
            [% brw.firstname %] [% brw.surname %] ([% brw.cardnumber %])
          </option>
          [% END %]
        </select>
      </li>
    </ol>
    [% ELSE %]
    <input name="[% opt.key %]" id="[% opt.key %]" value="[% opt.value %]" type="hidden"/>
    [% END %]
    [% END %]
  </fieldset>
  <fieldset class="action">
    <input type="submit" value="Select"/>
    <a class="cancel" href="/cgi-bin/koha/ill/ill-requests.pl">Cancel</a>
  </fieldset>
</form>

[% ELSIF whole.stage == 'search_results' %]
<h2>Search results</h2>
[% BLOCK search_summary %]
<div id="bldss_search_summary" style="padding:1em 0;display:flex;justify-content:space-between;align-items:center;">
    [% url = back _ "?method=create&amp;stage=init" %]
    [% url = url _ "&amp;backend=" _ whole.backend %]
    [% url = url _ "&amp;cardnumber=" _ whole.cardnumber %]
    [% url = url _ "&amp;brw=" _ whole.borrowernumber %]
    [% url = url _ "&amp;branchcode=" _ whole.branchcode %]
    [% url = url _ "&amp;query=" _ whole.params.other.query %]
    [% url = url _ "&amp;issn=" _ whole.params.other.issn %]
    [% url = url _ "&amp;isbn=" _ whole.params.other.isbn %]
    [% url = url _ "&amp;title=" _ whole.params.other.title %]
    [% url = url _ "&amp;author=" _ whole.params.other.author %]
    [% url = url _ "&amp;type=" _ whole.params.other.type %]
    [% start_matches = whole.userstring.match('start_rec: (\d+)') %]
    [% length_matches = whole.userstring.match('max_results: (\d+)') %]
    [% keywords_matches = whole.userstring.match('\[keywords: (.+?)]') %]
    [% type_matches = whole.userstring.match('\[type: (.+?)]') %]
    <div>
    Showing [% start_matches.0 %] to [% start_matches.0 + length_matches.0 %] of [% whole.records %] for search &quot;[% keywords_matches.0 %]&quot; with type &quot;[% type_matches.0 %]&quot;
    </div>
    <div>
        [% IF whole.previous %]
        <a title="Previous set of results" href=[% here _ whole.previous | url %]>&lsaquo; Previous</a>
        [% ELSE %]
        <span> &lsaquo; Previous</span>
        [% END %]
        [% IF whole.next %]
        <a title="Next set of results" href=[% here _ whole.next | url %]>Next &rsaquo;</a>
        [% ELSE %]
        <span>Next &rsaquo;</span>
        [% END %]
    </div>
    <div>
        <a href="[% url | url %]" title="Restart search" class="btn btn-default btn-sm pull-right" role="button">Amend your search</a>
    </div>
</div>
[% END %]
<div id="bldss_search_results" style="margin-top:1em;border-top:1px solid #bcbcbc;">
    [% IF whole.value.0 %]
    [% INCLUDE search_summary %]
<table class="table table-bordered table-striped">
  <thead>
    <tr>
    [% FOREACH field IN whole.value.0 %]
      [% IF field.value.inSummary %]<th id=[% field.key %]>[% field.value.name %]</th>[% END %]
    [% END %]
    </tr>
  </thead>
  <tbody>
    [% FOREACH record IN whole.value %]
    <tr>
    [% FOREACH field IN record %]
    [% IF field.value.inSummary %]
    [% value = field.value.value || "N/A" %]
      <td>
      [% IF field.key == './uin' %]
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
        [% value %]
      [% END %]
      </td>
    [% END %]
    [% END %]
    </tr>
    [% END %]
  </tbody>
</table>
</div>
[% INCLUDE search_summary %]
[% ELSE %]
<p id="bldss-no-results" role="alert" class="bg-info alert alert-danger">
  <span id="search-summary" class="pull-left">
  No results found for: &quot;[% whole.userstring %]&quot;
  [% url = back _ "?method=create&amp;stage=init" %]
  [% url = url _ "&amp;backend=" _ whole.backend %]
  [% url = url _ "&amp;cardnumber=" _ whole.cardnumber %]
  [% url = url _ "&amp;branchcode=" _ whole.branchcode %]
  [% url = url _ "&amp;query=" _ whole.params.other.query %]
  [% url = url _ "&amp;issn=" _ whole.params.other.issn %]
  [% url = url _ "&amp;isbn=" _ whole.params.other.isbn %]
  [% url = url _ "&amp;title=" _ whole.params.other.title %]
  [% url = url _ "&amp;author=" _ whole.params.other.author %]
  [% url = url _ "&amp;type=" _ whole.params.other.type %]
  </span>
  <a href="[% url | url %]" title="Restart search" class="btn btn-default btn-sm pull-right" role="button">Amend your search</a>
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
        [% whole.value.title %]
        <input type="hidden" name="rtitle" id="rtitle" value="[% whole.value.title %]"/>
      </li>
      [% IF whole.value.type == 'book' %]
      <li>
        <label for="rauthor">Author:</label>
        [% whole.value.author %]
        <input type="hidden" name="rauthor" id="rauthor" value="[% whole.value.author %]"/>
      </li>
      [% END %]
      [% IF whole.value.publisher %]
      <li>
        <label for="rpublisher">Publisher:</label>
        [% whole.value.publisher %]
        <input type="hidden" name="rpublisher" id="rpublisher" value="[% whole.value.publisher %]"/>
      </li>
      [% END %]
      [% IF whole.value.type == 'book' %]
      <li>
        <label for="risbn">ISBN:</label>
        [% whole.value.isbn %]
        <input type="hidden" name="risbn" id="risbn" value="[% whole.value.isbn %]"/>
      </li>
      [% ELSIF (whole.value.type == 'journal' || whole.value.type == 'newspaper') && whole.value.issn  %]
      <li>
        <label for="rissn">ISSN:</label>
        [% whole.value.issn %]
        <input type="hidden" name="rissn" id="rissn" value="[% whole.value.issn %]"/>
      </li>
      [% END %]
      [% IF (whole.value.type == 'book') && whole.value.edition %]
      <li>
        <label for="redition">Edition:</label>
        [% whole.value.edition %]
        <input type="hidden" name="redition" id="redition" value="[% whole.value.edition %]"/>
      </li>
      <li>
        <label for="ryear">Year:</label>
        [% whole.value.year %]
        <input type="hidden" name="ryear" id="ryear" value="[% whole.value.year %]"/>
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
        <input type="text" name="item_year" id="item_year" type="text" value="[% whole.value.item_year %]"/>
        <input type="hidden" name="read_write" value="item_year"/>
      </li>
      <li>
        <label for="item_season">Season:</label>
        <input type="text" name="item_season" id="item_season" type="text" value="[% whole.value.item_season %]"/>
        <input type="hidden" name="read_write" value="item_season"/>
      </li>
      <li>
        <label for="item_month">Month:</label>
        <input type="text" name="item_month" id="item_month" type="text" value="[% whole.value.item_month %]"/>
        <input type="hidden" name="read_write" value="item_month"/>
      </li>
      <li>
        <label for="item_day">Day:</label>
        <input type="text" name="item_day" id="item_day" type="text" value="[% whole.value.item_day %]"/>
        <input type="hidden" name="read_write" value="item_day"/>
      </li>
      <li>
        <label for="item_volume">Volume:</label>
        <input type="text" name="item_volume" id="item_volume" type="text" value="[% whole.value.item_volume %]"/>
        <input type="hidden" name="read_write" value="item_volume"/>
      </li>
      <li>
        <label for="item_part">Part:</label>
        <input type="text" name="item_part" id="item_part" type="text" value="[% whole.value.item_part %]"/>
        <input type="hidden" name="read_write" value="item_part"/>
      </li>
      <li>
        <label for="item_issue">Issue:</label>
        <input type="text" name="item_issue" id="item_issue" type="text" value="[% whole.value.item_issue %]"/>
        <input type="hidden" name="read_write" value="item_issue"/>
      </li>
      <li>
        <label for="item_special_issue">Special issue:</label>
        <input type="text" name="item_special_issue" id="item_special_issue" type="text" value="[% item_special_issue %]"/>
        <input type="hidden" name="read_write" value="item_special_issue"/>
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
        <input type="text" name="interest_title" id="interest_title" type="text" value="[% whole.value.interest_title %]"/>
        <input type="hidden" name="read_write" value="interest_title"/>
      </li>
      <li>
        [% IF whole.value.type == 'book' %]
        <label for="interest_author">Chapter author:</label>
        [% ELSIF (whole.value.type == 'journal' || whole.value.type == 'newspaper') %]
        <label for="interest_author">Article author:</label>
        [% END %]
        <input type="text" name="interest_author" id="interest_author" type="text" value="[% whole.value.interest_author %]"/>
        <input type="hidden" name="read_write" value="interest_author"/>
      </li>
      <li>
        <label for="pages">Pages:</label>
        <input type="text" name="pages" id="pages" type="text" value="[% whole.value.pages %]"/>
        <input type="hidden" name="read_write" value="pages"/>
      </li>
    </ol>
  </fieldset>
  <fieldset class="action">
    <input type="submit" value="Request"/>
    <a class="cancel" href="/cgi-bin/koha/ill/ill-requests.pl">Cancel</a>
  </fieldset>
</form>

[% END %]
[% BLOCK backend_jsinclude %]
<script>
    // Require a username a branch selection
    document.addEventListener('DOMContentLoaded', function(){
        $('#create_form #cardnumber, #create_form #branchcode').change(function() {
            var comp = ['#create_form #cardnumber','#create_form #branchcode'].filter(function(id) {
                return $(id).val().length > 0;
            });
            $('#search_submit').attr('disabled', comp.length < 2);
        });
        /* Maintain patron autocomplete compatibility across versions */
        [% IF koha_version.major <= 22 && koha_version.minor < 11 %]
        $('#create_form #cardnumber').autocomplete({
            source: "/cgi-bin/koha/circ/ysearch.pl",
            minLength: 3,
            select: function( event, ui ) {
                var field = ui.item.cardnumber;
                $('#create_form #cardnumber').val(field)
                return false;
            }
        })
        .data( "ui-autocomplete" )._renderItem = function( ul, item ) {
            return $( "<li></li>" )
            .data( "ui-autocomplete-item", item )
            .append( "<a>" + item.surname + ", " + item.firstname + " (" + item.cardnumber + ") <small>" + item.address + " " + item.city + " " + item.zipcode + " " + item.country + "</small></a>" )
            .appendTo( ul );
        };
        [% ELSE %]
        patron_autocomplete(
          $('#create_form #cardnumber'),
          {
            'on-select-callback': function( event, ui ) {
              $("#create_form #cardnumber").val( ui.item.patron_id );
              return false;
            }
          }
        );
        [% END %]        
    });
    //]]>
</script>
[% END %]
