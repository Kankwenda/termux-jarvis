# Termux ↔ Jarvis

Jarvis pilote le téléphone de Prince depuis Termux : lampe torche, batterie,
SMS, notifications, vibration… via SSH + tunnel Cloudflare.

## Ce qui est préparé (côté Jarvis, 14 nov. 2026)

- `setup.sh` — à lancer dans Termux sur le téléphone. Installe `termux-api`
  + `openssh`, autorise la clé SSH publique de Jarvis, démarre `sshd`
  (port 8022), teste la lampe torche 1 seconde, puis ouvre un tunnel
  Cloudflare TCP vers le SSH et affiche l'adresse.
- `connect.sh` — côté Jarvis. Ouvre le tunnel côté client
  (`cloudflared access tcp`) puis exécute la commande en SSH.
  Exemple : `./connect.sh https://xxxx.trycloudflare.com u0_a123 "termux-torch on"`
- Clé SSH de Jarvis : `ssh-ed25519 AAAAC3...hatch` (clé publique uniquement,
  intégrée dans `setup.sh`). Aucun mot de passe n'est partagé ni demandé.

## Étapes pour Prince (sur le téléphone)

1. **Termux** installé (F-Droid, pas le Play Store). Si ce n'est pas fait :
   installe-le depuis F-Droid.
2. **Termux:API** installé (l'appli compagnon, depuis F-Droid, même source
   que Termux). Sans elle, `termux-torch` ne marche pas.
3. Dans Termux :
   ```
   pkg update && pkg install -y git
   git clone https://github.com/Kankwenda/termux-jarvis
   cd termux-jarvis
   bash setup.sh
   ```
4. Le script affiche deux choses à envoyer à Jarvis : **l'adresse du
   tunnel** (`xxxx.trycloudflare.com`) et **le nom d'utilisateur SSH**
   (`u0_a...`).
5. Jarvis teste alors la connexion et allume la lampe à distance
   (`termux-torch on`).

## Sécurité

- Authentification par clé uniquement, pas de mot de passe.
- Pour retirer l'accès à tout moment, dans Termux :
  `sed -i '/hatch$/d' ~/.ssh/authorized_keys && pkill sshd`
- L'adresse du tunnel change à chaque démarrage ; le téléphone doit rester
  allumé (`termux-wake-lock`, fait par le script) tant que Jarvis doit
  pouvoir s'y connecter.

## Points à vérifier au premier test

- **Le proxy de la machine de Jarvis a déjà bloqué `api.trycloudflare.com`**
  pour la création de tunnels. Si `cloudflared access tcp` échoue côté
  Jarvis, le repli prévu est un polling via GitHub (le téléphone va chercher
  les commandes dans un fichier du dépôt toutes les 30 s) — pas de tunnel
  entrant nécessaire.
- **La lampe torche est le premier test** : si `termux-torch on` allume la
  lampe et que Prince le confirme, la connexion est validée.

## Journal

- 14 nov. 2026, 12:13 — Prince : « Oui, prépare la connexion Termux ».
  Objectif mesurable : Jarvis exécute `termux-torch on` sur le téléphone
  via SSH ; succès = Prince confirme que la lampe s'allume.
- Tentative 1 : vérification clé SSH (`~/.ssh/id_ed25519.pub` présente) +
  syntaxe `cloudflared tunnel --url tcp://...` et `cloudflared access tcp`
  — OK sur la machine de Jarvis.
- Scripts écrits d'après le patron prouvé de `walker-slm/termux/start-cloudflare.sh`
  (`pkg install -y cloudflared`, `termux-wake-lock`, tunnel en avant-plan).
