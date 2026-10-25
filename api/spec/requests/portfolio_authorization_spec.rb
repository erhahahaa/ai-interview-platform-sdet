# frozen_string_literal: true

require 'rails_helper'

# F-002 | P1 | BUILT-WRONG | authz/tenant (object-level)
# Portfolio is looked up by bare id with no tenant scope; cross-tenant export.
RSpec.describe 'Portfolio authorization', type: :request do
  let!(:test_corp) do
    create(:organization, name: 'Test Corp', scheme: 'test-corp',
                          identifier: 'test-corp', host: 'localhost')
  end
  let!(:acme) do
    create(:organization, name: 'Acme Corp', scheme: 'acme',
                          identifier: 'acme', host: 'acme.local')
  end
  let!(:user) { create(:user, email: 'admin@example.com', password: 'password123', role: 'admin') }
  let!(:acme_assessment) do
    create(:assessment, name: 'Acme Role', tenant_id: acme.id, created_by: user.id)
  end
  let!(:acme_session) { create(:session, assessment: acme_assessment, tenant_id: acme.id) }
  let!(:acme_portfolio) do
    create(:portfolio, session: acme_session, generation_status: 'complete')
  end

  it 'does not allow exporting another tenant\'s portfolio by id' do
    post '/api/v1/auth/login',
         params: { email: 'admin@example.com', password: 'password123' },
         as: :json,
         headers: { 'X-Tenant-Scheme' => 'test-corp' }
    token = JSON.parse(response.body)['token']

    get "/api/v1/portfolios/#{acme_portfolio.id}/export", params: { format: 'json' },
        headers: auth_header(token)

    # Correct behaviour: cross-tenant portfolio must not be reachable.
    expect(response).to have_http_status(:not_found)
  end
end
