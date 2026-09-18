#!/usr/bin/env bash
# convert-furniture.sh — converte móveis SWF -> .nitro para o client Nitro.
#
# Por que existe: o nitro-converter resolve mobília como
#   dcr/hof_furni/<revision>/<classname>.swf  (USES_REVISION=true),
# mas a maioria dos packs SWF entrega os arquivos ACHATADOS em dcr/hof_furni/.
# Sem a árvore por revisão, toda conversão falha com ENOENT e a pasta
# bundled/furniture do client fica vazia -> sala sem móveis (placeholders).
#
# Idempotente: pula se já existir qualquer *.nitro em bundled/furniture.
# Pode ser executado manualmente:
#   scripts/convert-furniture.sh /caminho/para/habbo-dev
# ou via systemd (habbo-asset-convert.service, no boot).
#
# Requisitos dentro de habboRoot:
#   - nitro-converter/ com dist/Main.js (rode `yarn build` uma vez)
#   - swf-assets/dcr/hof_furni/ (packs SWF) + swf-assets/gamedata/furnidata.xml

set -euo pipefail

ROOT="${1:-${HABBO_ROOT:-/home/gipsydanger/projects/habbo-dev}}"
CLIENT_BUNDLED="$ROOT/cms/public/client/bundled"
CONV="$ROOT/nitro-converter"
SWF="$ROOT/swf-assets/dcr/hof_furni"
REV="$SWF-rev"
FURNIDATA="$ROOT/swf-assets/gamedata/furnidata.xml"

# 1) Idempotência: já convertido?
if ls "$CLIENT_BUNDLED/furniture/"*.nitro >/dev/null 2>&1; then
  echo "furniture já convertido ($(ls "$CLIENT_BUNDLED/furniture/"*.nitro | wc -l) arquivos) — nada a fazer"
  exit 0
fi

# 2) Pré-requisitos
[ -x "$(command -v node)" ] || { echo "ERRO: node não encontrado no PATH"; exit 1; }
[ -f "$CONV/dist/Main.js" ] || { echo "ERRO: $CONV/dist/Main.js ausente — rode 'yarn build' dentro de nitro-converter"; exit 1; }
[ -f "$CONV/configuration.json" ] || { echo "ERRO: $CONV/configuration.json ausente — copie de configuration.json.example e ajuste os paths"; exit 1; }
[ -d "$SWF" ] || { echo "swf-assets/dcr/hof_furni ausente — nada a converter (client usará placeholders)"; exit 0; }
[ -f "$FURNIDATA" ] || { echo "ERRO: $FURNIDATA ausente"; exit 1; }

# 3) Árvore por revisão (hardlinks, sem duplicar 300MB+)
if [ ! -d "$REV" ]; then
  echo "Montando árvore de revisão em $REV ..."
  mkdir -p "$REV"
  awk -F'"' '
    /<furnitype / { cls = $4; next }
    /<revision>/  { if (match($0, /[0-9]+/)) print cls, substr($0, RSTART, RLENGTH) }
  ' "$FURNIDATA" | while read -r cls rev; do
    base="${cls%%\**}"          # remove variantes *1, *2, ...
    if [ -f "$SWF/$base.swf" ]; then
      mkdir -p "$REV/$rev"
      [ -e "$REV/$rev/$cls.swf" ] || ln "$SWF/$base.swf" "$REV/$rev/$cls.swf"
    fi
  done
  echo "  -> $(find "$REV" -name '*.swf' | wc -l) SWFs linkados em $(find "$REV" -mindepth 1 -maxdepth 1 -type d | wc -l) revisões"
fi

# 4) Garante a config do converter (convert.furniture=1 + árvore por revisão)
sed -i 's/"convert\.furniture": *"[01]"/"convert.furniture": "1"/' "$CONV/configuration.json"
sed -i "s|\"dynamic\.download\.furniture\.url\": *\"[^\"]*\"|\"dynamic.download.furniture.url\": \"$REV/%revision%/%className%.swf\"|" "$CONV/configuration.json"

# 5) Converte (7.7k móveis — pode levar 15+ min em máquinas lentas)
echo "Convertendo furniture (node dist/Main.js) ..."
( cd "$CONV" && node dist/Main.js ) 2>&1 | tail -5

# 6) Copia os bundles para o client (não sobrescreve existentes)
mkdir -p "$CLIENT_BUNDLED"/{furniture,figure,effect,pet,generic}
for kind in furniture figure effect pet; do
  if [ -d "$CONV/assets/bundled/$kind" ]; then
    cp -n "$CONV/assets/bundled/$kind/"*.nitro "$CLIENT_BUNDLED/$kind/" 2>/dev/null || true
  fi
done
if [ -d "$ROOT/default-assets/bundled/generic" ]; then
  cp -n "$ROOT/default-assets/bundled/generic/"*.nitro "$CLIENT_BUNDLED/generic/" 2>/dev/null || true
fi

echo "OK: $(ls "$CLIENT_BUNDLED/furniture/"*.nitro | wc -l) móveis prontos em $CLIENT_BUNDLED/furniture/"