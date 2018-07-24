package Koha::Illbackends::BLDSS::Base;

# Copyright PTFS Europe 2014, 2018
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Carp;
use File::Basename qw( dirname );

use Koha::Libraries;
use Clone qw( clone );
use Locale::Country;
use XML::LibXML;
use MARC::Record;
use C4::Context;
use C4::Biblio qw( AddBiblio );
use Koha::Illrequest::Config;
use Koha::Illbackends::BLDSS::BLDSS::API;
use Koha::Illbackends::BLDSS::BLDSS::Config;
use Koha::Illbackends::BLDSS::BLDSS::XML;
use Try::Tiny;
use CGI;
use URI::Escape;
use YAML;
use JSON qw( to_json );

# We will be implementing the Abstract interface.
#use base qw(Koha::ILLRequest::Abstract);

## Every backend should have a version
our $VERSION = "00.00.00";

=head1 NAME

Koha::Illbackends::BLDSS::Base - Koha ILL Backend: BLDSS

=head1 SYNOPSIS

=head1 DESCRIPTION

A first stub file to help to split out BLDSS specific logic from the Abstract
ILL Interface.

=head1 API

=head2 Class Methods

=cut

=head3 new

=cut

sub new {
    my ( $class, $params ) = @_;
    my $self = {
        keywords  => [ "name", "accessor", "inSummary", "many" ],
        framework => 'FA'
    };
    bless( $self, $class );
    my $config =
      Koha::Illbackends::BLDSS::BLDSS::Config->new( $params->{config} );
    my $api = Koha::Illbackends::BLDSS::BLDSS::API->new($config);
    $self->{cgi} = new CGI;
    $self->_config($config);
    $self->_api($api);
    $self->_key_map;
    $self->_logger( $params->{logger} ) if ( $params->{logger} );
    $self->{templates} = { 'BLDSS_STATUS_CHECK' => dirname(__FILE__)
          . '/intra-includes/log/bldss_status_check.tt' };
    return $self;
}

=head _key_map

    my $key_map = $bldss->_key_map;

Initialiser for our key_map

=cut

sub _key_map {
    my ($self) = @_;

    # Map item level metadata from form supplied
    # keys to BLDSS metadata keys
    $self->{key_map} = {
        title              => './metadata/titleLevel/title',
        author             => './metadata/titleLevel/author',
        publisher          => './metadata/titleLevel/publisher',
        isbn               => './metadata/titleLevel/isbn',
        issn               => './metadata/titleLevel/issn',
        edition            => './metadata/itemLevel/edition',
        year               => './metadata/itemLevelLevel/year',
        item_year          => './metadata/itemLevel/year',
        item_volume        => './metadata/itemLevel/volume',
        item_issue         => './metadata/itemLevel/issue',
        item_part          => './metadata/itemLevel/part',
        item_edition       => './metadata/itemLevel/edition',
        item_season        => './metadata/itemLevel/season',
        item_month         => './metadata/itemLevel/month',
        item_day           => './metadata/itemLevel/day',
        item_special_issue => './metadata/itemLevel/specialissue',
        interest_title     => './metadata/itemofinterestlevel/title',
        interest_author    => './metadata/itemofinterestlevel/author',
        pages              => './metadata/itemofinterestlevel/pages',
    };

    return $self->{key_map};
}

=head3 _api

    my $api = $bldss->_api($api);
    my $api = $bldss->_api;

Getter/Setter for our API object.

=cut

sub _api {
    my ( $self, $api ) = @_;
    $self->{api} = $api if ($api);
    return $self->{api};
}

=head3 _logger

    my $logger = $bldss->_logger($logger);
    my $logger = $bldss->_logger;

Getter/Setter for our Logger object.

=cut

sub _logger {
    my ( $self, $logger ) = @_;
    $self->{logger} = $logger if ($logger);
    return $self->{logger};
}

=head3 _config

    my $config = $bldss->_config($config);
    my $config = $bldss->_config;

Getter/Setter for our config object.

=cut

sub _config {
    my ( $self, $config ) = @_;
    $self->{config} = $config if ($config);
    return $self->{config};
}

=head3 status_graph

=cut

sub status_graph {
    return {
        EDITITEM => {
            prev_actions   => ['NEW'],
            id             => 'EDITITEM',
            name           => 'Edited item metadata',
            ui_method_name => 'Edit item metadata',
            method         => 'edititem',
            next_actions   => [],
            ui_method_icon => 'fa-edit',
        },
        STAT => {
            prev_actions   => ['REQ'],
            id             => 'STAT',
            name           => 'British Library Status',
            ui_method_name => 'Check British Library status',
            method         => 'status',
            next_actions   => [],
            ui_method_icon => 'fa-search',
        },
        MIG => {
            prev_actions   => [ 'NEW', 'REQREV', 'QUEUED', ],
            id             => 'MIG',
            name           => 'Backend Migration',
            ui_method_name => 'Switch provider',
            method         => 'migrate',
            next_actions   => [],
            ui_method_icon => 'fa-search',
        },
    };
}

sub name {
    return "BLDSS";
}

=head3 capabilities

    $capability = $backend->capabilities($name);

Return the sub implementing a capability selected by NAME, or 0 if that
capability is not implemented.

=cut

sub capabilities {
    my ( $self, $name ) = @_;
    my ($query) = @_;
    my $capabilities = {

        # The unmediated operation is just invoking confirm for BLDSS.
        unmediated_ill => sub { $self->unmediated_confirm(@_); }
    };
    return $capabilities->{$name};
}

=head3 metadata

Return a hashref containing canonical values from the key/value
illrequestattributes store.

In BLDSS we provide the following k/v fields:
- Title
- Author
- UIN
- Year

=cut

sub metadata {
    my ( $self, $request ) = @_;
    my $attrs = $request->illrequestattributes;
    my $return = { UIN => $attrs->find( { type => './uin' } )->value };
    $return->{Title} =
        $attrs->find( { type => './metadata/titleLevel/title' } )
      ? $attrs->find( { type => './metadata/titleLevel/title' } )->value
      : undef;
    $return->{Author} =
        $attrs->find( { type => './metadata/titleLevel/author' } )
      ? $attrs->find( { type => './metadata/titleLevel/author' } )->value
      : undef;
    $return->{Publisher} =
        $attrs->find( { type => './metadata/titleLevel/publisher' } )
      ? $attrs->find( { type => './metadata/titleLevel/publisher' } )->value
      : undef;
    $return->{"Shelf mark"} =
        $attrs->find( { type => './metadata/titleLevel/shelfmark' } )
      ? $attrs->find( { type => './metadata/titleLevel/shelfmark' } )->value
      : undef;
    $return->{Year} =
        $attrs->find( { type => './metadata/itemLevel/year' } )
      ? $attrs->find( { type => './metadata/itemLevel/year' } )->value
      : undef;
    $return->{Issue} =
        $attrs->find( { type => './metadata/itemLevel/issue' } )
      ? $attrs->find( { type => './metadata/itemLevel/issue' } )->value
      : undef;
    $return->{Volume} =
        $attrs->find( { type => './metadata/itemLevel/volume' } )
      ? $attrs->find( { type => './metadata/itemLevel/volume' } )->value
      : undef;
    $return->{"Item part title"} =
        $attrs->find( { type => './metadata/itemOfInterestLevel/title' } )
      ? $attrs->find( { type => './metadata/itemOfInterestLevel/title' } )
      ->value
      : undef;
    $return->{"Item part pages"} =
        $attrs->find( { type => './metadata/itemOfInterestLevel/pages' } )
      ? $attrs->find( { type => './metadata/itemOfInterestLevel/pages' } )
      ->value
      : undef;
    $return->{"Item part author"} =
        $attrs->find( { type => './metadata/itemOfInterestLevel/author' } )
      ? $attrs->find( { type => './metadata/itemOfInterestLevel/author' } )
      ->value
      : undef;

    return $return;
}

