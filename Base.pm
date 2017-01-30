package Koha::Illbackends::BLDSS::Base;

# Copyright PTFS Europe 2014
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

use BLDSS;
use C4::Branch;
use Clone qw( clone );
use Locale::Country;
use XML::LibXML;
use Koha::Illrequest::Config;
use Koha::Illbackends::BLDSS::XML;
use URI::Escape;
use YAML;

# We will be implementing the Abstract interface.
#use base qw(Koha::ILLRequest::Abstract);

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
    my $config = $params->{config};

    my $self = {
        keywords => [ "name", "accessor", "inSummary", "many" ],
        primary_props => {
            primary_access_url => {
                name      => "Access URL",
                inSummary => undef,
            },
            primary_cost => {
                name      => "Cost",
                inSummary => "true",
            },
            primary_manual => {
                name      => "Manually Created",
                inSummary => "true",
            },
            primary_notes_opac => {
                name      => "Opac notes",
                inSummary => undef,
            },
            primary_notes_staff => {
                name      => "Staff notes",
                inSummary => undef,
            },
            primary_order_id   => {
                name      => "Order ID",
                inSummary => undef,
            },
        },
        data          => {},
        accessors     => {},
    };
    bless( $self, $class );
    $self->_config($params->{config});
    $self->_api(
        BLDSS->new( {
            api_keys => $self->_config->getCredentials($params->{branch}),
            api_url  => $self->_config->getApiUrl,
        } )
    );
    return $self;
}

=head3 _api

    my $api = $bldss->_api($api);
    my $api = $bldss->_api;

Getter/Setter for our API object.

=cut

sub _api {
    my ( $self, $api ) = @_;
    $self->{api} = $api if ( $api );
    return $self->{api};
}

=head3 _config

    my $config = $bldss->_config($config);
    my $config = $bldss->_config;

Getter/Setter for our config object.

=cut

sub _config {
    my ( $self, $config ) = @_;
    $self->{config} = $config if ( $config );
    return $self->{config};
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
    my ( $self, $record, $status, $params ) = @_;
    my $stage = $params->{stage};
    if ( 'availability' eq $stage || !$stage ) {
        return $self->availability($record);
    } elsif ( 'pricing' eq $stage ) {
        return $self->prices($params);
    } elsif ( 'commit' eq $stage ) {
        return $self->create_order($record, $status, $params);
    } else {
        die "Confirm Unexpected Stage";
    }
}

=head3 create

    my $response = $BLDSS->create( $params );

Return an ILL standard response for the create method call.

For BLDSS, this is a composite method.

The first stage returns the request for form generation.

The second stage returns either a list of search results, or 'commit' if we
had manual entry, with details for creating the ILLRequest from manual form.

The third stage returns 'commit' with details of the selected ILLRequest.

=cut

