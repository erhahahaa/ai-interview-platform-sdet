# frozen_string_literal: true

require 'rails_helper'

# Direct coverage of the fit/gap engine (F-003: expected_level + is_override).
RSpec.describe FitGap::Engine do
  let!(:org) do
    create(:organization, name: 'Test Corp', scheme: 'test-corp',
                          identifier: 'test-corp', host: 'localhost')
  end
  let!(:assessment) { create(:assessment, tenant_id: org.id, created_by: 1) }
  let!(:session) { create(:session, assessment:, tenant_id: org.id) }
  let!(:portfolio) { create(:portfolio, session:, generation_status: 'complete') }
  let!(:vacancy) { create(:vacancy, tenant_id: org.id, created_by: 1) }

  let(:gemini_stub) do
    double('gemini', generate_content: { 'culture_narrative' => 'culture', 'overall_narrative' => 'overall' })
  end

  it 'emits expected_level, applies the override, and flags is_override' do
    skill = portfolio.portfolio_skills.create!(
      skill_label: 'React / Frontend Development',
      ai_level: 3, ai_confidence: 'medium', competency_summary: 'summary', evidence: []
    )
    vacancy.vacancy_skills.create!(skill_label: 'React / Frontend Development', expected_level: 4)
    skill.create_assessor_override!(ai_level: 3, override_level: 5, overridden_by: 1)

    report = FitGap::Engine.new(portfolio:, vacancy:, gemini_client: gemini_stub).call

    comparison = report.skill_comparisons.first
    expect(comparison['skill_label']).to eq('React / Frontend Development')
    expect(comparison['expected_level']).to eq(4)
    expect(comparison['candidate_level']).to eq(5) # override applied
    expect(comparison['is_override']).to be(true)
    expect(comparison['result']).to eq('exceed')
    expect(comparison['delta']).to eq(1)
  end
end
