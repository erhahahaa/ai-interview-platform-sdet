# frozen_string_literal: true

module RequestHelpers
  def auth_header(token)
    { 'Authorization' => "Bearer #{token}" }
  end
end
