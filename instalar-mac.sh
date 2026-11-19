#!/bin/zsh
# Instala o CotAI no Mac. No Terminal (Aplicativos > Utilitários > Terminal), cole e aperte Enter:
#
#   curl -fsSL https://raw.githubusercontent.com/thaydeveloper/cotai-atualizacoes/main/instalar-mac.sh | zsh
#
# Baixado pelo Terminal, o macOS não marca o CotAI como "baixado da internet": o "Iniciar CotAI"
# abre com dois cliques, sem o aviso de "desenvolvedor não identificado".
# Para testar: COTAI_ZIP (zip local), COTAI_PASTA, COTAI_CODIGO, COTAI_CHAVE_IA, COTAI_NAO_ABRIR=1, COTAI_SEM_ATALHO=1.
set -e

ENDERECO="https://github.com/thaydeveloper/cotai-atualizacoes/releases/latest/download"
PASTA="${COTAI_PASTA:-$HOME/CotAI}"
ZIP="${COTAI_ZIP:-$ENDERECO/CotAI.zip}"
INICIAR="$PASTA/Iniciar CotAI - Mac.command"

abrir() {
  [ -n "$COTAI_NAO_ABRIR" ] || open "$INICIAR"
}

echo
ja_instalado=""
if [ -f "$PASTA/src/main.py" ]; then
  ja_instalado=1
  echo "O CotAI já está instalado em $PASTA: atualizando e consertando os arquivos do programa."
  echo "O .env (código e chave), as planilhas e a conexão do WhatsApp ficam como estão."
else
  echo "Instalando o CotAI em $PASTA ..."
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
if [ -n "$ja_instalado" ]; then
  # Só os arquivos do programa: o pacote não traz .env, planilhas, histórico nem a sessão do WhatsApp
  ditto "$temporaria/extraido/CotAI" "$PASTA"
else
  mkdir -p "$(dirname "$PASTA")"
  mv "$temporaria/extraido/CotAI" "$PASTA"
fi
xattr -dr com.apple.quarantine "$PASTA" 2>/dev/null || true
chmod +x "$PASTA/iniciar.sh" "$INICIAR"

# Código de cliente (controle de uso): perguntado aqui, gravado no .env
codigo="${COTAI_CODIGO-}"
if [ -z "${COTAI_CODIGO+definido}" ] && [ -z "$ja_instalado" ] && [ -r /dev/tty ]; then
  printf "Código de cliente do CotAI (ex.: COTAI-ABCD-2345; Enter se ainda não tiver): " > /dev/tty
  read -r codigo < /dev/tty || codigo=""
fi
codigo=$(printf '%s' "$codigo" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9-')
[ -f "$PASTA/.env" ] || cp "$PASTA/.env.example" "$PASTA/.env"
if [ -n "$codigo" ]; then
  if grep -q '^LICENCA=' "$PASTA/.env"; then
    sed -i '' "s/^LICENCA=.*/LICENCA=$codigo/" "$PASTA/.env"
  else
    printf '\n# Código de cliente do CotAI (controle de uso)\nLICENCA=%s\n' "$codigo" >> "$PASTA/.env"
  fi
fi

# Chave da IA (Anthropic) do próprio cliente: com ela, toda lista passa pela revisão da IA antes da planilha
chave="${COTAI_CHAVE_IA-}"
if [ -z "${COTAI_CHAVE_IA+definido}" ] && [ -z "$ja_instalado" ] && [ -r /dev/tty ]; then
  printf "Chave da IA da Anthropic (começa com sk-ant-; Enter para pular): " > /dev/tty
  read -rs chave < /dev/tty || chave=""
  printf '\n' > /dev/tty
fi
chave=$(printf '%s' "$chave" | tr -cd 'A-Za-z0-9_-')
if [ -n "$chave" ]; then
  sed -i '' "s/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=$chave/; s/^IA_LEITURA=.*/IA_LEITURA=sim/" "$PASTA/.env"
fi

# Atalho na Mesa
if [ -z "$COTAI_SEM_ATALHO" ] && [ -d "$HOME/Desktop" ]; then
  ln -sf "$INICIAR" "$HOME/Desktop/Iniciar CotAI"
fi

echo
echo "Pronto! O CotAI está em $PASTA."
echo "Para ligar: dois cliques em \"Iniciar CotAI\" na Mesa. Ligando agora pela primeira vez..."
abrir
