# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Assessment time limit boundary', type: :request do
  let!(:org) do
    create(:organization, name: 'Test Corp', scheme: 'test-corp',
                          identifier: 'test-corp', host: 'localhost')
  end
  let!(:user) do
    create(:user, email: 'admin@example.com', password: 'password123', role: 'admin',
                  organization: org)
  end

  it 'rejects an unsupported time_limit_min' do
    post '/api/v1/auth/login',
         params: { email: 'admin@example.com', password: 'password123' }, as: :json
    token = JSON.parse(response.body)['token']

    post '/api/v1/assessments',
         params: { assessment: { name: 'Boundary Test', time_limit_min: 42, language: 'en' } },
         as: :json,
         headers: auth_header(token)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
