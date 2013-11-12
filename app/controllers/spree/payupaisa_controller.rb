require 'digest'
module Spree
  class PayupaisaController < StoreController
    def express
      items = current_order.line_items.map do |item|
        {
          :Name => item.product.name,
          :Quantity => item.quantity,
          :Amount => {
            :currencyID => current_order.currency,
            :value => item.price
          },
          :ItemCategory => "Physical"
        }
      end

      tax_adjustments = current_order.adjustments.tax
      shipping_adjustments = current_order.adjustments.shipping

      current_order.adjustments.eligible.each do |adjustment|
        next if (tax_adjustments + shipping_adjustments).include?(adjustment)
        items << {
          :Name => adjustment.label,
          :Quantity => 1,
          :Amount => {
            :currencyID => current_order.currency,
            :value => adjustment.amount
          }
        }
      end

      items.reject! do |item|
        item[:Amount][:value].zero?
      end

      begin
        merchant_key = "JBZaLc"
        merchant_salt = "GQs7yium"
        base_url = "https://test.payu.in/_payment"
        error = 0
        hashString = hash_calc '', ''

        rndm = Random.new.rand(2000000000000..300000000000000000000000).to_s
        txnid = hash_calc('256',rndm)[0,20]
        udf2 = txnid   
        hashSequence = "key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5|udf6|udf7|udf8|udf9|udf10"
        hashString = merchant_key +"|"+ "12131313131313133" + "|" + current_order.total.to_s + "|" + "Gifts Anytime -Gifts item" +"|" 
        hashString += current_order.bill_address.try(:full_name) +"|" + "sales@giftsanytime.com" + "|" + "" + "|"+ udf2.to_s   
        hashString += "|||||||||" + merchant_salt
        hash = hash_calc('512', hashString)
        puts "In calculation hashString"
        puts hashString 
        redirect_to  base_url, status:307
      end
    end

    def confirm
      order = current_order
      order.payments.create!({
        :source => Spree::PayupaisaExpressCheckout.create({
          :token => params[:token],
          :payer_id => params[:PayerID]
        } ),
        :amount => order.total,
        :payment_method => payment_method
      } )
      order.next
      if order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        redirect_to order_path(order, :token => order.token)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    def cancel
      flash[:notice] = "Don't want to use Payupaisa? No problems."
      redirect_to checkout_state_path(current_order.state)
    end

    private

    def payment_method
      Spree::PaymentMethod.find(params[:payment_method_id])
    end

    def provider
      payment_method.provider
    end

    def payment_details items
      item_sum = items.sum { |i| i[:Quantity] * i[:Amount][:value] }
      if item_sum.zero?
        # Payupaisa does not support no items or a zero dollar ItemTotal
        # This results in the order summary being simply "Current purchase"
        {
          :OrderTotal => {
            :currencyID => current_order.currency,
            :value => current_order.total
          }
        }
      else
        {
          :OrderTotal => {
            :currencyID => current_order.currency,
            :value => current_order.total
          },
          :ItemTotal => {
            :currencyID => current_order.currency,
            :value => item_sum
          },
          :ShippingTotal => {
            :currencyID => current_order.currency,
            :value => current_order.ship_total
          },
          :TaxTotal => {
            :currencyID => current_order.currency,
            :value => current_order.tax_total
          },
          :ShipToAddress => address_options,
          :PaymentDetailsItem => items,
          :ShippingMethod => "Shipping Method Name Goes Here",
          :PaymentAction => "Sale"
        }
      end
    end

    def address_options
      {
        :Name => current_order.bill_address.try(:full_name),
        :Street1 => current_order.bill_address.address1,
        :Street2 => current_order.bill_address.address2,
        :CityName => current_order.bill_address.city,
        # :phone => current_order.bill_address.phone,
        :StateOrProvince => current_order.bill_address.state_text,
        :Country => current_order.bill_address.country.iso,
        :PostalCode => current_order.bill_address.zipcode
      }
    end
     
    def hash_calc (type ,cleartext)
        if '256' == type 
          sha = Digest::SHA256.new 
        else 
          sha = Digest::SHA512.new 
        end  
        sha.reset
        sha.update cleartext
        return sha.digest(cleartext).unpack('H*')
    end 
  end 
end
