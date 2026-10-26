# frozen_string_literal: true

require 'rails_helper'

# Error / edge-state coverage (Task 1 "done when": "error/edge states are covered").
RSpec.describe 'Error and edge handling', type: :request do
  let!(:org) do
    create(:organization, name: 'Test Corp', scheme: 'test-corp',
                          identifier: 'test-corp', host: 'localhost')
  end
  let!(:user) do
    create(:user, email: 'admin@example.com', password: 'password123', role: 'admin',
                  organization: org)
  end

  def login_token
    post '/api/v1/auth/login',
         params: { email: 'admin@example.com', password: 'password123' }, as: :json
    JSON.parse(response.body)['token']
  end

  it 'rejects a protected endpoint with no token' do
    get '/api/v1/assessments'
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects an unsupported time_limit_min' do
    post '/api/v1/assessments',
         params: { assessment: { name: 'X', time_limit_min: 42 } },
         as: :json, headers: auth_header(login_token)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects an assessment with a missing name' do
    post '/api/v1/assessments',
         params: { assessment: { time_limit_min: 45 } },
         as: :json, headers: auth_header(login_token)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'returns 404 for a missing assessment' do
    get '/api/v1/assessments/999999', headers: auth_header(login_token)
    expect(response).to have_http_status(:not_found)
  end

  it 'returns 404 for a missing assessment in another tenant' do
    other = create(:organization, name: 'Acme', scheme: 'acme', identifier: 'acme', host: 'acme.local')
    acme_assessment = create(:assessment, name: 'Acme Role', tenant_id: other.id, created_by: user.id)
    get "/api/v1/assessments/#{acme_assessment.id}", headers: auth_header(login_token)
    # The assessment belongs to another tenant, so it must not be reachable.
    expect(response).to have_http_status(:not_found)
  end
end
