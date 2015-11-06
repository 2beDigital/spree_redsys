SpreeRedsys
============

Basic support for the Spanish Redsys HMAC SHA256 “TPV Virtual” Spree::BillingIntegration,
Version 2-4 & 1.3. stable

Based on https://github.com/samlown/active_merchant Library by @samlown
Following the integration examples: https://github.com/spree/spree_paypal_express 
and https://github.com/spree/spree_skrill


Install
=======

Add the following line to your application's Gemfile.

gem "spree_redsys", :https => "https://github.com/2beDigital/spree-redsys.git"

Configuring
===========
Add a new Payment Method, using: Spree::BillingIntegration::Payment as the Prodivder

Click Create, and enter your Redsys account details.

Save and enjoy!



TODO
====

. Refactor & improve the code.

. Write Rspecs, Tests tests...

. Perhaps Iframe integration like Skrill.

. Get Service Url from admin config instead of Active_Merchant Library.

. Locales...

Copyright (c) 2012, released under the New BSD License