sub create {
    my ( $self, $params ) = @_;
    my $stage = $params->{stage};
    if ( 'init' eq $stage || !$stage ) {
        # We just need to request the snippet that builds the Creation
        # interface.
        return {
            status  => "",
            message => "",
            error   => 0,
            value   => $params,
            method  => "create",
            stage   => "init",
        };
    } elsif ( 'validate' eq $stage ) {
        my ( $brw_count, $brw )
            = _validate_borrower($params->{'brw'}, $params->{'stage'});
        my $result = {
            status  => "",
            message => "",
            error   => 1,
            value   => {},
            method  => "create",
            stage   => "init",
        };
        if ( _fail($params->{'query'}) ) {
            $result->{status} = "missing_query";
            $result->{value} = $params;
            return $result;
        } elsif ( _fail($params->{'branch'}) ) {
            $result->{status} = "missing_branch";
            $result->{value} = $params;
            return $result;
        } elsif ( !GetBranchDetail($params->{'branch'}) ) {
            $result->{status} = "invalid_branch";
            $result->{value} = $params;
            return $result;
        } elsif ( $brw_count == 0 ) {
            $result->{status} = "invalid_borrower";
            $result->{value} = $params;
            return $result;
        } elsif ( $brw_count > 1 ) {
            # We must select a specific borrower out of our options.
            $params->{brw} = $brw;
            $result->{value} = $params;
            $result->{stage} = "borrowers";
            $result->{error} = 0;
            return $result;
        } else {
            # We perform the search!
            $params->{brw} = $brw->cardnumber;
            return $self->_search($params);
        }
    } elsif ( 'search_cont' eq $stage ) {
        # Continue search!
        return $self->_search($params);
    } elsif ( 'manual' eq $stage ) {
        # Build the manual entry fields.
        my $fields = {};
        my $mps = $self->getSpec->{manual_props};
        while ( my ($k, $v) = each %{$mps} ) {
            $fields->{$k} = $v->{name};
        }
        # Request we generate manual form
        return {
            status  => "",
            message => "",
            error   => 0,
            value   => $fields,
            method  => "create",
            stage   => "manual",
        };
    } elsif ( 'manual_confirm' eq $stage ) {
        my ( $brw_count, $brw )
            = _validate_borrower($params->{'brw'}, $params->{'stage'});
        my $result = {
            status  => "",
            message => "",
            error   => 1,
            value   => {},
            method  => "create",
            stage   => "init",
        };
        if ( _fail($params->{'branch'}) ) {
            $result->{status} = "missing_branch";
            return $result;
        } elsif ( !GetBranchDetail($params->{'branch'}) ) {
            $result->{status} = "invalid_branch";
            return $result;
        } elsif ( $brw_count == 0 ) {
            $result->{status} = "invalid_borrower";
            return $result;
        } elsif ( $brw_count > 1 ) {
            # We must select a specific borrower.
            $params->{brw} = $brw;
            $result->{value} = $params;
            $result->{stage} = "borrowers";
            $result->{error} = 0;
            return $result;
        } else  {
            my $fields = {};
            my $mps = $self->getSpec->{manual_props};
            while ( my ($k, $v) = each %{$mps} ) {
                $fields->{$k} = [ $v->{name}, $params->{$k} ];
            }
            $fields->{borrower} = [ "Borrower", $params->{brw} ];
            $fields->{branch} = [ "Branch", $params->{branch} ];
            # Request we emit fields and values for confirmation.
            return {
                status  => "",
                message => "",
                error   => 0,
                value   => $fields,
                method  => "create",
                stage   => "manual_confirm",
            };
        }
    } elsif ( 'commit_manual' eq $stage ) {
        # We should have the data we need for manually created Record.
        return {
            status  => "",
            message => "",
            error   => 0,
            value   => $self->_populate($params),
            method  => "create",
            stage   => "commit",
        };
    } elsif ( 'commit' eq $stage ) {
        # We should have the data we need for an API derived Record.
        return {
            status  => "",
            message => "",
            error   => 0,
            value   => $self->_find($params->{uin}),
            method  => "create",
            stage   => "commit",
        };
    } else {
        die "Create Unexpected Stage";
    }
}

=head3 list

    my $response = $BLDSS->list( $record, $status, $params );

This method is not yet implemented and will trigger an error.

=cut

sub list {
    my ( $self, $record, $status, $params ) = @_;
    return {
        error   => 1,
        status  => 'not_implemented',
        message => 'List requests is not implemented for BLDSS yet.',
        method  => 'list',
        stage   => 'commit',
        future  => 0,
        value   => {},
    };
}

=head3 renew

    my $response = $BLDSS->renew( $record, $status, $params );

This method is not yet implemented and will trigger an error.

=cut

sub renew {
    my ( $self, $record, $status, $params ) = @_;
    return {
        error   => 1,
        status  => 'not_implemented',
        message => 'Renew request is not implemented for BLDSS yet.',
        method  => 'renew',
        stage   => 'commit',
        future  => 0,
        value   => {},
    };
}

