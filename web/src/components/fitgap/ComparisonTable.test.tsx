import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import ComparisonTable from './ComparisonTable';
import type { SkillComparison } from '@/types';

describe('ComparisonTable', () => {
  it('renders the required level from the API expected_level field', () => {
    // The API emits `expected_level` per comparison (see api fit_gap engine).
    const comparisons = [
      {
        skill_label: 'React / Frontend Development',
        expected_level: 3,
        candidate_level: 2,
        result: 'gap',
        delta: -1,
      },
    ] as unknown as SkillComparison[];

    render(<ComparisonTable comparisons={comparisons} />);

    // The "Required" column must show "L3". It is currently blank because the
    // component reads `required_level` instead of `expected_level`.
    expect(screen.getByText('L3')).toBeInTheDocument();
  });
});
