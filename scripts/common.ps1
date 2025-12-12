#requires -Version 5.1
param()
$ErrorActionPreference = 'Stop'
$projectDir = "$env:HOME\Documents\ZZ2\TpCsharp\projet_clicker_cs\GameServerApi"

# Définir les couleurs pour la sortie (en utilisant les codes ANSI)
$RED = "`e[31m"
$YELLOW = "`e[33m"
$GREEN = "`e[32m"
$RESET = "`e[0m"

# Fonction pour coloriser la sortie
function colorize_line {
    param([string]$line)

    if ($line -match "error|failed") {
        Write-Host "$RED$line$RESET"
    } elseif ($line -match "warning") {
        Write-Host "$YELLOW$line$RESET"
    } else {
        Write-Host "$GREEN$line$RESET"
    }
}

# Fonction pour récupérer le nom de la branche Git
function get-branch-name {
    try {
        $branch = git branch --show-current
        if (-not $branch) {
            $branch = git rev-parse --short HEAD
        }
        return $branch
    } catch {
        return "DETACHED"
    }
}

# Fonction pour vérifier l'environnement (dossier projet et dotnet)
function verifier-environnement {

    if (-not (Test-Path $projectDir)) {
        Write-Host "$RED Dossier projet introuvable – opération annulée.$RESET"
        return $false
    }

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Host "$RED dotnet introuvable – opération annulée.$RESET"
        return $false
    }

    return $true
}

# Fonction pour formater le code avec dotnet
function format-code {
    Write-Host "$GREEN Format: dotnet format $RESET"
    if (-not (verifier-environnement)) {
        Write-Host "$RED Format non exécuté (environnement invalide).$RESET"
        return
    }

    $out = dotnet format --no-restore 2>&1
    $out | ForEach-Object { colorize_line $_ }

    # Vérifier si des fichiers ont été modifiés
    if (git status --porcelain) {
        git add -A
        Write-Host "$GREEN Fichiers formatés ajoutés à l'action et à l'index$RESET"
    }
    Write-Host "$GREEN Format terminé.$RESET"
}

# Fonction pour effectuer le build en mode Debug
function build-debug {
    Write-Host "$GREEN Build: Debug $RESET"
    if (-not (verifier-environnement)) {
        Write-Host "$RED Build non exécuté (environnement invalide).$RESET"
        return
    }

    $out = dotnet build --configuration Debug --no-restore 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Host "$RED Erreur de build (code $exitCode)$RESET"
        Write-Host "$out"
        return
    }

    $out | ForEach-Object { colorize_line $_ }
}

# Fonction pour exécuter les tests non bloquants
function run-tests-nonblocking {
    Write-Host "$GREEN Tests: dotnet test (non bloquant) $RESET"

    # Vérification stricte de l'environnement (dossier et dotnet)
    if (-not (verifier-environnement)) {
        Write-Host "$RED Tests non exécutés (environnement invalide).$RESET"
        return
    }

    $testOutput = dotnet test --configuration Debug --no-build 2>&1

    # Colorisation des lignes des résultats des tests
    $testOutput | ForEach-Object { colorize_line $_ }

    # Extraire le résumé des tests
    $summary = $testOutput | Select-String -Pattern 'Total tests:.*Passed:.*Failed:' | Select-Object -Last 1

    if ($summary) {
        $total = [int]($summary -replace '.*Total tests:\s*(\d+).*', '$1')
        $passed = [int]($summary -replace '.*Passed:\s*(\d+).*', '$1')
        $failed = [int]($summary -replace '.*Failed:\s*(\d+).*', '$1')
        $skipped = [int]($summary -replace '.*Skipped:\s*(\d+).*', '$1')

        if ($failed -gt 0) {
            Write-Host "$RED Tests échoués: $failed$RESET"
        } else {
            Write-Host "$GREEN Tests échoués: $failed$RESET"
        }

        if ($passed -gt 0) {
            Write-Host "$GREEN Tests réussis: $passed$RESET"
        }

        if ($skipped -gt 0) {
            Write-Host "$YELLOW Tests ignorés: $skipped$RESET"
        }

        Write-Host "$GREEN Total tests: $total$RESET"
    }

    Write-Host "$GREEN Vérification des tests terminée (non bloquante).$RESET"
}

# Fonction principale qui combine formatage, build et tests
function git-policy {
    format-code
    $branch = get-branch-name

    if ($branch -eq "master" -or $branch -eq "main") {
        Write-Host "Tentative de build"
        build-debug
    } else {
        Write-Host "Exécution de la politique dans une branche différente"
        build-debug
        run-tests-nonblocking
    }
}

# Exécution de la politique
git-policy
