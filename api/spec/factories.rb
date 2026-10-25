# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    name       { 'Test Corp' }
    scheme     { 'test-corp' }
    identifier { 'test-corp' }
    host       { 'localhost' }
  end

  factory :user do
    email    { 'admin@example.com' }
    password { 'password123' }
    role     { 'admin' }
  end

  factory :assessment do
    tenant_id      { 1 }
    created_by     { 1 }
    name           { 'Assessment' }
    time_limit_min { 45 }
  end

  factory :session do
    assessment
    tenant_id { 1 }
  end

  factory :portfolio do
    session
    generation_status { 'pending' }
  end

  factory :vacancy do
    tenant_id  { 1 }
    created_by { 1 }
    role_title { 'Senior Engineer' }
  end

  factory :fit_gap_report do
    portfolio
    vacancy
    skill_comparisons do
      [{ 'skill_label' => 'React / Frontend Development',
         'skill_id' => 'SK-ENG-001',
         'candidate_level' => 3,
         'expected_level' => 3,
         'result' => 'match',
         'delta' => 0,
         'confidence' => 'high' }]
    end
  end
end
