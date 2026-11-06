$ErrorActionPreference = 'Stop'
$console = Join-Path (Split-Path -Parent $PSScriptRoot) 'LarpConsole.html'
Invoke-Item -LiteralPath $console
