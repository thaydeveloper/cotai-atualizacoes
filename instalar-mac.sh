#!/bin/zsh
# Instala o CotAI no Mac. No Terminal (Aplicativos > Utilitários > Terminal), cole e aperte Enter:
#
#   curl -fsSL https://raw.githubusercontent.com/thaydeveloper/cotai-atualizacoes/main/instalar-mac.sh | zsh
#
# Baixado pelo Terminal, o macOS não marca o CotAI como "baixado da internet": o "Iniciar CotAI"
# abre com dois cliques, sem o aviso de "desenvolvedor não identificado".
# Para testar: COTAI_ZIP (zip local), COTAI_PASTA, COTAI_CODIGO, COTAI_NAO_ABRIR=1, COTAI_SEM_ATALHO=1.
set -e

ENDERECO="https://github.com/thaydeveloper/cotai-atualizacoes/releases/latest/download"
PASTA="${COTAI_PASTA:-$HOME/CotAI}"
ZIP="${COTAI_ZIP:-$ENDERECO/CotAI.zip}"
INICIAR="$PASTA/Iniciar CotAI - Mac.command"

abrir() {
  [ -n "$COTAI_NAO_ABRIR" ] || open "$INICIAR"
}

echo
echo "Instalando o CotAI em $PASTA ..."
if [ -f "$PASTA/src/main.py" ]; then
  echo "O CotAI já está instalado aqui (e se atualiza sozinho). Abrindo..."
  abrir
  exit 0
fi

temporaria=$(mktemp -d)
trap 'rm -rf "$temporaria"' EXIT
if [ -f "$ZIP" ]; then
  cp "$ZIP" "$temporaria/CotAI.zip"
else
  curl -fSL --progress-bar "$ZIP" -o "$temporaria/CotAI.zip"
fi
ditto -x -k "$temporaria/CotAI.zip" "$temporaria/extraido"
[ -f "$temporaria/extraido/CotAI/src/main.py" ] || { echo "O pacote do CotAI veio incompleto. Tente de novo."; exit 1; }
mkdir -p "$(dirname "$PASTA")"
mv "$temporaria/extraido/CotAI" "$PASTA"
xattr -dr com.apple.quarantine "$PASTA" 2>/dev/null || true
chmod +x "$PASTA/iniciar.sh" "$INICIAR"

# Código de cliente (controle de uso): perguntado aqui, gravado no .env
codigo="${COTAI_CODIGO-}"
if [ -z "${COTAI_CODIGO+definido}" ] && [ -r /dev/tty ]; then
  printf "Código de cliente do CotAI (ex.: COTAI-ABCD-2345; Enter se ainda não tiver): " > /dev/tty
  read -r codigo < /dev/tty || codigo=""
fi
codigo=$(printf '%s' "$codigo" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9-')
cp "$PASTA/.env.example" "$PASTA/.env"
if [ -n "$codigo" ]; then
  if grep -q '^LICENCA=' "$PASTA/.env"; then
    sed -i '' "s/^LICENCA=.*/LICENCA=$codigo/" "$PASTA/.env"
  else
    printf '\n# Código de cliente do CotAI (controle de uso)\nLICENCA=%s\n' "$codigo" >> "$PASTA/.env"
  fi
fi

# Atalho na Mesa
if [ -z "$COTAI_SEM_ATALHO" ] && [ -d "$HOME/Desktop" ]; then
  ln -sf "$INICIAR" "$HOME/Desktop/Iniciar CotAI"
fi

echo
echo "Pronto! O CotAI está em $PASTA."
echo "Para ligar: dois cliques em \"Iniciar CotAI\" na Mesa. Ligando agora pela primeira vez..."
abrir
