# Dot-source in the project root to use a project-local official toolchain.
# This script does not install or download anything.
$taskMoonHome = Join-Path $PSScriptRoot '..\release-local\toolchain'
if (!(Test-Path -LiteralPath (Join-Path $taskMoonHome 'bin\moon.exe'))) {
  throw 'Install the documented compatible toolchain, or place it in release-local/toolchain.'
}
$env:MOON_HOME = (Resolve-Path -LiteralPath $taskMoonHome).Path
$env:PATH = "$env:MOON_HOME\bin;$env:PATH"
