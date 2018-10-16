<h2>Edit item details</h2>
<form method="POST" action=[% here %]>
  <fieldset class="rows">
    <input name="backend" id="backend" value="[% whole.backend %]" type="hidden"/>
    <input name="method" id="method" value="edititem" type="hidden"/>
    <input name="stage" id="stage" value="commit" type="hidden"/>
    <input name="illrequest_id" id="illrequest_id" value="[% whole.illrequest_id %]" type="hidden"/>
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
    [% ELSIF whole.value.type == 'article' %]
    <legend>Article Details</legend>
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
    [% ELSIF (whole.value.type == 'article') %]
    <legend>Article Details</legend>
    [% END %]
    <ol>
      <li>
        [% IF whole.value.type == 'book' %]
        <label for="interest_title">Chapter title:</label>
        [% ELSIF (whole.value.type == 'article') %]
        <label for="interest_title">Article title:</label>
        [% END %]
        <input type="text" name="interest_title" id="interest_title" type="text" value="[% whole.value.interest_title %]"/>
        <input type="hidden" name="read_write" value="interest_title"/>
      </li>
      <li>
        [% IF whole.value.type == 'book' %]
        <label for="interest_author">Chapter author:</label>
        [% ELSIF (whole.value.type == 'article') %]
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
    <input type="submit" value="Save"/>
    <a class="cancel" href="?method=illview&illrequest_id=[% whole.illrequest_id %]">Cancel</a>
  </fieldset>
</form>
