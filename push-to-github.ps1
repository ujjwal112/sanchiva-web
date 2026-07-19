# Push Sanchiva web app to GitHub
# Usage:
#   1. Create empty repo at https://github.com/new (name e.g. sanchiva-web)
#   2. Run:  .\push-to-github.ps1 -Username YOUR_GITHUB_USERNAME -Repo sanchiva-web

param(
  [Parameter(Mandatory = $true)]
  [string]$Username,
  [string]$Repo = "sanchiva-web"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path .git)) {
  Write-Error "Not a git repo. Run from project root."
}

$remote = "https://github.com/$Username/$Repo.git"
Write-Host "Remote: $remote" -ForegroundColor Cyan

$existing = git remote 2>$null
if ($existing -match "origin") {
  git remote set-url origin $remote
} else {
  git remote add origin $remote
}

git branch -M main
Write-Host "Pushing main to GitHub (login if prompted)..." -ForegroundColor Yellow
git push -u origin main

Write-Host ""
Write-Host "Done! Repo: https://github.com/$Username/$Repo" -ForegroundColor Green
Write-Host "Next: open DEPLOY.md and deploy on Render (Blueprint)." -ForegroundColor Green
