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
    my ( $class, $keys ) = @_;

    my $self = {
        api_key              => $keys->{api_key}              || "73-0013",
        api_key_auth         => $keys->{api_key_auth}         || "API1394039",
        api_application      => $keys->{api_application}      || "BLAPI8IJdN",
        api_application_auth => $keys->{api_application_auth} || "m7eZz1CCu7",
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

sub hashing_key {
    my $self = shift;
    return join("&", $self->{api_application_auth}, $self->{api_key_auth});
}

1;
