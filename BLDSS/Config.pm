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
  my ($class, $configuration) = @_;

  my $config
    = $configuration->{configuration}->{raw_config};  # Extract the raw settings
  my $self = {
    api_key              => $config->{api_key}              || "73-0013",
    api_key_auth         => $config->{api_key_auth}         || "API1394039",
    api_application      => $config->{api_application}      || "BLAPI8IJdN",
    api_application_auth => $config->{api_application_auth} || "m7eZz1CCu7",
    api_url       => $config->{api_url} || "https://apitest.bldss.bl.uk",
    is_outside_uk => $config->{is_outside_uk} || 0,
    config        => $config,
    configuration => $configuration,
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
  my ($self) = @_;
  my $values = {};
  if (!$self->{config}->{branch}) {

    # OK, no per branch config defined
  }
  elsif (ref $self->{config}->{branch} eq 'HASH') {
    my $branch_spec = $self->{config}->{branch};
    $values->{$branch_spec->{code}} = $branch_spec->{library_privilege};
  }
  elsif (ref $self->{config}->{branch} eq 'ARRAY') {
    foreach my $branch_spec (@{$self->{config}->{branch}}) {
      $values->{$branch_spec->{code}} = $branch_spec->{library_privilege};
    }
  }
  $values->{default} = $self->{config}->{library_privilege} || 0;
  return $values;
}

=head3 getShouldLoanBook

    my $shouldLoanBook = $config->getShouldLoanBook();

Return whether the config has specified whether the unmediated
flow should request the loan of a book if it's available

=cut

sub getShouldLoanBook {
  my ($self, $request, $borrower) = @_;

  # borrower_category takes precedent
  if ($self->{config}->{borrower_category}) {
    if (ref $self->{config}->{borrower_category} eq 'HASH') {
        # Single per borrower_category config
        if (
            # If this borrower_category spec matches the borrower in question
            $self->{config}->{borrower_category}->{code} eq $borrower->categorycode &&
            $self->{config}->{borrower_category}->{loan_book_if_available}
        ) {
            return 1;
        }
    }
    elsif (ref $self->{config}->{borrower_category} eq 'ARRAY') {
        # Multiple per borrower_category configs
        foreach my $spec (@{$self->{config}->{borrower_category}}) {
            if (
                $spec->{code} eq $borrower->categorycode &&
                $spec->{loan_book_if_available}
            ) {
                return 1;
            }
        }
    }
  }
  # Didn't find an answer in borrower_category, so check in branch
  if ($self->{config}->{branch}) {
    if (ref $self->{config}->{branch} eq 'HASH') {
        # Single per branch config
        if (
            # If this branch spec matches the branch in question
            $self->{config}->{branch}->{code} eq $request->branchcode &&
            $self->{config}->{branch}->{loan_book_if_available}
        ) {
            return 1;
        }
    }
    elsif (ref $self->{config}->{branch} eq 'ARRAY') {
        # Multiple per branch configs
        foreach my $spec (@{$self->{config}->{branch}}) {
            if (
                $spec->{code} eq $request->branchcode &&
                $spec->{loan_book_if_available}
            ) {
                return 1;
            }
        }
    }
  }
  # Didn't find anything in branch, check if there's a global value,
  # otherwise return 0
  return $self->{config}->{loan_book_if_available} || 0;
}

=head3 getDefaultFormats

    my $defaultFormat = $config->getLimitRules('brw_cat' | 'branch')

Return the hash of ILL default formats defined by our config.

=cut

sub getDefaultFormats {
  my ($self, $type) = @_;
  die "Unexpected type." unless ($type eq 'brw_cat' || $type eq 'branch');
  my $values = {};
  if ($type eq 'branch') {

    # Per branch definitions
    if (!$self->{config}->{branch}) {

      # OK, no per branch config defined
    }
    elsif (ref $self->{config}->{branch} eq 'HASH') {
      my $branch_spec = $self->{config}->{branch};
      $values->{branch}->{$branch_spec->{code}}
        = $branch_spec->{default_formats};
    }
    elsif (ref $self->{config}->{branch} eq 'ARRAY') {
      foreach my $branch_spec (@{$self->{config}->{branch}}) {
        $values->{branch}->{$branch_spec->{code}}
          = $branch_spec->{default_formats};
      }
    }
  }
  elsif ($type eq 'brw_cat') {

    # Per borrower category definitions
    if (!$self->{config}->{borrower_category}) {

      # OK, no per borrower_category config defined
    }
    elsif (ref $self->{config}->{borrower_category} eq 'HASH') {
      my $brwcat_spec = $self->{config}->{borrower_category};
      $values->{brw_cat}->{$brwcat_spec->{code}}
        = $brwcat_spec->{default_formats};
    }
    elsif (ref $self->{config}->{branch} eq 'ARRAY') {
      foreach my $brwcat_spec (@{$self->{config}->{borrower_category}}) {
        $values->{brw_cat}->{$brwcat_spec->{code}}
          = $brwcat_spec->{default_formats};
      }
    }
  }

  $values->{default} = $self->{config}->{default_formats};

  return $values;
}

=head3 getDigitalRecipients

    my $digitalRecipient = $config->getDigitalRecipient('brw_cat' | 'branch')

Return the hash of digitalRecipient settings defined by our config.

=cut

sub getDigitalRecipients {
  my ($self, $type) = @_;
  return $self->{configuration}->getDigitalRecipients($type);
}


=head3 setCredentials

    my $credentials = $config->setCredentials($branchCode);

Establish the best-fit credentials: if we have credentials for $branchCode, use
those and set our instance properties accordingly

=cut

sub setCredentials {
  my ($self, $branchCode) = @_;

  # First we need to find the config for the branch we may have been passed
  if ($branchCode) {
    my $branches = (ref $self->{config}->{branch} eq 'ARRAY') ?
        $self->{config}->{branch} :
        [ $self->{config}->{branch} ];
    # Check we have a config for the branch we were passed and, if so,
    # grab it
    my $target;
    foreach my $branch(@{$branches}) {
        if ($branch->{code} eq $branchCode) {
            $target = $branch;
            last;
        }
    }
    # If we found a branch and it contains credentials
    if (
        $target &&
        $target->{api_key} &&
        $target->{api_key_auth}
    ) {
        $self->{api_key}      = $target->{api_key};
        $self->{api_key_auth} = $target->{api_key_auth};
    }
  }
  return {
      api_key      => $self->{api_key},
      api_key_auth => $self->{api_key_auth}
  };
}

=head3 getApiSpec

    my $api_spec_file = $config->getApiSpec;

Return a YAML description of the record structure used by BLDSS API.

=cut

sub getApiSpec {
  my ($self) = @_;
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
        inSummary: yes
      issn:
        name: ISSN
        inSummary: yes
      isbn:
        name: ISBN
        inSummary: yes
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
        inSummary: yes
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
