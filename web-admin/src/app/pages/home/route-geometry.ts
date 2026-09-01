/**
 * Projeção da rota GeoJSON (pares [lng, lat]) para coordenadas de SVG. Numa área de ~2 km a
 * projeção linear com correção de aspecto (longitude comprimida pelo cosseno da latitude média)
 * tem erro invisível a olho — é o que dispensa Leaflet, tiles e chave de API: o mapa da entrega
 * fala só com o localhost.
 */
export interface ProjectedRoute {
  points: [number, number][];
  /** Projeta qualquer par [lng, lat] no mesmo enquadramento da rota (ex.: o entregador). */
  project: (position: [number, number]) => [number, number];
}

export function projectRoute(
  coordinates: [number, number][],
  width: number,
  height: number,
  padding: number,
): ProjectedRoute {
  const lats = coordinates.map((c) => c[1]);
  const latMid = (Math.min(...lats) + Math.max(...lats)) / 2;
  const aspect = Math.cos((latMid * Math.PI) / 180);

  const xs = coordinates.map((c) => c[0] * aspect);
  const minX = Math.min(...xs);
  const minLat = Math.min(...lats);
  const spanX = Math.max(...xs) - minX || 1e-9;
  const spanLat = Math.max(...lats) - minLat || 1e-9;

  // escala única nos dois eixos: o mapa não entorta a geografia pra preencher o quadro
  const scale = Math.min((width - 2 * padding) / spanX, (height - 2 * padding) / spanLat);
  const offsetX = (width - spanX * scale) / 2;
  const offsetY = (height - spanLat * scale) / 2;

  const project = ([lng, lat]: [number, number]): [number, number] => [
    offsetX + (lng * aspect - minX) * scale,
    // eixo invertido: latitude cresce pra cima, y de tela cresce pra baixo
    height - offsetY - (lat - minLat) * scale,
  ];

  return { points: coordinates.map(project), project };
}

/** "M x,y L x,y …" com uma casa decimal — suficiente num viewBox de 640. */
export function toPath(points: [number, number][]): string {
  return points
    .map(([x, y], i) => `${i === 0 ? 'M' : 'L'} ${x.toFixed(1)},${y.toFixed(1)}`)
    .join(' ');
}
