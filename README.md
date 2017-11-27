SpreeRedsys
============

Basic support for the Spanish Redsys HMAC SHA256 “TPV Virtual” Spree::BillingIntegration,
Version 3.0-stable & 2-4 & 1.3. stable

Based on https://github.com/2beDigital/spree_redsys.git by @picazoH



Install
=======

Add the following line to your application's Gemfile.

gem "spree_redsys", :git => "https://github.com/sylvinho81/spree_redsys.git", :branch => '3-0-stable'

bundle install

bundle exec rails g spree_redsys:install


Configuring
===========
Add a new Payment Method, using: Spree::BillingIntegration::RedsysPayment as the Provider

Click Create, and enter your Redsys account details.

Save and enjoy!



TODO
====

. Refactor & improve the code.

. Write Rspecs, Tests tests...

. Perhaps Iframe integration like Skrill.

. Locales...

Copyright (c) 2016, released under the New BSD License
