package Koha::Illbackends::BLDSS::BLDSS::Config;
use strict;
use warnings;

=head3 new

    my $config = Koha::Illbackends::BLDSS::BLDSS::Config->new(
       {
           api_application      => "app_key",
           api_application_auth => "app_auth",
           api_key              => "cust_key"
           api_key_auth         => "cust_auth",
       }
    );

Constructor for BLDSS Config object.  All it needs is the api_application and
api_key values.  These are both retrieved from the application summary page in
the BL web interface.  We provide defaults for now, but normally they should
be populated through parameters for the constructor.

=cut

sub new {
    my ( $class, $configuration ) = @_;

    my $config = $configuration->{configuration}->{raw_config}; # Extract the raw settings
    my $self = {
        api_key              => $config->{api_key}              || "73-0013",
        api_key_auth         => $config->{api_key_auth}         || "API1394039",
        api_application      => $config->{api_application}      || "BLAPI8IJdN",
        api_application_auth => $config->{api_application_auth} || "m7eZz1CCu7",
        api_url              => $config->{api_url}              || "http://apitest.bldss.bl.uk",
        config               => $config,
        configuration        => $configuration,
    };

    bless $self, $class;
    return $self;
}

sub api_key {
    my $self = shift;
    return $self->{api_key};
}

sub api_application {
    my $self = shift;
    return $self->{api_application};
}

sub api_url {
    my $self = shift;
    return $self->{api_url};
}

sub hashing_key {
    my $self = shift;
    return join("&", $self->{api_application_auth}, $self->{api_key_auth});
}

=head3 getLibraryPrivileges

    my $privileges= $config->getLibraryPrivileges;

Return the LibraryPrivilege definitions defined by our config.

=cut

sub getLibraryPrivileges {
    my ( $self ) = @_;
    my $values= $self->{configuration}->{library_privileges}->{branch} || {};
    $values->{default} =
        $self->{configuration}->{library_privileges}->{default};
    return $values;
}

=head3 getDefaultFormats

    my $defaultFormat = $config->getLimitRules('brw_cat' | 'branch')

Return the hash of ILL default formats defined by our config.

=cut

sub getDefaultFormats {
    my ( $self, $type ) = @_;
    die "Unexpected type." unless ( $type eq 'brw_cat' || $type eq 'branch' );
    my $values = $self->{configuration}->{default_formats}->{$type};
    $values->{default} = $self->{configuration}->{default_formats}->{default};
    return $values;
}

=head3 getDigitalRecipients

    my $digitalRecipient = $config->getDigitalRecipient('brw_cat' | 'branch')

Return the hash of digitalRecipient settings defined by our config.

=cut

sub getDigitalRecipients {
    my ( $self, $type ) = @_;
    return $self->{configuration}->getDigitalRecipients($type);
}


=head3 getCredentials

    my $credentials = $config->getCredentials($branchCode);

Fetch the best-fit credentials: if we have credentials for $branchCode, use
those; otherwise fall back on default credentials.  If neither can be found,
simply populate application details, and populate key details with 0.

=cut

sub getCredentials {
    my ( $self, $branchCode ) = @_;
    my $creds = $self->{configuration}->{credentials}
        || die "We have no credentials defined.  Please check koha-conf.xml.";

    my $exact = { api_key => 0, api_auth => 0 };
    if ( $branchCode && $creds->{api_keys}->{$branchCode} ) {
        $exact = $creds->{api_keys}->{$branchCode}
    } elsif ( $creds->{api_keys}->{default} ) {
        $exact = $creds->{api_keys}->{default};
    }

    return {
        api_key              => $exact->{api_key},
        api_key_auth         => $exact->{api_auth},
        api_application      => $creds->{api_application}->{key},
        api_application_auth => $creds->{api_application}->{auth},
    };
}

=head3 getApiSpec

    my $api_spec_file = $config->getApiSpec;

Return a YAML description of the record structure used by BLDSS API.

=cut

sub getApiSpec {
    my ( $self ) = @_;
    return "record:
  uin:
    name: British Library Identifier
    inSummary: yes
    accessor: id
  type:
    name: Material Type
    accessor: type
    inSummary: yes
  isAvailableImmediateley:
    name: Available now?
  metadata:
    titleLevel:
      title:
        name: Title
        inSummary: yes
        accessor: title
      author:
        name: Author
        inSummary: yes
      identifier:
        name: Identifier
      publisher:
        name: Publisher
      issn:
        name: ISSN
      isbn:
        name: ISBN
      ismn:
        name: ISMN
      shelfmark:
        name: Shelfmark
      conferenceVenue:
        name: Conference Venue
      conferenceDate:
        name: Conference Date
      thesisUniversity:
        name: Thesis University
      thesisDissertation:
        name: Thesis Dissertation
      mapScale:
        name: Map Scale
    itemLevel:
      year:
        name: Year
        inSummary: yes
      volume:
        name: Volume Number
        inSummary: yes
      issue:
        name: Issue Number
        inSummary: yes
      part:
        name: Part Number
      edition:
        name: Edition
      season:
        name: Season
      month:
        name: Month
      day:
        name: Day
      specialIssue:
        name: Special Issue
    itemOfInterestLevel:
      title:
        name: Part Title
        inSummary: yes
      author:
        name: Part Author
        inSummary: yes
      pages:
        name: Pages
        inSummary: yes
";
}

1;
