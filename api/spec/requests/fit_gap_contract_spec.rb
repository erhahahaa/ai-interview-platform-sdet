# frozen_string_literal: true

require 'rails_helper'

# F-003 | P1 | BUILT-WRONG | seam / data integrity (contract side)
# The API must emit `expected_level` in each skill comparison. The web bug reads
# `required_level`; this spec pins the correct field name on the API contract.
RSpec.describe 'Fit/gap report contract', type: :request do
  let!(:org) do
    create(:organization, name: 'Test Corp', scheme: 'test-corp',
                          identifier: 'test-corp', host: 'localhost')
  end
  let!(:user) { create(:user, email: 'admin@example.com', password: 'password123', role: 'admin') }
  let!(:assessment) { create(:assessment, tenant_id: org.id, created_by: user.id) }
  let!(:session) { create(:session, assessment:, tenant_id: org.id) }
  let!(:portfolio) { create(:portfolio, session:, generation_status: 'complete') }
  let!(:vacancy) { create(:vacancy, tenant_id: org.id, created_by: user.id) }
  let!(:report) { create(:fit_gap_report, portfolio:, vacancy:) }

  it 'emits expected_level (not required_level) in each comparison' do
    post '/api/v1/auth/login',
         params: { email: 'admin@example.com', password: 'password123' },
         as: :json,
         headers: { 'X-Tenant-Scheme' => 'test-corp' }
    token = JSON.parse(response.body)['token']

    get "/api/v1/portfolios/#{portfolio.id}/fitgap/#{vacancy.id}", headers: auth_header(token)

    expect(response).to have_http_status(:ok)
    comparison = JSON.parse(response.body)['report']['skill_comparisons'].first
    expect(comparison).to have_key('expected_level')
    expect(comparison).not_to have_key('required_level')
  end
end
