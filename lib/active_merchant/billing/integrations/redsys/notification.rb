# encoding: utf-8
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Redsys
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData

          attr_accessor :params
          attr_accessor :raw

          # set this to an array in the subclass, to specify which IPs are allowed
          # to send requests
          class_attribute :production_ips

          # * *Args*    :
          #   - +doc+ ->     raw post string
          #   - +options+ -> custom options which individual implementations can
          #                  utilize
          def initialize(post, options = {})
            @options = options
            empty!
            parse(post)
          end

          def complete?
            status == 'Completed'
          end


          # When was this payment received by the client.
          def received_at
            if decode_Merchant_Parameters['Ds_Date']
              (day, month, year) = decode_Merchant_Parameters['Ds_Date'].split('/')
              Time.parse("#{year}-#{month}-#{day} #{decode_Merchant_Parameters['Ds_Hour']}")
            else
              Time.now # Not provided!
            end
          end

          # the money amount we received in cents in X.2 format
          def gross
            sprintf("%.2f", decode_Merchant_Parameters['Ds_Amount'].to_f / 100)
          end

          def gross_cents
            (gross.to_f * 100.0).round
          end

          # This combines the gross and currency and returns a proper Money object.
          # this requires the money library located at http://dist.leetsoft.com/api/money
          def amount
            return Money.new(gross_cents, currency) rescue ArgumentError
            return Money.new(gross_cents) # maybe you have an own money object which doesn't take a currency?
          end

          # reset the notification.
          def empty!
            @params  = ActiveSupport::HashWithIndifferentAccess.new
            @raw     = ""
          end

          # Check if the request comes from an official IP
          def valid_sender?(ip)
            return true if ActiveMerchant::Billing::Base.integration_mode == :test || production_ips.blank?
            production_ips.include?(ip)
          end


          # Was this a test transaction?
          def test?
            false
          end

          def currency
            Redsys.currency_from_code(decode_Merchant_Parameters['Ds_Currency'])
          end

          # Status of transaction. List of possible values:
          # <tt>Completed</tt>
          # <tt>Failed</tt>
          # <tt>Pending</tt>
          def status
            case error_code.to_i
              when 0..99
                'Completed'
              when 900
                'Pending'
              else
                'Failed'
            end
          end

          def error_code
            decode_Merchant_Parameters['Ds_Response']
          end

          def error_message
            msg = Redsys.response_code_message(error_code)
            error_code.to_s + ' - ' + (msg.nil? ? 'Operación Aceptada' : msg)
          end

          def secure_payment?
            decode_Merchant_Parameters['Ds_SecurePayment'] == '1'
          end




          # Acknowledge the transaction.
          #
          # Validate the details provided by the gateway by ensuring that the signature
          # matches up with the details provided.
          #
          #
          # Example:
          #
          #   def notify
          #     notify = Redsys::Notification.new(request.query_parameters)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          #
          #
          def acknowledge(credentials = nil)
            return false if(params[:Ds_SignatureVersion].blank? ||
                params[:Ds_MerchantParameters].blank? ||
                params[:Ds_Signature].blank?)

            #HMAC_SHA256_V1
            return false if(params[:Ds_SignatureVersion] != credentials[:key_type])

            decodec = decode_Merchant_Parameters

            create_Signature = create_MerchantSignature_Notif(credentials[:secret_key])

            res=create_Signature.to_s.upcase == params[:Ds_Signature].to_s.upcase

            responseCode=decodec['Ds_Response'].to_i

            return false if (responseCode > 99 && responseCode!=900)
            res
          end



          def decode_Merchant_Parameters
            return nil if(params[:Ds_MerchantParameters].blank?)
            jsonrec = Base64.urlsafe_decode64(params[:Ds_MerchantParameters])
            JSON.parse(jsonrec)
          end



          private

          def create_MerchantSignature_Notif(key)
            #obtenemos el orderId.
            orderrec = (decode_Merchant_Parameters['Ds_Order'].blank?)? decode_Merchant_Parameters['DS_ORDER'] : decode_Merchant_Parameters['Ds_Order']

            key3des=des3key(key, orderrec)
            hmac=hmac(key3des,params[:Ds_MerchantParameters])
            Base64.urlsafe_encode64(hmac)
          end

          def des3key(key,message)
            block_length = 8
            cipher = OpenSSL::Cipher::Cipher.new('DES3')
            cipher.encrypt

            cipher.key = Base64.strict_decode64(key)
            # The OpenSSL default of an all-zeroes ("\\0") IV is used.
            cipher.padding = 0

            message += "\0" until message.bytesize % block_length == 0 # Pad with zeros

            output = cipher.update(message) + cipher.final
            output
          end

          def hmac(key,message)
            OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, message)
          end


          # Take the posted data and try to extract the parameters.
          #
          # Posted data can either be a parameters hash, XML string or CGI data string
          # of parameters.
          #
          def parse(post)
            if post.is_a?(Hash)
              post.each { |key, value|  params[key] = value }
            else
              for line in post.to_s.split('&')
                key, value = *line.scan( %r{^([A-Za-z0-9_.]+)\=(.*)$} ).flatten
                params[key] = CGI.unescape(value)
              end
            end
            @raw = post.inspect.to_s
          end


        end
      end
    end
  end
end


