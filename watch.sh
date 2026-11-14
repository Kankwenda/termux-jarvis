#!/usr/bin/env bash
# Jarvis : attend l'adresse du tunnel Termux envoyée par le téléphone, puis se connecte.
# Usage : ./watch.sh [commande...]
#   sans argument : teste la connexion (termux-battery-status)
#   avec argument : exécute la commande, ex. ./watch.sh "termux-torch on"
# Le téléphone envoie l'adresse tout seul (setup.sh) ; Prince n'a rien à copier.
# Le jeton webhook.site expire le 21 nov. 2026 : après ça, en créer un autre et
# mettre à jour WEBHOOK_UUID ici et dans setup.sh.
set -u
UUID="7e90bb44-630c-45c6-9b57-cef69c6036e0"
CMD="${*:-termux-battery-status}"
DIR="$(dirname "$0")"

echo "J'attends l'adresse du tunnel envoyée par le téléphone..."
for i in $(seq 1 120); do
  curl -s -m 15 "https://webhook.site/token/$UUID/requests" -H 'Accept: application/json' > /tmp/jarvis-wh.json 2>/dev/null
  read HOST USER < <(python3 -c "
import json
d = json.load(open('/tmp/jarvis-wh.json'))
for r in d.get('data', []):
    try:
        c = json.loads(r.get('content', ''))
    except Exception:
        continue
    if isinstance(c, dict) and 'host' in c:
        print(c['host'], c.get('user', ''))
        break
" 2>/dev/null)
  if [ -n "${HOST:-}" ]; then
    echo "Adresse reçue : $HOST (utilisateur $USER)"
    exec "$DIR/connect.sh" "$HOST" "$USER" "$CMD"
  fi
  sleep 30
done
echo "Aucune adresse reçue après 60 minutes. Vérifie que setup.sh tourne sur le téléphone."
exit 1
