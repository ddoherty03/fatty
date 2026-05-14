# frozen_string_literal: true

# These can be used to add "roles" to strings so that they can be styled
# according to the theme.
class String
  def fatty_good
    { text: self, role: :good }
  end

  def fatty_info
    { text: self, role: :info }
  end

  def fatty_warn
    { text: self, role: :warn }
  end

  def fatty_error
    { text: self, role: :error }
  end
end
