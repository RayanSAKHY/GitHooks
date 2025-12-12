#!/usr/bin/env bash
# Détecte si on est dans Bash ou si on doit lancer PowerShell
if [[ "$0" == *bash* ]] || [[ -n "$BASH_VERSION" ]]; then
    echo "▶ Exécution du script Bash"
    sh "$HOME/Documents/ZZ2/TpCsharp/projet_clicker_cs/.husky/scripts/common.sh"
elif command -v pwsh >/dev/null 2>&1; then
    echo "▶ Exécution du script PowerShell (pwsh)"
    pwsh -NoProfile -File "$HOME/Documents/ZZ2/TpCsharp/projet_clicker_cs/.husky/scripts/common.ps1"
elif command -v powershell.exe >/dev/null 2>&1; then
    echo "▶ Exécution du script PowerShell (Windows)"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME/Documents/ZZ2/TpCsharp/projet_clicker_cs/.husky/scripts/common.ps1"
else
    echo "Aucun shell compatible trouvé"
       exit 1
fi