#!/data/data/com.termux/files/usr/bin/bash
# Jarvis ↔ Termux : prépare l'accès SSH de Jarvis à ce téléphone.
# Usage : bash setup.sh
# Ce que fait ce script :
#   1. installe termux-api (lampe torche, batterie, SMS...) et openssh
#   2. autorise la clé SSH publique de Jarvis (clé seule, jamais de mot de passe)
#   3. démarre le serveur SSH (port 8022)
#   4. teste la lampe torche (1 seconde) pour prouver que Termux:API marche
#   5. ouvre un tunnel Cloudflare vers le SSH et envoie l'adresse à Jarvis tout seul (Prince n'a rien à copier)
# Sécurité : seule la clé de Jarvis est autorisée. Pour retirer l'accès à
# tout moment : sed -i '/hatch$/d' ~/.ssh/authorized_keys && pkill sshd
# L'adresse du tunnel change à chaque démarrage ; le téléphone doit rester
# allumé (termux-wake-lock) tant que Jarvis doit pouvoir s'y connecter.
set -u

JARVIS_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKn4uXc80wc1RcvDzRBQeM4n+yg+kmbJPj0JhDfBSsCZ hatch"
# Boîte aux lettres de Jarvis : le téléphone y envoie l'adresse du tunnel tout seul.
# (jeton webhook.site, valable jusqu'au 21 nov. 2026 — après ça, Jarvis en crée un autre)
WEBHOOK_UUID="7e90bb44-630c-45c6-9b57-cef69c6036e0"

echo "=== 1/5 Paquets (termux-api, openssh) ==="
pkg install -y termux-api openssh curl

echo "=== 2/5 Clé SSH de Jarvis ==="
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
grep -qs "hatch$" ~/.ssh/authorized_keys || echo "$JARVIS_KEY" >> ~/.ssh/authorized_keys
echo "Clé Jarvis autorisée (authentification par clé uniquement)."

echo "=== 3/5 Serveur SSH (port 8022) ==="
pgrep -x sshd >/dev/null || sshd
echo "sshd en cours."

echo "=== 4/5 Test de la lampe torche (1 seconde) ==="
if command -v termux-torch >/dev/null 2>&1; then
  termux-torch on && sleep 1 && termux-torch off \
    && echo "Lampe torche OK : Termux:API fonctionne." \
    || echo "ATTENTION : termux-torch a échoué. Installe l'appli Termux:API depuis F-Droid (même source que Termux), puis relance ce script."
else
  echo "ATTENTION : termux-torch introuvable. Installe l'appli Termux:API depuis F-Droid (même source que Termux), puis relance ce script."
  exit 1
fi

command -v cloudflared >/dev/null 2>&1 || pkg install -y cloudflared
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

echo "=== 5/5 Tunnel Cloudflare vers le SSH ==="
echo "Utilisateur SSH : $(whoami)"
cloudflared tunnel --url tcp://localhost:8022 --no-autoupdate > /tmp/jarvis-tunnel.log 2>&1 &
TUNNEL_PID=$!
trap 'kill $TUNNEL_PID 2>/dev/null; exit' INT TERM
sleep 10
TUNNEL_HOST=$(grep -oE "[a-z0-9.-]+\.trycloudflare\.com" /tmp/jarvis-tunnel.log | head -1)
echo "Adresse du tunnel : $TUNNEL_HOST"
# Envoie l'adresse à Jarvis tout seul : Prince n'a rien à copier.
if [ -n "$TUNNEL_HOST" ]; then
  for i in 1 2 3; do
    curl -s -m 15 -X POST "https://webhook.site/$WEBHOOK_UUID" \
      -H 'Content-Type: application/json' \
      -d "{\"host\":\"$TUNNEL_HOST\",\"user\":\"$(whoami)\"}" >/dev/null && break
    sleep 3
  done
  echo "Adresse envoyée à Jarvis automatiquement."
fi
echo ""
echo "Laisse Termux ouvert. Si aucune adresse ne s'affiche, regarde /tmp/jarvis-tunnel.log"
echo "Pour arrêter : Ctrl+C (le tunnel s'arrête, la clé reste autorisée)."
wait $TUNNEL_PID
