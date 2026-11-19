# Instala o CotAI no Windows. Abra o PowerShell (tecla Windows, digite PowerShell, Enter), cole e aperte Enter:
#
#   irm https://raw.githubusercontent.com/thaydeveloper/cotai-atualizacoes/main/instalar-windows.ps1 | iex
#
# Baixado pelo PowerShell, o Windows nao marca o CotAI como "baixado da internet": o SmartScreen
# nao bloqueia o "Iniciar CotAI". (Sem acentos neste arquivo: o PowerShell antigo le errado.)
# Para testar: COTAI_ZIP (zip local), COTAI_PASTA, COTAI_CODIGO, COTAI_CHAVE_IA, COTAI_NAO_ABRIR=1, COTAI_SEM_ATALHO=1.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$endereco = 'https://github.com/thaydeveloper/cotai-atualizacoes/releases/latest/download'
$pasta = if ($env:COTAI_PASTA) { $env:COTAI_PASTA } else { Join-Path $env:USERPROFILE 'CotAI' }
$zip = if ($env:COTAI_ZIP) { $env:COTAI_ZIP } else { "$endereco/CotAI.zip" }
$iniciar = Join-Path $pasta 'Iniciar CotAI - Windows.bat'

function Abrir-CotAI {
  if (-not $env:COTAI_NAO_ABRIR) { Start-Process -FilePath $iniciar -WorkingDirectory $pasta }
}

Write-Host ''
Write-Host "Instalando o CotAI em $pasta ..."
if (Test-Path (Join-Path $pasta 'src\main.py')) {
  Write-Host 'O CotAI ja esta instalado aqui (e se atualiza sozinho). Abrindo...'
  Abrir-CotAI
  return
}

$temporaria = Join-Path ([IO.Path]::GetTempPath()) ('cotai-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temporaria | Out-Null
try {
  $arquivo = Join-Path $temporaria 'CotAI.zip'
  if (Test-Path $zip) {
    Copy-Item $zip $arquivo
  } else {
    Write-Host 'Baixando o CotAI...'
    Invoke-WebRequest -Uri $zip -OutFile $arquivo -UseBasicParsing
  }
  Expand-Archive -Path $arquivo -DestinationPath $temporaria -Force
  if (-not (Test-Path (Join-Path $temporaria 'CotAI\src\main.py'))) { throw 'o pacote do CotAI veio incompleto; tente de novo' }
  $mae = Split-Path $pasta -Parent
  if ($mae) { New-Item -ItemType Directory -Force -Path $mae | Out-Null }
  Move-Item (Join-Path $temporaria 'CotAI') $pasta
} finally {
  Remove-Item $temporaria -Recurse -Force -ErrorAction SilentlyContinue
}
# Se algum arquivo tiver a marca "baixado da internet", ela sai
Get-ChildItem $pasta -Recurse -File | Unblock-File

# Codigo de cliente (controle de uso): perguntado aqui, gravado no .env
if ($null -ne $env:COTAI_CODIGO) { $codigo = $env:COTAI_CODIGO }
else { $codigo = Read-Host 'Codigo de cliente do CotAI (ex.: COTAI-ABCD-2345; Enter se ainda nao tiver)' }
$codigo = "$codigo".ToUpper() -replace '[^A-Z0-9-]', ''
$arquivoEnv = Join-Path $pasta '.env'
Copy-Item (Join-Path $pasta '.env.example') $arquivoEnv
if ($codigo) {
  $semBom = New-Object System.Text.UTF8Encoding $false
  $texto = [IO.File]::ReadAllText($arquivoEnv)
  if ($texto -match '(?m)^LICENCA=') { $texto = $texto -replace '(?m)^LICENCA=.*$', "LICENCA=$codigo" }
  else { $texto += "`r`n# Codigo de cliente do CotAI (controle de uso)`r`nLICENCA=$codigo`r`n" }
  [IO.File]::WriteAllText($arquivoEnv, $texto, $semBom)
}

# Chave da IA (Anthropic) do proprio cliente: com ela, toda lista passa pela revisao da IA antes da planilha
if ($null -ne $env:COTAI_CHAVE_IA) { $chave = $env:COTAI_CHAVE_IA }
else {
  $segura = Read-Host 'Chave da IA da Anthropic (comeca com sk-ant-; Enter para pular)' -AsSecureString
  $chave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura))
}
$chave = "$chave" -replace '[^A-Za-z0-9_-]', ''
if ($chave) {
  $semBom = New-Object System.Text.UTF8Encoding $false
  $texto = [IO.File]::ReadAllText($arquivoEnv)
  $texto = $texto -replace '(?m)^ANTHROPIC_API_KEY=.*$', "ANTHROPIC_API_KEY=$chave"
  $texto = $texto -replace '(?m)^IA_LEITURA=.*$', 'IA_LEITURA=sim'
  [IO.File]::WriteAllText($arquivoEnv, $texto, $semBom)
}

# Atalho na Area de Trabalho
if (-not $env:COTAI_SEM_ATALHO) {
  $mesa = [Environment]::GetFolderPath('Desktop')
  $atalho = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $mesa 'Iniciar CotAI.lnk'))
  $atalho.TargetPath = $iniciar
  $atalho.WorkingDirectory = $pasta
  $atalho.Save()
}

Write-Host ''
Write-Host "Pronto! O CotAI esta em $pasta."
Write-Host 'Para ligar: dois cliques em "Iniciar CotAI" na Area de Trabalho. Ligando agora pela primeira vez...'
Abrir-CotAI
