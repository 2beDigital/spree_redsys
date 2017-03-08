Spree::Order.class_eval do

  # Order number starts with R (it's not allowed by redsys). We override the method generate number
  # 12 / A- N.
  # Mandatory. The first 4 digits must be numeric , for the remaining digits only use the following ASCII characters
  # (0..9), ('A'..'Z'),  ('a'..'z')
  def generate_number(options = {})
    possible = (0..9).to_a
    possible_with_letters = possible + ('A'..'Z').to_a + ('a'..'z').to_a if options[:letters]

    self.number ||= loop do
      random = "#{(0...12).map { possible.shuffle.first }.join}"
      if options[:letters]
        random = "#{(0...9).map { possible.shuffle.first }.join}"
        random += "#{(0...3).map { possible_with_letters.shuffle.first }.join}"
      end
      break random unless self.class.exists?(number: random)
    end
  end


end