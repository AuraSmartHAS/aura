#!/usr/bin/env bash
# Gera a entrega da Fase 7: os dois PDFs, o código-fonte, os scripts do banco e o ZIP.
#   docs/fase7/gerar-entrega.sh [LINK_DO_VIDEO] [LINK_DA_RUN]
# Os links substituem os marcadores nos dois HTML (que ficam no repositório já com eles).
# Saída em $OUT (padrão ~/Desktop): a pasta "AURA - FASE 7" e "AURA - FASE 7.zip".
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$DIR/../.." && pwd)"
OUT="${OUT:-$HOME/Desktop}/AURA - FASE 7"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
VIDEO="${1:-}"
RUN="${2:-}"

troca() { # marcador, link
  local v="${2//&/\\&}"  # & no lado direito do sed repetiria o marcador
  sed -i '' "s|$1|<a href=\"$v\">$v</a>|g" "$DIR/documentacao.html" "$DIR/slides.html"
}
[ -n "$VIDEO" ] && troca '«inserir link do YouTube (não listado)»' "$VIDEO"
[ -n "$RUN" ] && troca '«inserir link da run»' "$RUN"
grep -q '«inserir' "$DIR/documentacao.html" "$DIR/slides.html" && echo "Aviso: ainda há link a inserir nos HTML." >&2
git -C "$RAIZ" diff --quiet HEAD -- . ':!docs/fase7' \
  || echo "Aviso: há mudança sem commit fora de docs/fase7; codigo-fonte/ sai do último commit." >&2

rm -rf "$OUT" && mkdir -p "$OUT"
pdf() {
  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=10000 \
    --print-to-pdf="$OUT/$2" "file://$DIR/$1" 2>/dev/null
  [ -s "$OUT/$2" ] || { echo "Falhou ao gerar $2" >&2; exit 1; }
}
pdf documentacao.html "AURA - Documentacao Fase 7.pdf"
pdf slides.html "AURA - Apresentacao Fase 7.pdf"

mkdir -p "$OUT/codigo-fonte" "$OUT/banco-oracle/migrations-flyway"
git -C "$RAIZ" archive HEAD | tar -x -C "$OUT/codigo-fonte"
cp -R "$RAIZ/database/oracle/." "$OUT/banco-oracle/"
cp "$RAIZ"/backend-spring/src/main/resources/db/migration/oracle/*.sql "$OUT/banco-oracle/migrations-flyway/"

cat > "$OUT/Equipe e Links.txt" <<EOF
AURA - Fase 7 - Consolidando o Smart HAS

Vinícius Miranda Baptista     RM 555081
João Domingos Góes Filho      RM 564465
Pedro Henrique Arenas Negri   RM 554971
Júlia Alves Dias              RM 557151

Código:    https://github.com/AuraSmartHAS/aura (também em codigo-fonte/)
Esteira:   https://github.com/AuraSmartHAS/aura/actions/workflows/entrega-oracle.yml
Run:       ${RUN:-(inserir link da run)}
Vídeo:     ${VIDEO:-(inserir link do YouTube)}

banco-oracle/instalar-tudo.sql instala tudo num usuário vazio (SQL Developer, F5).
EOF

(cd "$(dirname "$OUT")" && rm -f "AURA - FASE 7.zip" && zip -qr "AURA - FASE 7.zip" "AURA - FASE 7")
du -sh "$OUT" "$(dirname "$OUT")/AURA - FASE 7.zip"
