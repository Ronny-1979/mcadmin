#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG_FILE="/opt/minecraft-bedrock/logs/latest.log"
FIFO="/opt/minecraft-bedrock/server.stdin"
STATE_FILE="/var/www/html/mcadmin/mcadmin_state.json"
WORLDS_DIR="/opt/minecraft-bedrock/worlds"
PID_FILE="/tmp/mcadmin_welcome.pid"

echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

while IFS= read -r line; do
    if [[ "$line" =~ Player\ connected:\ ([^,]+), ]]; then
        PLAYER="${BASH_REMATCH[1]}"
        WORLD=$(jq -r '.active_world // empty' "$STATE_FILE" 2>/dev/null)
        [ -z "$WORLD" ] && continue
        WELCOME_FILE="$WORLDS_DIR/$WORLD/.mcadmin_welcome.txt"
        [ -f "$WELCOME_FILE" ] || continue
        sleep 2
        SERVER_NAME=$(grep -m1 '^server-name=' "/opt/minecraft-bedrock/server.properties" 2>/dev/null | cut -d'=' -f2-)
        while IFS= read -r msg_line || [ -n "$msg_line" ]; do
            msg_line="${msg_line#"${msg_line%%[![:space:]]*}"}"
            msg_line="${msg_line%"${msg_line##*[![:space:]]}"}"
            [ -z "$msg_line" ] && continue
            msg_line="${msg_line//\{player\}/$PLAYER}"
            msg_line="${msg_line//\{world\}/$WORLD}"
            msg_line="${msg_line//\{server\}/$SERVER_NAME}"
            [ -p "$FIFO" ] && printf 'tell %s %s\n' "$PLAYER" "$msg_line" > "$FIFO"
            sleep 0.2
        done < "$WELCOME_FILE"
    fi
done < <(tail -n 0 -F "$LOG_FILE" 2>/dev/null)
