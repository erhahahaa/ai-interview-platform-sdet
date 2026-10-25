# frozen_string_literal: true

require 'rails_helper'

# F-001 | P1 | BUILT-WRONG | auth/tenant
# Login mints a cross-tenant JWT from the attacker-controlled X-Tenant-Scheme header.
RSpec.describe 'Tenant isolation at login', type: :request do
  let!(:test_corp) do
    create(:organization, name: 'Test Corp', scheme: 'test-corp',
                          identifier: 'test-corp', host: 'localhost')
  end
  let!(:acme) do
    create(:organization, name: 'Acme Corp', scheme: 'acme',
                          identifier: 'acme', host: 'acme.local')
  end
  let!(:user) do
    create(:user, email: 'admin@example.com', password: 'password123', role: 'admin',
                  organization: test_corp)
  end
  let!(:acme_assessment) do
    create(:assessment, name: 'Acme Secret Project', tenant_id: acme.id, created_by: user.id)
  end

  it 'does not let a user self-select another tenant via X-Tenant-Scheme' do
    post '/api/v1/auth/login',
         params: { email: 'admin@example.com', password: 'password123' },
         as: :json,
         headers: { 'X-Tenant-Scheme' => 'acme' }
    token = JSON.parse(response.body)['token']

    get '/api/v1/assessments', headers: auth_header(token)

    expect(response).to have_http_status(:ok)
    names = JSON.parse(response.body)['assessments'].map { |a| a['name'] }
    # The admin belongs to test-corp, so they must NOT see acme's assessment.
    expect(names).not_to include('Acme Secret Project')
  end
end