=head3 update_status

    my $response = $BLDSS->update_status( $record, $status, $params );

Return an ILL standard response for the update_status method call.

For BLDSS, this method currently is a noop.  We simply return success.

=cut

sub update_status {
    my ( $self, $record, $status, $params ) = @_;
    # We have no business logic to perform as part of updating statuses.
    return {
        error => 0,
        method => 'confirm',
    };
}

=head3 cancel

    my $response = $BLDSS->cancel( $record, $status, $params );

Return an ILL standard response for the cancel method call.

As for all cancel calls, $params will simply contain 'order_id'.

=cut

sub cancel {
    my ( $self, $record, $status, $params ) = @_;
    return $self->_process($self->_api->cancel_order($params->{order_id}));
}

=head3 status

    my $response = $BLDSS->status( $record, $status, $params );

Return an ILL standard response for the status method call.

As for all status calls, $params will simply contain 'order_id'.

=cut

sub status {
    my ( $self, $record, $status, $params ) = @_;
    my $status = $self->_process($self->_api->order($params->{order_id}));
    # querying message on this response fails for some reason.
    if ( !$status->{error} ) {
        my $orderline  = $status->{value}->result->orderline;
        my $delDetails = $orderline->deliveryDetails;
        $status->{value} = {
            cost              => [
                "Total cost", $orderline->cost
            ],
            customerReference => [
                "Customer Reference", $orderline->customerRef
            ],
            note              => [
                "Note", $orderline->note
            ],
            requestor         => [
                "Requestor", $orderline->requestor
            ],
            status            => [
                "Status", $orderline->overallStatus
            ],
        };

        # Add extra delivery details
        my @deliveryDetails;
        push @deliveryDetails, {
            deliveryType => ["Delivery type", $delDetails->type ]
        };
        if ( 'digital' eq $delDetails->type ) {
            push @deliveryDetails, {
                deliveryEmail => [ "Delivery email", $delDetails->email ]
            };
        } elsif ( 'physical' eq $delDetails->type ) {
            my $address = $delDetails->address;

            my @titles = (
                "Address line 1", "Address line 2", "Address line 3",
                "Country", "County or state", "Department", "Postcode",
                "Province or region", "Town or city"
            );
            for ( qw/ AddressLine1 AddressLine2 AddressLine3 Country
                      CountyOrState Department PostOrZipCode
                      ProvinceOrRegion TownOrCity / ) {
                push @deliveryDetails, {
                    'delivery' . $_ => [ shift(@titles), $address->$_ ]
                };
            }
        } else {
            die "unexpected delivery type: $delDetails->type";
        }

        $status->{value}->{delivery} = [
            "Delivery details", \@deliveryDetails
        ];

        # Add history elements
        my @history;
        for ( @{$orderline->historyEvents} ) {
            push @history, {
                time => [ "Timestamp", $_->time ],
                type => [ "Event type", $_->eventType ],
                info => [ "Additional notes", $_->additionalInfo ],
            }
        }
        $status->{value}->{history} = [
            "Request history", \@history
        ];
        $status->{method} = "status";
        $status->{stage} = "commit";
        $status->{future} = 0;
    }
    return $status;
}

#### Helpers

