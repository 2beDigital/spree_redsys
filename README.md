SpreeSermepa
============

Basic support for the Spanish SERMEPA “TPV Virtual” Spree::BillingIntegration,  Spree 1.3.X compatible

Based on https://github.com/samlown/active_merchant Library by @samlown
Following the integration examples: https://github.com/spree/spree_paypal_express 
and https://github.com/spree/spree_skrill


Install
=======

Add the following line to your application's Gemfile.

gem "spree_sermepa", :git => "git://github.com/picazoH/spree_sermepa.git"

Configuring
===========
Add a new Payment Method, using: Spree::BillingIntegration::SermepaPayment as the Prodivder

Click Create, and enter your Sermepa account details.

Save and enjoy!



TODO
====

. Refactor & improve the code.

. Write Rspecs, Tests tests...

. Perhaps Iframe integration like Skrill.

. Get Service Url from admin config instead of Active_Merchant Library.

. Locales...

Copyright (c) 2012, released under the New BSD License
