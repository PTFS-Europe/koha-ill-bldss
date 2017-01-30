[% rspValue = whole.value %]

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
[% ELSE %]
<p>Unhandled error</p>
[% END %]
[% END %]

[% IF whole.stage == "commit" %]
<p>We have now created your request.</p>

[% ELSIF whole.stage == "init" %]
<!-- Need to finish this form: keywords, etc, all not populated. I dont
     believe this is essential at this point: they will just init to blank.
     Then: return to ill-new.{tt,pl} and continue with other parts of create -->
<h2>Search the British Library</h2>
<p>Alternatively, <a href="[% here _ '?stage=manual&method=create' %]">click here for manual entry</a>.</p>
<form method="POST" action=[% here %]>
  <fieldset class="rows">
    <legend>Search the British Library</legend>
    <input name="stage" id="stage" value="validate" type="hidden"/>
    <input name="method" id="method" value="create" type="hidden"/>
    <ol>
      <li>
        <label class="required" for="query">Keywords:</label>
        <input type="text" name="query" id="query" value="[% whole.value.query %]" />
      </li>
      <li>
        <label for="isbn">ISBN:</label>
        <input type="text" name="isbn" id="isbn" value="[% whole.value.isbn %]" />
      </li>
      <li>
        <label for="issn">ISSN:</label>
        <input type="text" name="issn" id="issn" value="[% whole.value.issn %]" />
      </li>
      <li>
        <label for="title">Title:</label>
        <input type="text" name="title" id="title" value="[% whole.value.title %]" />
      </li>
      <li>
        <label for="author">Author:</label>
        <input type="text" name="author" id="author" value="[% whole.value.author %]" />
      </li>
      <li>
        <label for="type">Type:</label>
        <select name="type" id="type">
            <option value=""/>
            [% FOREACH opt IN [ 'Book' 'Article' 'Journal' ] %]
            [% IF ( whole.value.type == opt ) %]
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
    <legend>Borrower Options</legend>
    <ol>
      <li>
        <label class="required" for="brw">Borrower number or surname:</label>
        <input type="text" name="brw" id="brw" type="text" value="[% whole.value.brw %]" />
      </li>
      <li>
        <label class="required" for="branch">Destination branch:</label>
        <select name="branch" id="branch">
          <option value=""></option>
          [% FOREACH branch IN branches %]
          [% IF ( whole.value.branch == branch.value ) %]
          <option value="[% branch.value %]" selected="selected">
            [% branch.branchname %]
          </option>
          [% ELSE %]
          <option value="[% branch.value %]">[% branch.branchname %]</option>
          [% END %]
          [% END %]
        </select>
      </li>
    </ol>
  </fieldset>
  <fieldset class="action">
    <input type="submit" value="Search"/>
    <a class="cancel" href=[% parent %]>Cancel</a>
  </fieldset>
</form>

[% ELSIF whole.stage == "borrowers" %]
<!-- We need to clarify the borrower that has been requested. -->
<h2>Borrower selection</h2>
<form method="POST" action=[% here %]>
  <fieldset class="rows">
    <legend>Available borrowers for surname [% surname %]</legend>
    [% FOREACH opt IN whole.value %]
    [% IF opt.key == "brw" %]
    <ol>
      <li>
        <label class="required" for="brw">Borrower</label>
        <select name="brw" id="brw">
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
    <a class="cancel" href=[% parent %]>Cancel</a>
  </fieldset>
</form>

[% ELSIF whole.stage == 'search' OR whole.stage == 'search_cont' %]
<h2>Search results</h2>
[% IF whole.value.0 %]
<p class="bg-info">Results of search for: ”[% whole.userstring %]“
  [% url = back _ "?method=create&stage=init" %]
  [% url = url _ "&brw=" _ whole.params.brw %]
  [% url = url _ "&branch=" _ whole.params.branch %]
  [% url = url _ "&query=" _ whole.params.query %]
  [% url = url _ "&issn=" _ whole.params.issn %]
  [% url = url _ "&isbn=" _ whole.params.isbn %]
  [% url = url _ "&title=" _ whole.params.title %]
  [% url = url _ "&author=" _ whole.params.author %]
  [% url = url _ "&type=" _ whole.params.type %]
  <a href="[% url %]" title="Restart search"
     class="btn btn-default btn-sm"
     role="button">Amend your search</a>