sub validate_delivery_input {
    my ( $self, $params ) = @_;
    my ( $fmt, $brw, $brn, $recipient ) = (
        $params->{service}->{format}, $params->{borrower}, $params->{branch},
        $params->{digital_recipient},
    );
    # FIXME: Here we can cross-reference services with API's services request.
    # The latter currently returns 404, so instead we mock a services
    # response.
    # my $formats = $self->_api_do( {
    #     action => 'reference',
    #     params => [ 'formats' ],
    # } );
    my $formats = {
        1 => "digital",
        2 => "digital",
        3 => "digital",
        4 => "physical",
        5 => "physical",
        6 => "physical",
    };
    # Seed return values.
    # FIXME: instead of dying we should return Status, for friendly UI output
    # (0 only in case of all valid).
    my ( $status, $delivery ) = ( 0, {} );

    if ( 'digital' eq $formats->{$fmt} ) {
        my $target = $brw->email || "";
        if ( 'branch' eq $recipient ) {
            if ( $brn->{branchreplyto} ) {
                $target = $brn->{branchreplyto};
            } else {
                $target = $brn->{branchemail};
            }
        }
        die "Digital delivery: invalid $recipient type email address."
            if ( !$target );
        $delivery->{email} = $target;
    } elsif ( 'physical' eq $formats->{$fmt} ) {
        # Country
        $delivery->{Address}->{Country} = country2code(
            $brn->{branchcountry}, LOCALE_CODE_ALPHA_3
        ) || die "Invalid country in branch record: $brn->{branchcountry}.";
        # Mandatory Fields
        my $mandatory_fields = {
            AddressLine1  => "branchaddress1",
            TownOrCity    => "branchcity",
            PostOrZipCode => "branchzip",
        };
        while ( my ( $bl_field, $k_field ) = each %{$mandatory_fields} ) {
            die "Physical delivery requested, but branch missing $k_field."
                if ( !$brn->{$k_field} or "" eq $brn->{$k_field} );
            $delivery->{Address}->{$bl_field} = $brn->{$k_field};
        }
        # Optional Fields
        my $optional_fields = {
            AddressLine2     => "branchaddress2",
            AddressLine3     => "branchaddress3",
            CountyOrState    => "branchstate",
            ProvinceOrRegion => "",
        };
        while ( my ( $bl_field, $k_field ) = each %{$optional_fields} ) {
            $delivery->{Address}->{$bl_field} = $brn->{$k_field} || "";
        }
    } else {
        die "Unknown service type: $fmt."
    }

    return ( $status, $delivery );
}

=head3 _fail

=cut

sub _fail {
    my @values = @_;
    foreach my $val ( @values ) {
        return 1 if (!$val or $val eq '');
    }
    return 0;
}

=head3 _validate_borrower

=cut

