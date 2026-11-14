#!/usr/bin/env bash
# Jarvis → Termux : exécute une commande dans le Termux de Prince via SSH + tunnel Cloudflare.
# Usage :
#   ./connect.sh <adresse-tunnel> <utilisateur-ssh> <commande...>
# Exemple :
#   ./connect.sh https://xxxx.trycloudflare.com u0_a123 "termux-torch on"
# Sans commande : affiche l'état de la batterie (test de connexion).
# Prérequis : ~/cloudflared présent, clé ~/.ssh/id_ed25519 (autorisée par setup.sh côté téléphone).
# Risque connu (à vérifier au premier test) : le proxy de cette machine a déjà
# bloqué api.trycloudflare.com pour la création de tunnels ; si « cloudflared
# access » échoue ici, le repli est un polling via GitHub (voir README.md).
set -u
HOST="${1:?adresse du tunnel, ex. https://xxxx.trycloudflare.com}"
USER="${2:?nom utilisateur SSH, ex. u0_a123}"
shift 2
CMD="${*:-termux-battery-status}"
HOST="${HOST#https://}"; HOST="${HOST#http://}"; HOST="${HOST%%/*}"

CLOUDFLARED="$HOME/cloudflared"
LOCAL_PORT=2222
"$CLOUDFLARED" access tcp --hostname "$HOST" --url "localhost:$LOCAL_PORT" > /tmp/jarvis-access.log 2>&1 &
ACCESS_PID=$!
trap 'kill $ACCESS_PID 2>/dev/null; exit' INT TERM EXIT
sleep 5
ssh -p "$LOCAL_PORT" -i ~/.ssh/id_ed25519 \
  -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
  "$USER@127.0.0.1" "$CMD"
