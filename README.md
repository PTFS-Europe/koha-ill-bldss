
# Koha Interlibrary Loans BLDSS backend

This backend provides the ability to create Interlibrary Loan requests using the BLDSS service.

## Getting Started

The version of the backend you require depends on the version of Koha you are using:
* 17.11 - Use the 17.11 branch if you are using this version of Koha
* 18.05 - Use the 18.05 branch if you are using this version of Koha
* master - We recommend against using this branch as it contains additions that are tied to pending bugs in Koha and, as such, will not work with any released version of Koha

## Installing

* Create a directory in `Koha` called `Illbackends`, so you will end up with `Koha/Illbackends`
* Clone the repository into this directory, so you will end up with `Koha/Illbackends/koha-ill-bldss`
* In the `koha-ill-bldss` directory switch to the branch you wish to use
* Activate ILL by enabling the `ILLModule` system preference

## Configuration

* Additional configuration to be set in koha-conf.xml

  Currently our configuration accepts 6 additional parameters from
  koha-conf.xml:
  - <api_key>
  - <api_key_auth>
  - <api_application>
  - <api_application_auth>
  - <api_url>
  - <is_outside_uk>
  
  Normally only `<api_application>` and `<api_application_auth>` need to
  be set. `<api_url>` defaults to the test environment, so it should be
  set when switching to production, to "https://api.bldss.bl.uk".
  
  `<is_outside_uk> `should be set according to whether the request is being made
  from an institution outside the UK. If not, an additional flag is sent to
  the BLDSS API request: `<payCopyright>true</payCopyright>`. If this flag is
  not present in the config, we will assume the institution is inside the UK