sub _validate_borrower {
    # Perform cardnumber search.  If no results, perform surname search.
    # Return ( 0, undef ), ( 1, $brw ) or ( n, $brws )
    my ( $input, $action ) = @_;
    my $borrowers = Koha::Borrowers->new;
    my ( $count, $brw );
    my $query = { cardnumber => $input };
    $query = { borrowernumber => $input } if ( $action eq 'search_cont' );

    my $brws = $borrowers->search( $query );
    $count = $brws->count;
    my @criteria = qw/ surname firstname end /;
    while ( $count == 0 ) {
        my $criterium = shift @criteria;
        return ( 0, undef ) if ( "end" eq $criterium );
        $brws = $borrowers->search( { $criterium => $input } );
        $count = $brws->count;
    }
    if ( $count == 1 ) {
        $brw = $brws->next;
    } else {
        $brw = $brws;           # found multiple results
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
        "The API responded with an error: ", $self->_api->error->{status},
        "\nDetail: ", $self->_api->error->{content}
    ) if ( $self->_api->error );

    my $re = Koha::Illbackends::BLDSS::XML->new->load_xml(
        { string => $response }
    );

    my $status = $re->status;
    my $message = $re->message;
    my $response = $re;
    my $code = "This unusual case has not yet been defined: $message ($status)";
    my $error = 0;

    if ( 0 == $status ) {
        if ( 'Order successfully cancelled' eq $message ) {
            $code = 'cancel_success';
        } elsif ( 'Order successfully submitted' eq $message ) {
            $code = 'request_success';
        } elsif ( '' eq $message ) {
            $code = 'status_success';
        }

    } elsif ( 1 == $status ) {
        if ( 'Invalid Request: A valid physical address is required for the delivery format specified' eq $message ) {
            $code = 'branch_address_incomplete';
            $error = 1;
        } else {
            $code = 'invalid_request';
            $error = 1;
        }

    } elsif ( 5 == $status ) {
        $code = 'request_fail';
        $error = 1;
    } elsif ( 111 == $status ) {
        $code = 'unavailable';
        $error = 1;

    } elsif ( 162 == $status ) {
        $code = 'cancel_fail';
        $error = 1;
    } elsif ( 170 == $status ) {
        $code = 'search_fail';
        $error = 1;
    } elsif ( 701 == $status ) {
        $code = 'request_fail';
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
    my ( $self, $record ) = @_;
    my $response = $self->_process($self->_api->availability(
        $record->getProperty('id'),
        { year => $record->getProperty('year') }
    ));

    return $response if ( $response->{error} );
    my $availability = $response->{value}->result->availability;
    my @formats;
    foreach my $format (@{$availability->formats}) {
        my @speeds;
        foreach my $speed (@{$format->speeds}) {
            push @speeds, {
                speed => [ "Speed", $speed->textContent ],
                key => [ "Key", $speed->key ],
            };
        }
        my @qualities;
        foreach my $quality (@{$format->qualities}) {
            push @qualities, {
                quality => [ "Quality", $quality->textContent ],
                key => [ "Key", $quality->key ],
            };
        }

        push @formats, {
            format    => [ "Format", $format->deliveryFormat->textContent ],
            key       => [ "Key", $format->deliveryFormat->key ],
            speeds    => [ "Speeds", \@speeds ],
            qualities => [ "Qualities", \@qualities ],
        };
    }

    $response->{value} =  {
        copyrightFee         => [ "Copyright fee",
                                  $availability->copyrightFee ],
        availableImmediately => [ "Available immediately?",
                                  $availability->availableImmediately ],
        formats              => [ "Formats", \@formats ],
    };
    $response->{method} = "confirm";
    $response->{stage} = "availability";
    $response->{future} = "pricing";
    return $response;
}

sub create_order {
    my ( $self, $record, $status, $params ) = @_;

    my $brw = $status->getProperty('borrower');
    my $branch_code = $status->getProperty('branch');
    my $brw_cat     = $brw->categorycode;
    my $branch = C4::Branch::GetBranchDetail($branch_code);
    my $details;
    if ( $params->{speed} ) {
        $details = {
            speed   => $params->{speed},
            quality => $params->{quality},
            format  => $params->{format},
        };
    } else {
        $details = $self->getDefaultFormat( {
            brw_cat => $brw_cat,
            branch  => $branch_code,
        } );
    }
    my ( $invalid, $delivery ) = $self->validate_delivery_input( {
        service           => $details,
        borrower          => $brw,
        branch            => $branch,
        digital_recipient => $self->getDigitalRecipient({
            brw_cat => $brw->categorycode,
            branch  => $branch,
        }),
    } );
    return $invalid if ( $invalid );

    my $final_details = {
        type     => "S",
        Item     => {
            uin     => $record->getProperty('id'),
            # At least one item of interest criterium is required for 'paper'
            # book requests.  But this is not always provided by the BL.
            # Through no fault of our own, we may end in a dead-end.
            itemOfInterestLevel => {
                title  => $record->getProperty('ioiTitle'),
                pages  => $record->getProperty('ioiPages'),
                author => $record->getProperty('ioiAuthor'),
            }
        },
        service  => $details,
        Delivery => $delivery,
        # Optional params:
        requestor         => join(" ", $brw->firstname, $brw->surname),
        customerReference => $params->{customerReference},
        payCopyright => $self->getPayCopyright($branch),
    };

    my $response = $self->_process($self->_api->create_order($final_details));
    return $response if $response->{error};

    $response->{method} = "confirm";
    $response->{stage} = "commit";
    $response->{future} = 0;
    $response->{order_id} = $response->{value}->result->newOrder->orderline;
    $response->{cost} = $response->{value}->result->newOrder->totalCost;
    $response->{acces_url} = $response->{value}->result->newOrder->downloadUrl;
    return $response;
}

sub prices {
    my ( $self, $params ) = @_;
    my $coordinates = {
        format  => $params->{'format'},
        speed   => $params->{'speed'},
        quality => $params->{'quality'},
    };
    my $response =  $self->_process($self->_api->prices);
    return $response if ( $response->{error} );
    my $result   = $response->{value}->result;
    my $price = 0;
    my $service = 0;
    my $services = $result->services;
    foreach ( @{$services} ) {
        my $format = $_->get_format($params->{format});
        if ( $format ) {
            $price = $format->get_price($params->{speed}, $params->{quality}) ||
                $format->get_price($params->{speed});
            $service = $_;
            last;
        }
    }
    $response->{value} = {
        currency        => [ "Currency", $result->currency ],
        region          => [ "Region", $result->region ],
        copyrightVat    => [ "CopyrightVat", $result->copyrightVat ],
        loanRenewalCost => [ "Loan Renewal Cost", $result->loanRenewalCost ],
        price           => [ "Price", $price->textContent ],
        service         => [ "Service", $service->{id} ],
        coordinates     => $coordinates,
    };
    $response->{method} = "confirm";
    $response->{stage} = "pricing";
    $response->{future} = "commit";
    return $response;
}

sub reference {
    my ( $self, @params ) = @_;
    return $self->_process($self->_api->reference(@params));
}

sub _populate {
    my ( $self, $params ) = @_;
    my $content = {};
    my $mps = $self->getSpec->{manual_props};
    while ( my ( $id, $properties ) = each %{$mps} ) {
        $content->{$id} = {
            value     => $params->{$id},
            name      => $properties->{name},
            inSummary => $properties->{inSummary} || 0,
        };
    }
    return Koha::ILLRequest::Record->new($self->_config)
        ->create_from_api($content, 1);
}

sub _find {
    my ( $self, $uin ) = @_;
    my $response = $self->_process($self->_api->search($uin));
    return $response if ( $response->{error} );
    return Koha::ILLRequest::Record->new($self->_config)
        ->create_from_api(
            $self->_parseResponse(
                @{$response->{value}->result->records},
                $self->getSpec->{record_props}, {})
        );
}

=head3 search

    my $results = $bldss->search($query, $opts);

Return an array of Record objects.

The optional OPTS parameter specifies additional options to be passed to the
API. For now the options we use in the ILL Module are:
 max_results -> SearchRequest.maxResults,
 start_rec   -> SearchRequest.start,
 isbn        -> SearchRequest.Advanced.isbn
 issn        -> SearchRequest.Advanced.issn
 title       -> SearchRequest.Advanced.title
 author      -> SearchRequest.Advanced.author
 type        -> SearchRequest.Advanced.type
 general     -> SearchRequest.Advanced.general

We simply pass the options hashref straight to the backend.

=cut

sub _search {
    my ( $self, $params ) = @_;
    my $query = $params->{query};
    my $brw = $params->{brw};
    my $branch = $params->{branch};
    my %opts = map { $_ => $params->{$_} }
        qw/ author isbn issn title type max_results start_rec /;
    my $opts = \%opts;

    $opts->{max_results} = 10 unless $opts->{max_results};
    $opts->{start_rec} = 1 unless $opts->{start_rec};

    # Perform the search in the API
    my $response = $self->_process($self->_api->search($query, $opts));
    return $response if ( $response->{error} );

    my @return;
    # Create summaries of the received response.
    my $spec = $self->getSpec->{record_props};
    foreach my $datum ( @{$response->{value}->result->records} ) {
        my $record =
            Koha::ILLRequest::Record->new($self->_config)
              ->create_from_api($self->_parseResponse($datum, $spec, {}))
              ->getSummary;
        push (@return, $record);
    }
    # Add final values to response
    $response->{value} = \@return;
    $response->{method} = "create";
    $response->{stage} = "search";

    # Build user search string & paging query string
    my $nav_qry = "?method=create&stage=search_cont&query="
        . uri_escape($query);
    $nav_qry .= "&brw=" . $brw;
    $nav_qry .= "&branch=" . $branch;
    my $userstring = "[keywords: " . $query . "]";
    while ( my ($type, $value) = each $opts ) {
        $userstring .= "[" . join(": ", $type, $value) . "]";
        $nav_qry .= "&" . join("=", $type, $value)
            unless ( 'start_rec' eq $type );
    }

    # Finalise paging query string
    my $result_count = @return;
    my $current_pos  = $opts->{start_rec};
    my $next_pos = $current_pos + $result_count;
    my $next = $nav_qry . "&start_rec=" . $next_pos
        if ( $result_count == $opts->{max_results} );
    my $prev_pos = $current_pos - $result_count;
    my $previous = $nav_qry . "&start_rec=" . $prev_pos
        if ( $prev_pos >= 1 );

    $response->{userstring} = $userstring;
    $response->{next} = $next;
    $response->{previous} = $previous;
    $response->{brw} = $brw;
    $response->{branch} = $branch;
    $response->{params} = $params;
    return $response;
}

sub error {
    my ( $self, @params ) = @_;
    return $self->_process($self->_api->error(@params));
}

=head3 _getStatusCode

    my $illStatus = _getStatusCode($status, $message);

An introspective call turning API error codes into ILL Module error codes.

=cut

sub _getStatusCode {
}

sub _parseResponse {
    my ( $self, $chunk, $config, $accum ) = @_;
    $accum = {} if ( !$accum ); # initiate $accum if empty.
    foreach my $field ( keys %{$config} ) {
        if ( ref $config->{$field} eq 'ARRAY' ) {
            foreach my $node ($chunk->findnodes($field)) {
                $accum->{$field} = [] if ( !$accum->{$field} );
                push @{$accum}{$field},
                  $self->_parseResponse($node, ${$config}{$field}[0], {});
            }
        } else {
            my ( $op, $arg ) = ( "findvalue", $field );
            ( $op, $arg ) = ( "textContent", "" )
              if ( $field eq "./" );
            $accum->{$field} = {
                value     => $chunk->$op($arg),
                name      => $config->{$field}->{name},
                inSummary => $config->{$field}->{inSummary},
            };
            # FIXME: populate accessor if desired.  This breaks the
            # functional-ish approach by referencing $self directly.
            my $accessor = $config->{$field}->{accessor};
            if ($accessor) {
                $self->{accessors}->{$accessor} = sub {
                    return $accum->{$field}->{value};
                };
            }
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
    my $brw_dig_rec = $brw_dig_recs->{$params->{brw_cat}} || '';
    my $brn_dig_rec = $brn_dig_recs->{$params->{branch}} || '';
    my $def_dig_rec = $brw_dig_recs->{default} || '';

    my $dig_rec = "borrower";
    if      ( 'borrower' eq $brw_dig_rec || 'branch' eq $brw_dig_rec ) {
        $dig_rec = $brw_dig_rec;
    } elsif ( 'borrower' eq $brn_dig_rec || 'branch' eq $brn_dig_rec ) {
        $dig_rec = $brn_dig_rec;
    } elsif ( 'borrower' eq $def_dig_rec || 'branch' eq $def_dig_rec ) {
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
    my $privilege = $libraryPrivileges->{$branch}
        || $libraryPrivileges->{default}
        || 0;
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

    return $brw_formats->{$params->{brw_cat}}
        || $brn_formats->{$params->{branch}}
        || $brw_formats->{default}
        || die "No suitable format found.  Unlikely to have happened.";
}

sub getSpec {
    my ( $self ) = @_;
    # We need to decide whether we create slots for each object, or whether we
    # abandon the YAML spec approach entirely.
    #
    # We no longer make the assumption: we removed all types but the Record
    # type.
    #
    # ALL APIs will have a record type as it defines the data that the API
    # provides as part of its 'find' or 'search' methods.  It contains things
    # like 'title' or 'author'.
    #
    # Whilst all APIs will have such a definition, the jury is out as to
    # whether it makes sense to enforce the use of a yaml file for this record
    # definition, or whether it should be left entirely to the backend.  The
    # latter is probably better.
    #
    # Assuming that, we should either:
    #
    # a) move yaml loading to the BLDSS backend, so it does not pollute
    # general configuration; or
    #
    # b) remove the yaml system from the BLDSS backend all together.
    #
    # For option (a), my preference, we could have the yaml spec path be part
    # of BLDSS, and have the YAML loader in BLDSS backend.
    #
    # Going with option (a)!
    #
    # This comment will stay as is for a few commits, then it will be
    # rewritten purely to elucidate the role of our spec.yaml.

    my $spec  = _load_api_specification($self->_config->getApiSpecFile);
    my $record_props =
        $self->_deriveProperties({source => $spec->{record}});
    my $manual_props =
        $self->_deriveProperties({source => $spec->{record}, prefix => "m"});

    return {
        record_props => $record_props,
        manual_props => $manual_props,
    };
}

###### YAML Spec Processing! ######

=head3 getProperties

    $properties = $config->getProperties($name);

Return the properties of type $NAME, a data structure derived from parsing the
ILL yaml config.

At present we provide "record" properties.

=cut

sub getProperties {
    my ( $self, $name ) = @_;
    return $self->{$name . "_props"};
}

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
    my $source = $params->{source};
    my $prefix = $params->{prefix} || "";
    my $modifiedSource = clone($source);
    delete $modifiedSource->{many};
    my $accum = $self->_recurse( {
        accum => {},
        tmpl  => $modifiedSource,
        kwrds => $self->{keywords},
    } );
    if ( $prefix ) {
        my $paccum = {};
        while ( my ( $k, $v ) = each $accum ) {
            $paccum->{$prefix . $k} = $v;
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
    my $wip = $params->{accum};
    my $keywords = $params->{kwrds};

    # We manufacture an accumulated result set indexed by xpaths.
    my $xpath = "./" . join("/", @prefix);

    if ( $template->{many} && $template->{many} eq "yes" ) {
        # The many keyword is special: it means we create a new root.
        $wip->{$xpath} =
            [ $self->_deriveProperties($template) ];
    } else {
        while ( my ( $key, $value ) = each $template ) {
            if ( $key ~~ $keywords ) {
                # syntactic keyword entry -> add keyword entry's value to the
                # current prefix entry in our accumulated results.
                if ( $key eq "inSummary" ) {
                    # inSummary should only appear if it's "yes"...
                    $wip->{$xpath}->{$key} = 1
                        if ( $value eq "yes" );
                } else {
                    # otherwise simply enrich.
                    $wip->{$xpath}->{$key} = $value;
                }
            } else {
                # non-keyword & non-root entry -> simple recursion to add it
                # to our accumulated results.
                $self->_recurse({
                        accum => $wip,
                        tmpl  => $template->{$key},
                        kwrds => $keywords,
                    }, @prefix, $key);
            }
        }
    }
    return $wip;
}

=head3 _load_api_specification

    _load_api_specification(FILENAME);

Return a hashref, the result of loading FILENAME using the YAML
loader, or raise an error.

=cut

sub _load_api_specification {
    my ( $config_file ) = @_;
    die "The ill config file (" . $config_file . ") does not exist"
      if not -e $config_file;
    return YAML::LoadFile($config_file);
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
