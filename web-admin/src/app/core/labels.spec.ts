import {
  RECOMMENDATION_STATUS_LABELS,
  STAGE_LABELS,
  recommendationStatusLabel,
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
});
