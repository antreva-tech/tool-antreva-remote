[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

git submodule update --init --recursive
git -C upstream/rustdesk submodule update --init --recursive

Write-Output "Upstream RustDesk and RustDesk Server sources are initialized."