#### Standard Method Calls

=head3 confirm

    my $response = $BLDSS->confirm( $record, $status, $params );

Return an ILL standard response for the confirm method call.

For BLDSS, this is a composite method, consisting of 3 stages: availability
lookup, pricing lookup and finally commit.  Constructing the relevant standard
responses is carried out by the helper procedures `availability', `prices' and
`create_order' respectively.

=cut

sub confirm {
    my ( $self, $params ) = @_;
    my $stage = $params->{other}->{stage};
    if ( !$stage || 'availability' eq $stage ) {
        return $self->availability($params);
    }
    elsif ( 'pricing' eq $stage ) {
        return $self->prices($params);
    }
    elsif ( 'commit' eq $stage ) {
        return $self->create_order($params);
    }
    else {
        die "Confirm Unexpected Stage";
    }
}

=head3 unmediated_confirm

    my $response = $BLDSS->unmediated_confirm( $params );

Return an ILL standard response for the confirm method call, in the case of
an unmediated workflow.

In the context of BLDSS this involves reading the default order preferences
from the configuration file, or falling back on the standard ones, and using
that to "create the order".

=cut

sub unmediated_confirm {
    my ( $self, $params ) = @_;

    # Directly invoke return create_order.
    # It contains logic to load request details (speed, quality...) from
    # the configuration file, using getDefaultFormat.
    return $self->create_order($params);
}

=head3 create

    my $response = $BLDSS->create( $params );

Return an ILL standard response for the create method call.

For BLDSS, this is a composite method.

=cut

sub create {
    my ( $self, $params ) = @_;
    my $other = $params->{other};
    my $stage = $other->{stage};

    my $response = {
        backend    => $self->name,
        method     => 'create',
        stage      => $stage,
        branchcode => $other->{branchcode},
        cardnumber => $other->{cardnumber},
        status     => '',
        message    => '',
        error      => 0
    };

    # Check for borrowernumber
    if ( !$other->{borrowernumber} && defined( $other->{cardnumber} ) ) {
        $response->{cardnumber} = $other->{cardnumber};

        # 'cardnumber' here could also be a surname (or in the case of
        # search it will be a borrowernumber).
        my ( $brw_count, $brw ) =
          _validate_borrower( $other->{'cardnumber'}, $stage );
        if ( $brw_count == 0 ) {
            $response->{status} = "invalid_borrower";
            $response->{value}  = $params;
            $response->{error}  = 1;
            return $response;
        }
        elsif ( $brw_count > 1 ) {

            # We must select a specific borrower out of our options.
            $params->{brw}     = $brw;
            $response->{value} = $params;
            $response->{stage} = "borrowers";
            $response->{error} = 0;
            return $response;
        }
        else {
            $other->{borrowernumber} = $brw->borrowernumber;

            #$params->{other}->{borrowernumber} = $brw->borrowernumber;
        }
    }
    $response->{borrowernumber} = $other->{borrowernumber};

    # Initiate process
    if ( !$stage || 'init' eq $stage ) {

        # We just need to request the snippet that builds the Creation
        # interface.
        $response->{stage} = 'init';
        $response->{value} = $params;
        return $response;
    }

    # Validate form and perform search if valid
    elsif ( 'validate' eq $stage ) {

        if ( _fail( $other->{'branchcode'} ) ) {
            $response->{status} = "missing_branch";
            $response->{error}  = 1;
            $response->{stage}  = 'init';
            $response->{value}  = $params;
            return $response;
        }
        elsif ( !Koha::Libraries->find( $other->{'branchcode'} ) ) {
            $response->{status} = "invalid_branch";
            $response->{error}  = 1;
            $response->{stage}  = 'init';
            $response->{value}  = $params;
            return $response;
        }
        else {
            $response->{stage}  = 'search_results';
            $response->{query}  = $other->{query};
            $response->{params} = $params;

            # Perform the search!
            my $results = $self->_search($params);

            # Merge and return
            $response = { %{$response}, %{$results} };
            return $response;
        }
    }

    # Load next results page
    elsif ( 'search_results' eq $stage ) {
        $response->{stage}  = 'search_results';
        $response->{query}  = $other->{query};
        $response->{params} = $params;

        # Continue search!
        my $results = $self->_search($params);

        # Merge and return
        return { %{$response}, %{$results} };
    }

    # Create request from search result
    elsif ( 'commit' eq $stage ) {

        # We should have the data we need for an API derived Record.
        # ...Populate Illrequest
        my $request      = $params->{request};
        my @read_write   = $self->{cgi}->multi_param('read_write');
        my $patron       = Koha::Patrons->find( $other->{borrowernumber} );
        my $bldss_result = $self->_find( $other->{uin} );

        # If this is a 'book' or 'journal' request ask the user if they wish
        # to add further details to turn it into a chapter or issue request.
        if ( $bldss_result->{'./type'}->{value} =~ /book|journal|newspaper/ ) {

            # Augment bldss_result with submitted details
            if ( $other->{complete} ) {
                foreach my $key ( keys %{ $self->{key_map} } ) {
                    my $value = $self->{key_map}->{$key};
                    if (  !length $bldss_result->{$value}->{value}
                        && length $other->{$key} > 0 )
                    {
                        $bldss_result->{$value}->{value} = $other->{$key};
                    }
                }
            }

            # Request more details
            else {
                $response->{stage}  = 'extra_details';
                $response->{params} = $other;
                $response->{value}  = {
                    type => $bldss_result->{'./type'}->{value},

                    # titleLevel
                    title =>
                      $bldss_result->{'./metadata/titleLevel/title'}->{value},
                    author =>
                      $bldss_result->{'./metadata/titleLevel/author'}->{value},
                    publisher =>
                      $bldss_result->{'./metadata/titleLevel/publisher'}
                      ->{value},
                    isbn =>
                      $bldss_result->{'./metadata/titleLevel/isbn'}->{value},
                    issn =>
                      $bldss_result->{'./metadata/titleLevel/issn'}->{value},

                    # itemLevel
                    edition =>
                      $bldss_result->{'./metadata/itemLevel/edition'}->{value},
                    year =>
                      $bldss_result->{'./metadata/itemLevelLevel/year'}->{value}
                };
                return $response;
            }
        }

        my $biblionumber = $self->bldss2biblio($bldss_result);

        $request->biblio_id($biblionumber) unless !$biblionumber;
        $request->borrowernumber( $patron->borrowernumber );
        $request->branchcode( $other->{branchcode} );
        $request->medium( $other->{type} );
        $request->status('NEW');
        $request->backend( $self->name );
        $request->placed( DateTime->now );
        $request->updated( DateTime->now );
        $request->store;

        # Store the request attributes
        $self->create_illrequestattributes( $bldss_result, $request,
            \@read_write );

        # Add original query details to result for storage
        $self->_store_search( $request, $bldss_result, $other );

        # Return
        return {
            status  => "",
            message => "",
            error   => 0,
            value   => {},
            method  => "create",
            stage   => "commit",
            next    => "illview",
        };
    }

    # Catch unexpected stage
    else {
        die "Create Unexpected Stage";
    }
}

=head3 edititem

Edit the read-write illrequest attribute fields for a request

=cut

sub edititem {
    my ( $self, $params ) = @_;

    my $other = $params->{other};
    my $stage = $other->{stage} ? $other->{stage} : 'form';

    my $response = {
        params        => $params,
        backend       => $self->name,
        method        => 'edititem',
        illrequest_id => $other->{illrequest_id},
        stage         => $stage,
        error         => 0,
        status        => '',
        message       => '',
    };

    # Don't allow editing of submitted requests
    $response->{method} = 'illlist' if $params->{request}->status ne 'NEW';

    if ( $stage eq 'form' ) {

        # Map the BLDSS keys into form keys
        my %rev = reverse %{ $self->{key_map} };

        # Attributes for this request
        my $attr = $params->{request}->illrequestattributes->unblessed;

        # Prepare our return
        my $out = {};
        foreach my $meta ( @{$attr} ) {
            if ( $rev{ $meta->{type} } ) {
                $out->{ $rev{ $meta->{type} } } = $meta->{value};
            }
            elsif ( $meta->{type} eq './type' ) {
                $out->{type} = $meta->{value};
            }
        }
        $response->{value} = $out;
        return $response;
    }
    elsif ( $stage eq 'commit' ) {
        my $request    = $params->{request};
        my $passed     = $params->{other};
        my @read_write = $self->{cgi}->multi_param('read_write');

        # Update the writeable fields that we've been passed
        foreach my $attr (@read_write) {
            my $bldss_key = $self->{key_map}->{$attr};
            my $value     = $passed->{$attr};
            if ( $bldss_key && $value ) {
                my $current_attr = Koha::Illrequestattributes->find(
                    {
                        illrequest_id => $request->id,
                        type          => $bldss_key
                    }
                );
                if ($current_attr) {
                    $current_attr->value($value);
                    $current_attr->store;
                }
            }
        }

        $response->{method} = 'illlist';
        return $response;

    }
    else {
        return $response;
    }

}

=head3 migrate

Migrate a request into or out of this backend.

=cut

sub migrate {
    my ( $self, $params ) = @_;
    my $other = $params->{other};

    my $stage = $other->{stage};
    my $step  = $other->{step};

    # Recieve a new request from another backend and suppliment it with
    # anything we require speficifcally for this backend.
    if ( !$stage || $stage eq 'immigrate' ) {

        my $response = {
            backend       => $self->name,
            method        => 'migrate',
            stage         => $stage,
            illrequest_id => $other->{illrequest_id},
            status        => '',
            message       => '',
            error         => 0
        };
        $response->{branchcode} = $other->{branchcode} if $other->{branchcode};
        $response->{borrowernumber} = $other->{borrowernumber}
          if $other->{borrowernumber};

        # Initiate immigration search
        if ( !$step || 'init' eq $step ) {

            # Fetch original request details
            my $original_request =
              Koha::Illrequests->find( $other->{illrequest_id} );

            # Collect parameters
            $response->{step}           = 'search_results';
            $response->{query}          = $other->{query};
            $response->{params}         = $params;
            $response->{borrowernumber} = $original_request->borrowernumber;
            $response->{branchcode}     = $original_request->branchcode;

            # Initiate search with details from last request
            my @recognised_attributes = (qw/isbn issn title author srchany/);
            my $original_attributes =
              $original_request->illrequestattributes->search(
                { type => { '-in' => \@recognised_attributes } } );
            my $search_attributes =
              { map { $_->type => $_->value }
                  ( $original_attributes->as_list ) };
            $params->{other} = { %{ $params->{other} }, %{$search_attributes} };
            if (
                my $query = $original_request->illrequestattributes->find(
                    { type => 'srchany' }
                )
              )
            {
                $params->{other}->{query} = $query->value;
            }

            # Perform a search
            my $results = $self->_search($params);

            # Merge and return
            $response = { %{$response}, %{$results} };
            return $response;
        }

        # Load next results page
        elsif ( 'search_results' eq $step ) {
            $response->{step}   = 'search_results';
            $response->{query}  = $other->{query};
            $response->{params} = $params;

            # Continue search!
            my $results = $self->_search($params);

            # Merge and return
            return { %{$response}, %{$results} };
        }

        # Create request from search results
        elsif ( 'commit' eq $step ) {
            my $request = $params->{request};

            my $bldss_result = $self->_find( $other->{uin} );

            # Merge original request details as required
            my $original_request =
              Koha::Illrequests->find( $other->{illrequest_id} );
            my @interesting_fields =
              (qw/title container_title author edition year pages/);
            my $original_attributes = {
                map { $_->type => $_->value } (
                    $original_request->illrequestattributes->search(
                        { type => { '-in' => \@interesting_fields } }
                    )->as_list
                )
            };
            if ( exists $original_attributes->{'container_title'} ) {

                # itemLevel
                $bldss_result->{'./metadata/itemLevel/year'} //=
                  $original_request->{year}
                  if exists $original_request->{year};
                $bldss_result->{'./metadata/itemLevel/volume'} //=
                  $original_request->{volume}
                  if exists $original_request->{volume};
                $bldss_result->{'./metadata/itemLevel/issue'} //=
                  $original_request->{issue}
                  if exists $original_request->{issue};
                $bldss_result->{'./metadata/itemLevel/edition'} //=
                  $original_request->{edition}
                  if exists $original_request->{edition};

                # itemOfInterestLevel
                $bldss_result->{'./metadata/itemOfInterestLevel/title'} //=
                  $original_attributes->{title}
                  if exists $original_attributes->{title};
                $bldss_result->{'./metadata/itemOfInterestLevel/author'} //=
                  $original_attributes->{author}
                  if exists $original_attributes->{author};
                $bldss_result->{'./metadata/itemOfInterestLevel/pages'} //=
                  $original_attributes->{pages}
                  if exists $original_attributes->{pages};
            }

            # Add temporary bib record
            my $biblionumber = $self->bldss2biblio($bldss_result);

            # Store request
            $request->borrowernumber( $other->{borrowernumber} );
            $request->branchcode( $other->{branchcode} );
            $request->status('NEW');
            $request->backend( $self->name );
            $request->placed( DateTime->now );
            $request->updated( DateTime->now );
            $request->biblio_id($biblionumber);
            $request->store;

            # ...Add original query details to result for storage
            $self->_store_search( $request, $bldss_result, $other );

            # Store the request attributes
            $bldss_result->{migrated_from}->{value} = $other->{illrequest_id};
            $self->create_illrequestattributes( $bldss_result, $request );

            return {
                error   => 0,
                status  => '',
                message => '',
                method  => 'migrate',
                stage   => 'commit',
                next    => 'emigrate',
                value   => $params,
            };
        }

        # Catch unexpected step
        else {
            die "Immigate Unexpected Step";
        }
    }

    # Cleanup any outstanding work and close the request.
    elsif ( $stage eq 'emigrate' ) {
        my $request = $params->{request};

        # Cancel the original request if required
        if ( $request->status eq 'REQ' ) {

            # FIXME: Add Error Handling Here
            $self->_process(
                $self->_api->cancel_order( $params->{request}->orderid ) );
        }

        # Update original request to cancelled
        $request->status("REQREV");
        $request->orderid(undef);
        $request->store;

        return {
            error   => 0,
            status  => '',
            message => '',
            method  => 'migrate',
            stage   => 'commit',
            value   => $params,
        };
    }
}

=head3 cancel

    my $response = $BLDSS->cancel( $record, $status, $params );

Return an ILL standard response for the cancel method call.

=cut

sub cancel {
    my ( $self, $params ) = @_;
    my $response =
      $self->_process(
        $self->_api->cancel_order( $params->{request}->orderid ) );
    if ( $response->{error} ) {
        $response->{method} = 'cancel';
        $response->{stage}  = 'init';
        return $response;
    }
    return { method => 'cancel', stage => 'commit', next => 'illview', };
}

=head3 status

    my $response = $BLDSS->status( $record, $status, $params );

Return an ILL standard response for the status method call.

=cut

sub status {
    my ( $self, $params ) = @_;
    my $stage = $params->{other}->{stage};
    if ( !$stage || $stage eq 'init' ) {
        my $status =
          $self->_process( $self->_api->order( $params->{request}->orderid ) );
        $status->{method} = "status";
        $status->{stage}  = "show_status";

        # Log this check if appropriate
        if ( $self->_logger ) {
            my $logger = $self->_logger;
            $logger->set_data(
                {
                    actionname   => 'BLDSS_STATUS_CHECK',
                    objectnumber => $params->{request}->id,
                    infos        => to_json(
                        {
                            log_origin => $self->name,
                            response =>
                              $status->{value}->result->orderline->overallStatus
                        }
                    )
                }
            );
            $logger->log_something();
        }

        return $status;
    }
    else {
        # Assume stage is commit, we just return.
        return {
            status  => "",
            message => "",
            error   => 0,
            value   => {},
            method  => "status",
            next    => "illview",
            stage   => "commit",
        };
    }
}

=head3 get_log_template_path

    my $path = $BLDSS->get_log_template_path($action);

Given an action, return the path to the template for displaying
that action log

=cut

sub get_log_template_path {
    my ( $self, $action ) = @_;
    return $self->{templates}->{$action};
}

#### Helpers

=head3 bldss2biblio

    my $biblionumber = $BLDSS->bldss2biblio($result);

Create a basic biblio record for the passed BLDSS API result

=cut

sub bldss2biblio {
    my ( $self, $result ) = @_;

    # We only want to create biblios for books
    return 0 unless $result->{'./type'}->{value} eq 'book';

    # We're going to try and populate author, title & ISBN
    my $author = $result->{'./metadata/titleLevel/author'}->{value};
    my $title  = $result->{'./metadata/titleLevel/title'}->{value};
    my $isbn   = $result->{'./metadata/titleLevel/isbn'}->{value};

    # Create the MARC::Record object and populate
    my $record = MARC::Record->new();
    if ($isbn) {
        my @isbns = split /|/, $isbn;
        for my $each (@isbns) {
            my $marc_isbn = MARC::Field->new( '020', '', '', a => $each );
            $record->append_fields($marc_isbn);
        }
    }
    if ($author) {
        my $marc_author = MARC::Field->new( '100', '1', '', a => $author );
        $record->append_fields($marc_author);
    }
    if ($title) {
        my $marc_title = MARC::Field->new( '245', '0', '0', a => $title );
        $record->append_fields($marc_title);
    }

    # Suppress the record
    $self->_set_suppression($record);

    # We hardcode a framework name of 'ILL', which will need to exist
    # All this stuff should be configurable
    my $biblionumber = AddBiblio( $record, $self->{framework} );

    return $biblionumber;
}

=head3 _set_suppression

    $BLDSS->_set_suppression($record);

Take a MARC::Record object and set it to be suppressed

=cut

sub _set_suppression {
    my ( $self, $record ) = @_;

    my $new942 = MARC::Field->new( '942', '', '', n => '1' );
    $record->append_fields($new942);

    return 1;
}

=head3 _store_search

  $self->_store_search($request, $result, $params);

Given the request object, result and params hashrefs, collate and store the 
share search attributes for possible migrations.

=cut

sub _store_search {
    my ( $self, $request, $result, $params ) = @_;

    # Standard Fields
    # * type [book, journal, article]
    # * ISBN
    # * ISSN
    # * title
    # * author
    # * editor
    # * publisher
    # * year
    # * edition
    # * issue
    # * volume

    # * pages
    # * container_title

    my $search_attributes = {};

    # book
    if ( $result->{'./type'}->{value} eq 'book' ) {
        $search_attributes->{type} = 'book';
        my $isbns = $result->{'./metadata/titleLevel/isbn'}->{value};
        if ($isbns) {
            $search_attributes->{isbn} = $isbns;
            $search_attributes->{isbn} =~ s/\|/,/g;
        }
        $search_attributes->{title} =
          $result->{'./metadata/titleLevel/title'}->{value};
        $search_attributes->{author} =
          $result->{'./metadata/titleLevel/author'}->{value};
        $search_attributes->{publisher} =
          $result->{'./metadata/titleLevel/publisher'}->{value};
        $search_attributes->{year} =
          $result->{'./metadata/itemLevel/year'}->{value};
        $search_attributes->{edition} =
          $result->{'./metadata/itemLevel/edition'}->{value};
        $search_attributes->{volume} =
          $result->{'./metadata/itemLevel/volume'}->{value};
    }

    # journal
    elsif ( $result->{'./type'}->{value} eq 'journal' ) {
        $search_attributes->{type} = 'journal';
        $search_attributes->{issn} =
          $result->{'./metadata/titleLevel/issn'}->{value};
        $search_attributes->{title} =
          $result->{'./metadata/titleLevel/title'}->{value};
        $search_attributes->{author} =
          $result->{'./metadata/titleLevel/author'}->{value};
        $search_attributes->{publisher} =
          $result->{'./metadata/titleLevel/publisher'}->{value};
    }

    # article
    elsif ( $result->{'./type'}->{value} eq 'article' ) {
        $search_attributes->{type} = 'article';
        $search_attributes->{issn} =
          $result->{'./metadata/titleLevel/issn'}->{value};
        $search_attributes->{title} =
          $result->{'./metadata/itemOfInterestLevel/title'}->{value};
        $search_attributes->{author} =
          $result->{'./metadata/itemOfInterestLevel/author'}->{value};
        $search_attributes->{publisher} =
          $result->{'./metadata/titleLevel/publisher'}->{value};
        $search_attributes->{year} =
          $result->{'./metadata/itemLevel/year'}->{value};
        $search_attributes->{issue} =
          $result->{'./metadata/itemLevel/issue'}->{value};
        $search_attributes->{pages} =
          $result->{'./metadata/itemOfInterestLevel/pages'}->{value};
        $search_attributes->{container_title} =
          $result->{'./metadata/titleLevel/title'}->{value};
    }

    # newspaper
    elsif ( $result->{'./type'}->{value} eq 'newspaper' ) {
        $search_attributes->{type} = 'newspaper';
        $search_attributes->{issn} =
          $result->{'./metadata/titleLevel/issn'}->{value};
        $search_attributes->{title} =
          $result->{'./metadata/titleLevel/title'}->{value};
        $search_attributes->{author} =
          $result->{'./metadata/titleLevel/author'}->{value};
        $search_attributes->{publisher} =
          $result->{'./metadata/titleLevel/publisher'}->{value};
    }

    # conference
    elsif ( $result->{'./type'}->{value} eq 'conference' ) {
        $search_attributes->{type} = 'conference';
        $search_attributes->{title} =
          $result->{'./metadata/titleLevel/title'}->{value};
    }

    # thesis
    elsif ( $result->{'./type'}->{value} eq 'thesis' ) {
        $search_attributes->{type} = 'thesis';
        $search_attributes->{title} =
          $result->{'./metadata/titleLevel/thesisDissertation'}->{value};
    }

    # score
    elsif ( $result->{'./type'}->{value} eq 'score' ) {
        $search_attributes->{type} = 'score';
        $search_attributes->{ismn} =
          $result->{'./metadata/titleLevel/ismn'}->{value};
        $search_attributes->{title} =
          $result->{'./metadata/titleLevel/title'}->{value};
        $search_attributes->{author} =
          $result->{'./metadata/titleLevel/author'}->{value};
        $search_attributes->{publisher} =
          $result->{'./metadata/titleLevel/publisher'}->{value};
    }

    # ...Fallback to original query details for any undefined fields
    my @interesting = (qw/issn isbn title author/);
    for my $interesting (@interesting) {
        $search_attributes->{$interesting} //= $params->{$interesting}
          if $params->{$interesting};
    }
    $search_attributes->{'srchany'} = $params->{query}
      if defined( $params->{query} );

    # Store the request attributes
    $self->create_illrequestattributes( $search_attributes, $request );

    return 1;
}

sub create_illrequestattributes {
    my ( $self, $attr, $request, $read_write ) = @_;

    # Populate Illrequestattributes
    while ( my ( $type, $value ) = each %{$attr} ) {

        # $value may be a string or a hashref
        my $resolved_value;
        if (   ref $value eq 'HASH'
            && $value->{value}
            && length $value->{value} > 0 )
        {
            $resolved_value = $value->{value};
        }
        elsif ( !ref $value && length $value > 0 ) {
            $resolved_value = $value;
        }

        my $data = {
            illrequest_id => $request->illrequest_id,
            type          => $type,
            value         => $resolved_value
        };

        # We may need this attribute to be read-write
        if ($read_write) {
            if ( $data->{value} && grep { $self->{key_map}->{$_} eq $type }
                @{$read_write} )
            {
                $data->{readonly} = 0;
            }
        }

        # Sometimes we attempt to store the same illrequestattribute
        # twice.  We simply ignore when that happens.
        if ( $data->{value} ) {
            try {
                Koha::Illrequestattribute->new($data)->store;
            };
        }
    }
    return 1;
}

sub validate_delivery_input {
    my ( $self, $params ) = @_;
    my ( $fmt, $brw, $brn, $recipient ) = (
        $params->{service}->{format},
        $params->{borrower}, $params->{branch}, $params->{digital_recipient},
    );

    # The /formats API route gives no indication of whether a given format
    # is electronic or physical, so the best we can do is maintain a
    # mapping table here
    my $formats = {
        1 => "digital",
        2 => "digital",
        3 => "digital",
        4 => "physical",
        5 => "physical",
        6 => "physical",
    };

    # Seed return values.
    my $stat_obj = { error => 0, message => "" };
    my ( $status, $delivery ) = ( $stat_obj, {} );

    if ( 'digital' eq $formats->{$fmt} ) {
        my $target = $brw->email || "";
        if ( 'branch' eq $recipient ) {
            if ( $brn->{branchreplyto} ) {
                $target = $brn->branchreplyto;
            }
            else {
                $target = $brn->branchemail;
            }
        }
        if ( !$target ) {
            $status->{error} = 1;
            $status->{message} =
              "Digital delivery: invalid $recipient " . "type email address.";
        }
        else {
            $delivery->{email} = $target;
        }
    }
    elsif ( 'physical' eq $formats->{$fmt} ) {

        # Country
        $delivery->{Address}->{Country} =
          country2code( $brn->branchcountry, LOCALE_CODE_ALPHA_3 )
          || die "Invalid country in branch record: $brn->branchcountry.";

        # Mandatory Fields
        my $mandatory_fields = {
            AddressLine1  => "branchaddress1",
            TownOrCity    => "branchcity",
            PostOrZipCode => "branchzip",
        };
        my @missing_fields = ();
        while ( my ( $bl_field, $k_field ) = each %{$mandatory_fields} ) {
            if ( !$brn->$k_field ) {
                push @missing_fields, $k_field;
            }
            else {
                $delivery->{Address}->{$bl_field} = $brn->$k_field;
            }
        }
        if (@missing_fields) {
            $status->{error} = 1;
            $status->{message} =
                "Physical delivery requested, "
              . "but branch missing "
              . join( ", ", @missing_fields );
        }
        else {
            # Optional Fields
            my $optional_fields = {
                AddressLine2  => "branchaddress2",
                AddressLine3  => "branchaddress3",
                CountyOrState => "branchstate",
            };
            while ( my ( $bl_field, $k_field ) = each %{$optional_fields} ) {
                $delivery->{Address}->{$bl_field} = $brn->$k_field || "";
            }
        }
    }
    else {
        $status->{error}   = 1;
        $status->{message} = "Unknown service type: $fmt.";
    }

    return ( $status, $delivery );
}

=head3 _fail

=cut

sub _fail {
    my @values = @_;
    foreach my $val (@values) {
        return 1 if ( !$val or $val eq '' );
    }
    return 0;
}

=head3 _validate_borrower

=cut

sub _validate_borrower {

    # Perform cardnumber search.  If no results, perform surname search.
    # Return ( 0, undef ), ( 1, $brw ) or ( n, $brws )
    my ( $input, $action ) = @_;
    my $patrons = Koha::Patrons->new;
    my ( $count, $brw );
    my $query = { cardnumber => $input };
    $query = { borrowernumber => $input } if ( $action eq 'search_results' );

    my $brws = $patrons->search($query);
    $count = $brws->count;
    my @criteria = qw/ surname userid firstname end /;
    while ( $count == 0 ) {
        my $criterium = shift @criteria;
        return ( 0, undef ) if ( "end" eq $criterium );
        $brws = $patrons->search( { $criterium => $input } );
        $count = $brws->count;
    }
    if ( $count == 1 ) {
        $brw = $brws->next;
    }
    else {
        $brw = $brws;    # found multiple results
    }
    return ( $count, $brw );
}

=head3 _process

    my $statusMessage = $self->_process($rawAPIResponse);

Return a BLDSS status message for further processing or die.

_process is a helper procedure taking a raw BLDSS API response and performing
some preliminary parsing of it.

BLDSS status messages are compatible with ILL Module's standard response
format: sometimes (on error) they are returned directly, sometimes they are
augmented by further values.

=cut

sub _process {
    my ( $self, $response ) = @_;

    die(
        "The API responded with an error: ",
        $self->_api->error->{status},
        "\nDetail: ", $self->_api->error->{content}
    ) if ( $self->_api->error );

    my $re = Koha::Illbackends::BLDSS::BLDSS::XML->new->load_xml(
        { string => $response } );

    my $status  = $re->status;
    my $message = $re->message;
    $response = $re;
    my $code = "This unusual case has not yet been defined: $message ($status)";
    my $error = 0;

    if ( 0 == $status ) {
        if ( 'Order successfully cancelled' eq $message ) {
            $code = 'cancel_success';
        }
        elsif ( 'Order successfully submitted' eq $message ) {
            $code = 'request_success';
        }
        elsif ( '' eq $message ) {
            $code = 'status_success';
        }

    }
    elsif ( 1 == $status ) {
        if (
'Invalid Request: A valid physical address is required for the delivery format specified'
            eq $message )
        {
            $code  = 'branch_address_incomplete';
            $error = 1;
        }
        else {
            $code  = 'invalid_request';
            $error = 1;
        }

    }
    elsif ( 5 == $status ) {
        $code  = 'request_fail';
        $error = 1;
    }
    elsif ( 111 == $status ) {
        $code  = 'unavailable';
        $error = 1;

    }
    elsif ( 162 == $status ) {
        $code  = 'cancel_fail';
        $error = 1;
    }
    elsif ( 170 == $status ) {
        $code  = 'search_fail';
        $error = 1;
    }
    elsif ( 701 == $status ) {
        $code  = 'request_fail';
        $error = 1;
    }

    return {
        status  => $code,
        message => $message,
        error   => $error,
        value   => $response,
    };
}

sub availability {
    my ( $self, $params ) = @_;

    my $response = { method => "confirm", stage => "availability" };

    my $request = $params->{request};
    my $uin =
      $request->illrequestattributes->find( { type => './uin' } )->value;
    my @interesting_fields = (
        "./metadata/itemLevel/year",    "./metadata/itemLevel/volume",
        "./metadata/itemLevel/part",    "./metadata/itemLevel/issue",
        "./metadata/itemLevel/edition", "./metadata/itemLevel/season",
        "./metadata/itemLevel/month",   "./metadata/itemLevel/day",
        "./metadata/itemLevel/specialIssue"
    );
    my $fieldResults = $request->illrequestattributes->search(
        { type => { '-in' => \@interesting_fields } } );
    my $opt = {
        map {
            my $key = $_->type;
            $key =~ s/\.\/metadata\/itemLevel\///g;
            ( $key => $_->value )
        } ( $fieldResults->as_list )
    };

    my $result = $self->_process( $self->_api->availability( $uin, $opt ) );
    $response = { %{$response}, %{$result} };
    return $response if ( $response->{error} );

    my $availability = $response->{value}->result->availability;

    # Formats
    # 1 = Encrypted Download, 2 = Unencrypted download,
    # 3 = Secure File Transfer, 4 = Paper, 5 = CD/DVD,
    # 6 = Loan
    my @formats;
    my $isTitle = $self->_isTitleLevel($request);
    foreach my $format ( @{ $availability->formats } ) {
        if (   ( !$isTitle && ( $format->deliveryFormat->key <= 5 ) )
            || ( $isTitle && ( $format->deliveryFormat->key == 6 ) ) )
        {

            my @speeds;
            foreach my $speed ( @{ $format->speeds } ) {
                push @speeds,
                  {
                    speed => [ "Speed", $speed->textContent ],
                    key   => [ "Key",   $speed->key ],
                  };
            }
            my @qualities;
            foreach my $quality ( @{ $format->qualities } ) {
                push @qualities,
                  {
                    quality => [ "Quality", $quality->textContent ],
                    key     => [ "Key",     $quality->key ],
                  };
            }

            push @formats,
              {
                format => [ "Format", $format->deliveryFormat->textContent ],
                key    => [ "Key",    $format->deliveryFormat->key ],
                speeds => [ "Speeds", \@speeds ],
                qualities => [ "Qualities", \@qualities ],
              };
        }
    }

    $response->{value} = {
        copyrightFee => [ "Copyright fee", $availability->copyrightFee ],
        availableImmediately =>
          [ "Available immediately?", $availability->availableImmediately ],
        formats       => [ "Formats", \@formats ],
        illrequest_id => $params->{request}->illrequest_id,
    };
    $response->{future} = "pricing";
    return $response;
}

sub _isTitleLevel {
    my ( $self, $request ) = @_;

    my $typeResult =
      $request->illrequestattributes->find( { type => './type' } );
    return 0 if ( $typeResult->value eq 'article' );

    my @itemOfInterest_fields = (
        "./metadata/itemOfInterestLevel/title",
        "./metadata/itemOfInterestLevel/pages",
        "./metadata/itemOfInterestLevel/author"
    );
    my $searchResults = $request->illrequestattributes->search(
        { type => { '-in' => \@itemOfInterest_fields } } );
    my $isTitle = $searchResults->count ? 0 : 1;

    return $isTitle;
}

sub create_order {
    my ( $self, $params ) = @_;

    my $request   = $params->{request};
    my $brw       = Koha::Patrons->find( $request->borrowernumber );
    my $branch    = Koha::Libraries->find( $request->branchcode );
    my $brw_cat   = $brw->categorycode;
    my $final_out = {
        error   => 0,
        status  => '',
        message => '',
        method  => 'confirm',
        stage   => 'commit',
        next    => 'illview',
        value   => {}
    };
    my $service;
    if ( $params->{other}->{speed} ) {
        $service = {
            speed   => $params->{other}->{speed},
            quality => $params->{other}->{quality},
            format  => $params->{other}->{format},
        };
    }
    else {
        $service = $self->getDefaultFormat(
            {
                brw_cat => $brw_cat,
                branch  => $branch->branchcode,
            }
        );
    }
    my ( $status, $delivery ) = $self->validate_delivery_input(
        {
            service           => $service,
            borrower          => $brw,
            branch            => $branch,
            digital_recipient => $self->getDigitalRecipient(
                {
                    brw_cat => $brw->categorycode,
                    branch  => $branch,
                }
            ),
        }
    );

    if ( $status->{error} ) {
        return {
            error   => 1,
            method  => 'create',
            message => $status->{message}
        };
    }

    my $is_available =
      $self->validate_available( { request => $request, details => $service } );

    if ( !$is_available ) {
        return {
            error   => 1,
            method  => 'create',
            message => "Selected item is not available in the specified format"
        };
    }

    my $metadata           = $self->metadata( $params->{request} );
    my @interesting_fields = (
        "./metadata/itemLevel/year",    "./metadata/itemLevel/volume",
        "./metadata/itemLevel/part",    "./metadata/itemLevel/issue",
        "./metadata/itemLevel/edition", "./metadata/itemLevel/season",
        "./metadata/itemLevel/month",   "./metadata/itemLevel/day",
        "./metadata/itemLevel/specialIssue"
    );
    my $fieldResults = $request->illrequestattributes->search(
        { type => { '-in' => \@interesting_fields } } );
    my $itemLevel = {
        map {
            my $key = $_->type;
            $key =~ s/\.\/metadata\/itemLevel\///g;
            ( $key => $_->value )
        } ( $fieldResults->as_list )
    };

    my $final_details = {
        type => "S",
        Item => {
            uin => $metadata->{UIN},

            # Item level detail can be sent to aid in identifying the specific
            # issue or volume an itemOfInterest should be selected.
            itemLevel => $itemLevel,

            # Item of interest level detail is required if the request is not
            # a phyical item loan.
            itemOfInterestLevel => {
                title  => $metadata->{'Item Title'},
                pages  => $metadata->{'Item Pages'},
                author => $metadata->{'Item Author'},
            }
        },
        service  => $service,
        Delivery => $delivery,

        # Optional params:
        requestor         => join( " ", $brw->firstname, $brw->surname ),
        customerReference => $request->id_prefix . '-' . $request->illrequest_id,
        payCopyright      => $self->getPayCopyright($branch),
    };

    my $response = $self->_process( $self->_api->create_order($final_details) );
    if ( $response->{error} ) {
        return {
            error   => 1,
            method  => 'create',
            message => $response->{message}
        };
    }

    $request->orderid( $response->{value}->result->newOrder->orderline );
    $request->cost( $response->{value}->result->newOrder->totalCost );
    $request->accessurl( $response->{value}->result->newOrder->downloadUrl );
    $request->status("REQ");
    $request->store;

    $final_out->{value} = { status => "On order", cost => $request->cost, };
    return $final_out;
}

sub validate_available {
    my ( $self, $params ) = @_;

    my $speed_avail   = 0;
    my $quality_avail = 0;

    my $request = $params->{request};
    my $uin =
      $request->illrequestattributes->find( { type => './uin' } )->value;
    my @interesting_fields = (
        "./metadata/itemLevel/year",    "./metadata/itemLevel/volume",
        "./metadata/itemLevel/part",    "./metadata/itemLevel/issue",
        "./metadata/itemLevel/edition", "./metadata/itemLevel/season",
        "./metadata/itemLevel/month",   "./metadata/itemLevel/day",
        "./metadata/itemLevel/specialIssue"
    );
    my $fieldResults = $request->illrequestattributes->search(
        { type => { '-in' => \@interesting_fields } } );
    my $opt = {
        map {
            my $key = $_->type;
            $key =~ s/\.\/metadata\/itemLevel\///g;
            ( $key => $_->value )
        } ( $fieldResults->as_list )
    };

    my $response = $self->_process( $self->_api->availability( $uin, $opt ) );
    return 0 if ( $response->{error} );

    my $availability = $response->{value}->result->availability;

    foreach my $format ( @{ $availability->formats } ) {
        foreach my $speed ( @{ $format->speeds } ) {
            if (   $speed_avail == 0
                && $speed->key eq $params->{details}->{speed} )
            {
                $speed_avail = 1;
            }
        }
        foreach my $quality ( @{ $format->qualities } ) {
            if (   $quality_avail == 0
                && $quality->key eq $params->{details}->{quality} )
            {
                $quality_avail = 1;
            }
        }
    }

    return $speed_avail && $quality_avail;
}

sub prices {
    my ( $self, $params ) = @_;
    my $format  = $params->{other}->{'format'};
    my $speed   = $params->{other}->{'speed'};
    my $quality = $params->{other}->{'quality'};
    my $coordinates =
      { format => $format, speed => $speed, quality => $quality, };
    my $response = $self->_process( $self->_api->prices );
    return $response if ( $response->{error} );
    my $result   = $response->{value}->result;
    my $price    = 0;
    my $service  = 0;
    my $services = $result->services;

    foreach ( @{$services} ) {
        my $frmt = $_->get_format($format);
        if ($frmt) {
            $price = $frmt->get_price( $speed, $quality );
            $service = $_;
            last;
        }
    }
    $response->{value} = {
        currency        => [ "Currency",          $result->currency ],
        region          => [ "Region",            $result->region ],
        copyrightVat    => [ "Copyright VAT",     $result->copyrightVat ],
        loanRenewalCost => [ "Loan Renewal Cost", $result->loanRenewalCost ],
        price           => [ "Price",             $price->textContent ],
        service         => [ "Service",           $service->{id} ],
        coordinates     => $coordinates,
        illrequest_id   => $params->{request}->illrequest_id
    };
    $response->{method} = "confirm";
    $response->{stage}  = "pricing";
    $response->{future} = "commit";
    return $response;
}

sub _find {
    my ( $self, $uin ) = @_;
    my $response = $self->_process( $self->_api->search($uin) );
    return $response if ( $response->{error} );
    $response = $self->_parseResponse( @{ $response->{value}->result->records },
        $self->getSpec, {} );
    return $response;
}

=head3 _search

    my $results = $bldss->search($params);

Given a hashref of search parameters, return an array of matching record
objects.

The accepted hash keys are:

=over 2

=item start_rec

The index of the first record to return from the result set. Defaults to 1

=item max_results

The maximum number of results to return (limited to a maximum of 100). Defaults
to 10

=item issn

A query to be applied to the ISSN index. Use this to search by ISSN.

=item isbn

A query to be applied to the ISBN index. Use this to search by ISBN.

=item title

A query to be applied to the Title index. Use this to specify a query should
be the title of a record.

=item author

A query to be applied to the Author index. Use this to specify a query should
be the author/creator of a record.

=item type

A query to be applied to the record Type index. Use this to specify the record
type to return (valid types are those returned as the type value e.g. journal,
book and article).

=item general

A query to be applied to the General index. Use this to specify data such as
shelfmark or volume/issue/part information.

=back

=cut

sub _search {
    my ( $self, $params ) = @_;
    my $other = $params->{other};

    # Collect parameters
    my $opts = { map { $_ => $other->{$_} }
          qw/ author isbn issn title type max_results start_rec / };
    $opts->{max_results} = 10 unless $opts->{max_results};
    $opts->{start_rec}   = 1  unless $opts->{start_rec};

    # Perform search
    my $response =
      $self->_process( $self->_api->search( $other->{query}, $opts ) );

    # Catch errors
    if ( $response->{error} && $response->{status} eq 'search_fail' ) {

        # Ignore 'search_fail' result: empty resultset
        $response->{error} = 0;
    }
    elsif ( $response->{error} ) {

        # Return on other errors
        return $response;
    }

    # Construct response
    my @return;
    my $spec = $self->getSpec;
    $response->{records} = $response->{value}->result->numberOfRecords;
    foreach my $datum ( @{ $response->{value}->result->records } ) {
        my $record = $self->_parseResponse( $datum, $spec, {} );
        push( @return, $record );
    }
    $response->{value} = \@return;

    # Build user search string & paging query string
    my $nav_qry =
        "?backend="
      . $self->name
      . "&method=$other->{method}"
      . "&stage=$other->{stage}"
      . "&borrowernumber=$other->{borrowernumber}"
      . "&cardnumber=$other->{cardnumber}"
      . "&branchcode=$other->{branchcode}";

    $nav_qry .= "&step=$other->{step}" if $other->{step};
    $nav_qry .= "&query=" . uri_escape( $other->{query} );

    my $userstring = "[keywords: " . $other->{query} . "]";
    while ( my ( $type, $value ) = each %{$opts} ) {
        $userstring .= "[" . join( ": ", $type, $value ) . "]";
        $nav_qry    .= "&" . join( "=",  $type, $value )
          unless ( 'start_rec' eq $type );
    }
    $response->{userstring} = $userstring;

    my $result_count = @return;
    my $current_pos  = $opts->{start_rec};
    my $next_pos     = $current_pos + $result_count;
    my $next =
      ( $result_count == $opts->{max_results} )
      ? $nav_qry . "&start_rec=" . $next_pos
      : undef;
    my $prev_pos = $current_pos - $result_count;
    my $previous =
      ( $prev_pos >= 1 ) ? $nav_qry . "&start_rec=" . $prev_pos : undef;
    $response->{next}     = $next;
    $response->{previous} = $previous;

    # Return search results
    return $response;
}

sub _parseResponse {
    my ( $self, $chunk, $config, $accum ) = @_;
    $accum = {} if ( !$accum );    # initiate $accum if empty.
    foreach my $field ( keys %{$config} ) {
        if ( ref $config->{$field} eq 'ARRAY' ) {
            foreach my $node ( $chunk->findnodes($field) ) {
                $accum->{$field} = [] if ( !$accum->{$field} );
                push @{ $accum->{$field} },
                  $self->_parseResponse( $node, ${ $config->{$field} }[0], {} );
            }
        }
        else {
            my ( $op, $arg ) = ( "findvalue", $field );
            ( $op, $arg ) = ( "textContent", "" ) if ( $field eq "./" );
            $accum->{$field} = {
                value     => $chunk->$op($arg),
                name      => $config->{$field}->{name},
                inSummary => $config->{$field}->{inSummary},
            };
        }
    }
    return $accum;
}

=head3 getDigitalRecipient

    my $getDigitalRecipient = $abstract->getDigitalRecipient( {
        brw_cat => $brw_cat,
        branch  => $branch_code,
    } );

Return the digital_recipient setting that should take effect, defaulting to
'borrower' if none is available, else using 'brw_cat' || 'branch' ||
'default'.

=cut

sub getDigitalRecipient {
    my ( $self, $params ) = @_;
    my $brn_dig_recs = $self->_config->getDigitalRecipients('branch');
    my $brw_dig_recs = $self->_config->getDigitalRecipients('brw_cat');
    my $brw_dig_rec  = $brw_dig_recs->{ $params->{brw_cat} } || '';
    my $brn_dig_rec  = $brn_dig_recs->{ $params->{branchcode} } || '';
    my $def_dig_rec  = $brw_dig_recs->{default} || '';

    my $dig_rec = "borrower";
    if ( 'borrower' eq $brw_dig_rec || 'branch' eq $brw_dig_rec ) {
        $dig_rec = $brw_dig_rec;
    }
    elsif ( 'borrower' eq $brn_dig_rec || 'branch' eq $brn_dig_rec ) {
        $dig_rec = $brn_dig_rec;
    }
    elsif ( 'borrower' eq $def_dig_rec || 'branch' eq $def_dig_rec ) {
        $dig_rec = $def_dig_rec;
    }

    return $dig_rec;
}

=head3 getPayCopyright

    my $payCopyright = $illRequest->getPayCopyright($branch);

Return true if we don't have library privilege by default or for this specific
branch.

=cut

sub getPayCopyright {
    my ( $self, $branch ) = @_;
    my $libraryPrivileges = $self->_config->getLibraryPrivileges;
    my $privilege =
      $libraryPrivileges->{$branch} || $libraryPrivileges->{default} || 0;
    return 'false' if $privilege;
    return 'true';
}

=head3 getDefaultFormat

    my $format = $bldss->getDefaultFormat( {
        brw_cat => $brw_cat,
        branch  => $branch_code,
    } );

Return the ILL default format that we should use in case of non-interactive
use.  We will return borrower category definitions with a higher priority than
branch level definitions.  Default is fall-back.

This procedure just dies if it cannot find a sane values, as we assume the
caller requires configured defaults.

=cut

sub getDefaultFormat {
    my ( $self, $params ) = @_;
    my $brn_formats = $self->_config->getDefaultFormats('branch');
    my $brw_formats = $self->_config->getDefaultFormats('brw_cat');

    return
         $brw_formats->{brw_cat}->{ $params->{brw_cat} }
      || $brn_formats->{branch}->{ $params->{branch} }
      || $brw_formats->{default}
      || die "No default format found.  Please define one in koha-conf.xml.";
}

sub getSpec {
    my ($self) = @_;
    my $spec = YAML::Load( $self->_config->getApiSpec );
    return $self->_deriveProperties( { source => $spec->{record} } );
}

###### YAML Spec Processing! ######

=head3 _deriveProperties

    my $_derivedProperties = $illRequest->_deriveProperties($params);

$PARAMS is a hashref containing:
- source: the source datastructure from which we derive our properties.
- prefix [optional]: a prefix string we prepend to each property we derive.

Translate source, which is usually a structure declared in the YAML spec, into
an in memory structure suitable for use by the ILL module.

_deriveProperties can be recursively called from it's helper _recurse.

=cut

sub _deriveProperties {
    my ( $self, $params ) = @_;
    my $source         = $params->{source};
    my $prefix         = $params->{prefix} || "";
    my $modifiedSource = clone($source);
    delete $modifiedSource->{many};
    my $accum = $self->_recurse(
        {
            accum => {},
            tmpl  => $modifiedSource,
            kwrds => $self->{keywords},
        }
    );
    if ($prefix) {
        my $paccum = {};
        while ( my ( $k, $v ) = each %{$accum} ) {
            $paccum->{ $prefix . $k } = $v;
        }
        $accum = $paccum;
    }
    return $accum;
}

=head3 _recurse

    my $accum = $self->_recurse($params, @prefix);

$PARAMS is a hashref containing:
- accum: the work-in-progress accumulated result of our recursive process.
- tmpl: the source off of which we are building accum.
- kwrds: keywords we use to parse the tmpl datastructure.

@PREFIX is a list containing elements of the path in the datastructure we are
generating.

_recurse will traverse tmpl, creating entries through recursion on itself for
every node in the tree tmpl that is not a member of kwrds.

=cut

sub _recurse {
    my ( $self, $params, @prefix ) = @_;
    my $template = $params->{tmpl};
    my $wip      = $params->{accum};
    my $keywords = $params->{kwrds};

    # We manufacture an accumulated result set indexed by xpaths.
    my $xpath = "./" . join( "/", @prefix );

    if ( $template->{many} && $template->{many} eq "yes" ) {

        # The many keyword is special: it means we create a new root.
        $wip->{$xpath} = [ $self->_deriveProperties($template) ];
    }
    else {
        while ( my ( $key, $value ) = each %{$template} ) {
            if ( grep { $key eq $_ } @{$keywords} ) {

                # syntactic keyword entry -> add keyword entry's value to the
                # current prefix entry in our accumulated results.
                if ( $key eq "inSummary" ) {

                    # inSummary should only appear if it's "yes"...
                    $wip->{$xpath}->{$key} = 1 if ( $value eq "yes" );
                }
                else {
                    # otherwise simply enrich.
                    $wip->{$xpath}->{$key} = $value;
                }
            }
            else {
                # non-keyword & non-root entry -> simple recursion to add it
                # to our accumulated results.
                $self->_recurse(
                    {
                        accum => $wip,
                        tmpl  => $template->{$key},
                        kwrds => $keywords,
                    },
                    @prefix, $key
                );
            }
        }
    }
    return $wip;
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>
Andrew Isherwood <andrew.isherwood@ptfs-europe.com>

=cut

1;
