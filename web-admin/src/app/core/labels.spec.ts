import {
  RECOMMENDATION_STATUS_LABELS,
  RISK_TAG_LABELS,
  SCORE_FACTOR_LABELS,
  STAGE_LABELS,
  recommendationStatusLabel,
  riskTagLabel,
  stageLabel,
} from './labels';

describe('labels', () => {
  it('cobre os 6 estágios do pedido, em português', () => {
    const stages = ['approved', 'sourcing', 'in_route', 'delivered', 'installed', 'returned'];
    for (const stage of stages) {
      expect(STAGE_LABELS[stage]).withContext(stage).toBeTruthy();
      expect(STAGE_LABELS[stage]).withContext(stage).not.toContain('_');
    }
    expect(stageLabel('in_route')).toBe('Em rota');
  });

  it('cobre os 3 status da recomendação, em português', () => {
    const statuses = ['recommended', 'approved', 'rejected'];
    for (const status of statuses) {
      expect(RECOMMENDATION_STATUS_LABELS[status]).withContext(status).toBeTruthy();
    }
    expect(recommendationStatusLabel('recommended')).toBe('Recomendado');
  });

  it('código desconhecido aparece cru em vez de sumir da tela', () => {
    expect(stageLabel('warehouse_hold')).toBe('warehouse_hold');
    expect(recommendationStatusLabel('expired')).toBe('expired');
  });

  it('nenhuma tag de risco do catálogo sai em código cru', () => {
    for (const [tag, label] of Object.entries(RISK_TAG_LABELS)) {
      expect(label).withContext(tag).not.toContain('_');
    }
    expect(riskTagLabel('fall_bathroom')).toBe('Queda no banheiro');
    expect(riskTagLabel(null)).toBe('');
    expect(riskTagLabel('tag_nova')).toBe('tag_nova');
  });

  it('cobre os 10 fatores do escore explicável', () => {
    expect(Object.keys(SCORE_FACTOR_LABELS).length).toBe(10);
  });
});
