#!/bin/sh
project_dir="$HOME/Documents/ZZ2/TpCsharp/projet_clicker_cs/GameServerApi/GameServerApi.csproj"
project_dirTest="$HOME/Documents/ZZ2/TpCsharp/projet_clicker_cs/GameServerApi.Tests/GameServerApi.Tests.csproj"

# Détection du shell utilisé pour ajuster les comportements spécifiques
if [[ -n "$BASH_VERSION" ]]; then
    # Pour Bash : Utilisation de 'local' pour les variables locales
    echo "▶ Bash détecté"
elif [[ -n "$ZSH_VERSION" ]]; then
    # Pour Zsh : Utilisation de 'typeset' pour les variables locales
    echo "▶ Zsh détecté"
else
    echo "▶ Shell inconnu. Utilisation de variables globales."
    local() { typeset "$@"; }  # Simuler 'local' pour les autres shells
fi

# Variables de couleur pour la sortie
RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RESET=$'\033[0m'

# Fonction pour coloriser les lignes de sortie
colorize_line() {
    local line="$1"
    local lower="${line}"  # Convertir en minuscules
    if [[ "$lower" == *error* || "$lower" == *failed* ]]; then
        printf "%s%s%s\n" "$RED" "$line" "$RESET"
    elif [[ "$lower" == *warning* ]]; then
        printf "%s%s%s\n" "$YELLOW" "$line" "$RESET"
    else
        printf "%s%s%s\n" "$GREEN" "$line" "$RESET"
    fi
}

# Fonction pour récupérer le nom de la branche Git
get_branch_name() {
    local current
    current="$(git branch --show-current 2>/dev/null || true)"
    if [[ -z "${current:-}" ]]; then
        current="$(git rev-parse --short HEAD 2>/dev/null || echo "DETACHED")"
    fi
    echo "$current"
}

# Fonction pour vérifier l'environnement (dossier et dotnet)
verifier_environement() {
    
    if ! ls "$project_dir" >/dev/null 2>&1; then
        echo "${RED}Dossier projet introuvable – opération annulée.${RESET}" >&2
        return 1
    fi
    
    if ! ls "$project_dirTest" >/dev/null 2>&1; then
            echo "${RED}Dossier projet introuvable – opération annulée.${RESET}" >&2
            return 1
        fi
        
    if ! command -v dotnet >/dev/null 2>&1; then
        echo "${RED}dotnet introuvable – opération annulée.${RESET}" >&2
        return 1
    fi
    return 0
}

# Fonction pour formater le code avec dotnet
format_code() {
    echo "${GREEN}Format: dotnet format${RESET}"
    if ! verifier_environement; then
        echo "${RED}Format non exécuté (environnement invalide).${RESET}"
        return 1
    fi

    local out1
    out1="$(dotnet format "$project_dirTest"--no-restore 2>&1 || true)"
    while IFS= read -r line; do colorize_line "$line"; done <<< "$out1"
    
    local out2
    out2="$(dotnet format "$project_dir"--no-restore 2>&1 || true)"
    while IFS= read -r line; do colorize_line "$line"; done <<< "$out2"

    if [[ -n "$(git status --porcelain)" ]]; then
        git add -A
        echo "${GREEN}Fichiers formatés ajoutés à l'action et à l'index${RESET}"
    fi
    echo "${GREEN}Format terminé.${RESET}"
}

# Fonction pour effectuer le build (Debug)
build_debug() {
    echo "${GREEN}Build: Debug${RESET}"
    if ! verifier_environement; then
        echo "${RED}Build non exécuté (environnement invalide).${RESET}"
        return 1
    fi
  
    local out
    out="$(dotnet build "$project_dir"--configuration Debug --no-restore 2>&1 || true)"
    local exit_code=$?
    
    # Vérification du code de retour après le build
    if [[ $exit_code -ne 0 ]]; then
        echo "${RED}Erreur de build (code $exit_code)${RESET}"
        echo "$out"  # Afficher la sortie d'erreur pour aider au débogage
        return 1
    fi
    
    # Coloriser la sortie du build
    while IFS= read -r line; do
        colorize_line "$line"
    done <<< "$out"
}

# Fonction pour exécuter les tests non bloquants
run_tests_nonblocking() {
    echo "${GREEN}Tests: dotnet test (non bloquant)${RESET}"

    # Vérification stricte de l'environnement (dossier et dotnet)
    if ! verifier_environement; then
        echo "${RED}Tests non exécutés (environnement invalide).${RESET}"
        return 1
    fi

    local test_output
    test_output="$(dotnet test "$project_dirTest"--configuration Debug --no-build 2>&1 || true)"

    # Colorisation des lignes des résultats des tests
    while IFS= read -r line; do
        colorize_line "$line"
    done <<< "$test_output"

    local summary
    summary="$(printf '%s\n' "$test_output" | grep -E 'Total tests:.*Passed:.*Failed:' | tail -n1 || true)"

    local total passed failed skipped
    total="$(printf '%s\n' "$summary" | sed -n 's/.*Total tests:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
    passed="$(printf '%s\n' "$summary" | sed -n 's/.*Passed:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
    failed="$(printf '%s\n' "$summary" | sed -n 's/.*Failed:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
    skipped="$(printf '%s\n' "$summary" | sed -n 's/.*Skipped:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"

    # Affichage du résumé des tests
    if [[ "$failed" =~ ^[0-9]+$ ]] && (( failed > 0 )); then
        echo "${RED}Tests échoués: $failed${RESET}"
    else
        echo "${GREEN}Tests échoués: ${failed:-0}${RESET}"
    fi
    if [[ "$passed" =~ ^[0-9]+$ ]]; then
        echo "${GREEN}Tests réussis: $passed${RESET}"
    fi
    if [[ "$skipped" =~ ^[0-9]+$ ]]; then
        echo "${YELLOW}Tests ignorés: $skipped${RESET}"
    fi
    if [[ "$total" =~ ^[0-9]+$ ]]; then
        echo "${GREEN}Total tests: $total${RESET}"
    fi

    echo "${GREEN}Vérification des tests terminée (non bloquante).${RESET}"
}

# Fonction principale qui combine formatage, build et tests
git_policy() {
    format_code
    branch=$(get_branch_name)

    if [[ "$branch" == "master" || "$branch" == "main" ]]; then
        echo "Tentative de build"
        build_debug
    else
        echo "Exécution de la politique dans une branche différente"
        build_debug
        run_tests_nonblocking
    fi
}

# Exécution de la politique
git_policy
