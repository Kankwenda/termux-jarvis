#!/usr/bin/env bash
# Poller Jarvis → Termux via webhook.site.
# Repli quand le tunnel Cloudflare est bloqué côté Jarvis (proxy : 403 + websocket
# cassé, vérifié le 14 nov. 2026 avec deux erreurs différentes). Le canal webhook.site,
# lui, fonctionne dans les deux sens (c'est lui qui a livré l'adresse du tunnel).
# Usage (une seule commande à coller dans Termux) :
#   curl -sL "https://raw.githubusercontent.com/Kankwenda/termux-jarvis/master/poll.sh" | bash -s <JETON> <SECRET>
# Le poller tourne en arrière-plan, vérifie les commandes toutes les 20 s,
# exécute uniquement celles qui portent le bon SECRET, et renvoie le résultat
# sur le même jeton. Le jeton et le secret ne sont PAS dans ce dépôt public :
# ils sont passés en arguments (le secret empêche quiconque trouve le jeton
# de commander le téléphone).
# Arrêt : pkill -f jarvis-poll-loop.sh
set -u
TOKEN="${1:?jeton webhook.site manquant}"
SECRET="${2:?mot secret manquant}"
LOOP_FILE="$HOME/jarvis-poll-loop.sh"
LOG_FILE="$HOME/jarvis-poll.log"

pkg install -y jq curl >/dev/null 2>&1

cat > "$LOOP_FILE" <<'LOOP_EOF'
#!/usr/bin/env bash
TOKEN="__TOKEN__"
SECRET="__SECRET__"
SEEN_FILE="$HOME/jarvis-seen-uuids"
touch "$SEEN_FILE"
# Signal de vie : Jarvis voit que le poller tourne.
curl -s -X POST "https://webhook.site/$TOKEN" -H "Content-Type: application/json" -d "{\"hello\":true,\"user\":\"$(whoami)\"}" >/dev/null 2>&1
while true; do
  curl -s "https://webhook.site/token/$TOKEN/requests" -H "Accept: application/json" > /tmp/jarvis-cmds.json 2>/dev/null
  if [ -s /tmp/jarvis-cmds.json ]; then
    jq -r '.data | reverse | .[] | [.uuid, (.content | @base64)] | @tsv' /tmp/jarvis-cmds.json 2>/dev/null | while IFS="$(printf '\t')" read -r UUID B64; do
      grep -qx "$UUID" "$SEEN_FILE" 2>/dev/null && continue
      echo "$UUID" >> "$SEEN_FILE"
      CONTENT="$(echo "$B64" | base64 -d 2>/dev/null)"
      S="$(echo "$CONTENT" | jq -r '.secret // empty' 2>/dev/null)"
      [ "$S" = "$SECRET" ] || continue
      CMD="$(echo "$CONTENT" | jq -r '.cmd // empty' 2>/dev/null)"
      CID="$(echo "$CONTENT" | jq -r '.id // empty' 2>/dev/null)"
      [ -n "$CMD" ] || continue
      OUT="$(bash -c "$CMD" 2>&1 | head -c 4000)"
      jq -n --arg id "$CID" --arg out "$OUT" '{result:true, id:$id, output:$out}' | curl -s -X POST "https://webhook.site/$TOKEN" -H "Content-Type: application/json" --data @- >/dev/null 2>&1
    done
  fi
  sleep 20
done
LOOP_EOF
sed -i "s/__TOKEN__/$TOKEN/; s/__SECRET__/$SECRET/" "$LOOP_FILE"
chmod +x "$LOOP_FILE"
pkill -f jarvis-poll-loop.sh 2>/dev/null
nohup bash "$LOOP_FILE" > "$LOG_FILE" 2>&1 &
echo "Poller Jarvis démarré en arrière-plan (vérifie les commandes toutes les 20 s). Journal : $LOG_FILE"
echo "Pour arrêter : pkill -f jarvis-poll-loop.sh"