</p>
<table>
  <thead>
    <tr>
    [% FOREACH field IN whole.value.0 %]
      <th id=[% field.key %]>[% field.value.0 %]</th>
    [% END %]
    </tr>
  </thead>
  <tbody>
    [% FOREACH record IN whole.value %]
    <tr>
      [% FOREACH field IN record %]
      [% value = field.value.1 %]
      <td>
        [% IF field.key == './uin' %]
        [% url = here _ "?method=create&stage=commit" %]
        [% url = url _ "&borrower=" _ whole.brw %]
        [% url = url _ "&branch=" _ whole.branch %]
        [% url = url _ "&uin=" _ value %]
        <a href=[% url %]>
          Request [% value %]
        </a>
        [% ELSE %]
        [% value %]
        [% END %]
      </td>
      [% END %]
    </tr>
    [% END %]
  </tbody>
</table>
<p>
  [% IF whole.previous %]
  <a class="nav" title="Previous set of results"
     href=[% here _ whole.previous %]>&lsaquo;&lsaquo; Previous</a>
  [% ELSE %]
  <span> &lsaquo;&lsaquo; Previous</span>
  [% END %]
  [% IF whole.next %]
  <a class="nav" title="Next set of results"
     href=[% here _ whole.next %]>Next &rsaquo;&rsaquo;</a>
  [% ELSE %]
  <span>Next &rsaquo;&rsaquo;</span>
  [% END %]
</p>
[% ELSE %]
<p>
  No results were found for: “[% whole.search %]”
  <a href="[% back %]" title="Amend your search"
     class="btn btn-default btn-sm"
     role="button">Amend your search</a>
</p>
[% END %]

[% ELSIF whole.stage == 'manual' %]
<h2>Manually enter request details</h2>
<form method="POST" action=[% here %]>
  <fieldset class="rows">
    <legend>Manually entry fields</legend>
    <input name="method" id="method" value="create" type="hidden"/>
    <input name="stage" id="stage" value="manual_confirm" type="hidden"/>
    <ol>
      [% FOREACH opt IN whole.value %]
      <li>
        <label for="[% opt.key %]">[% opt.value %]</label>
        <input name="[% opt.key %]" id="[% opt.key %]" type="text"/>
      </li>
      [% END %]
      <li>
        <label for="type">Type:</label>
        <select name="type" id="type">
          <option value=""/>
          [% FOREACH opt IN [ 'Book' 'Article' 'Journal' ] %]
          [% IF type == opt %]
          <option value=[% opt %] selected="selected">[% opt %]</option>
          [% ELSE %]
          <option value=[% opt %]>[% opt %]</option>
          [% END %]
          [% END %]
        </select>
      </li>
    </ol>
  </fieldset>
  <fieldset class="rows">
    <legend>Borrower Options</legend>
    <ol>
      <li>
        <label class="required" for="brw">Borrower number or surname:</label>
        <input type="text" name="brw" id="brw" type="text"/>
      </li>
      <li>
        <label class="required" for="branch">Destination branch:</label>
        <select name="branch" id="branch">
          <option value=""></option>
          [% FOREACH branch IN branches %]
          [% IF ( branch.selected ) %]
          <option value="[% branch.value %]"
                  selected="selected">
           [% branch.branchname %]
          </option>
          [% ELSE %]
          <option value="[% branch.value %]">
            [% branch.branchname %]
          </option>
          [% END %]
          [% END %]
        </select>
      </li>
    </ol>
  </fieldset>
  <fieldset class="action">
    <input type="submit" value="Create"/>
    <a class="cancel" href=[% parent %]>Cancel</a>
  </fieldset>
</form>

[% ELSIF whole.stage == 'manual_confirm' %]
<h2>Manually entry confirmation</h2>
<form method="POST" action="[% here %]">
  <fieldset class="rows">
  <legend>Information</legend>
  <ol>
  [% FOREACH opt IN whole.value %]
  [% name = opt.value.0 %]
  [% value = opt.value.1 %]
  [% IF name %]
    <li>
      <label for="[% opt.key %]">[% name %]</label>
      <input name="[% opt.key %]" id="[% opt.key %]" value="[% value %]"
             type="text" readonly="readonly"/>
    </li>
    [% ELSE %]
    <input name="[% opt.key %]" id="[% opt.key %]" value="[% value %]" type="hidden"/>
    [% END %]
    [% END %]
  </ol>
  <fieldset class="action">
    <input name="method" id="method" value="create" type="hidden"/>
    <input name="stage" id="stage" value="commit_manual" type="hidden"/>
    <input type="submit" value="Confirm"/>
    <a class="cancel" href=[% parent %]>Cancel</a>
  </fieldset>
</form>

[% END %]
