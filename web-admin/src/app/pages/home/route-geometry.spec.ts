import { projectRoute, toPath } from './route-geometry';

describe('route-geometry', () => {
  const coords: [number, number][] = [
    [-46.64, -23.55],
    [-46.6462, -23.5527],
    [-46.656, -23.561],
  ];

  it('mantém todos os pontos dentro do quadro com a folga pedida', () => {
    const { points } = projectRoute(coords, 640, 260, 40);
    for (const [x, y] of points) {
      expect(x).toBeGreaterThanOrEqual(40 - 1e-6);
      expect(x).toBeLessThanOrEqual(600 + 1e-6);
      expect(y).toBeGreaterThanOrEqual(40 - 1e-6);
      expect(y).toBeLessThanOrEqual(220 + 1e-6);
    }
  });

  it('preserva o aspecto (escala única) e desenha o norte pra cima', () => {
    const square: [number, number][] = [
      [-46.65, -23.56],
      [-46.64, -23.56],
      [-46.64, -23.55],
    ];
    const { points } = projectRoute(square, 640, 260, 40);

    // 0,01° de longitude encolhe pelo cos da latitude; 0,01° de latitude fica inteiro
    const dx = Math.abs(points[1][0] - points[0][0]);
    const dy = Math.abs(points[2][1] - points[1][1]);
    expect(dx).toBeLessThan(dy);
    expect(dx / dy).toBeCloseTo(Math.cos((-23.555 * Math.PI) / 180), 2);

    // latitude maior (mais ao norte) aparece mais alta na tela
    expect(points[2][1]).toBeLessThan(points[1][1]);
  });

  it('projeta a posição do entregador no mesmo enquadramento da rota', () => {
    const { points, project } = projectRoute(coords, 640, 260, 40);
    expect(project(coords[0])).toEqual(points[0]);
    expect(project(coords[2])).toEqual(points[2]);
  });

  it('toPath desenha M seguido de L com uma casa decimal', () => {
    expect(toPath([[10, 20], [30.44, 40]])).toBe('M 10.0,20.0 L 30.4,40.0');
  });
});
