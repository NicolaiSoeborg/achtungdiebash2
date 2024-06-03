#!/usr/bin/env bash
shopt -s nullglob  # make sure `for blah in /*` doesn't match `.`

GAME_DIR="/tmp/actungdebash"
PLAYERS_DIR="$GAME_DIR/players"

# https://stackoverflow.com/a/13322667
read -r _{,} _ _ _ _ SERVER_IP _ < <(ip r g 1)

# PORTS:
# 1337: web interface
# 1338: get state
# 1339: input

game_state() {
  # prints lobby or game canvas
  if [ -f "$GAME_DIR/lobby" ]; then
    printf "\033cWaiting for players to ready up.\n\n\t\x1b[1mcurl %s:1337 | bash\x1b[0m\n\nPress \x1b[4mwasd\x1b[0m when connected, then \x1b[4mr\x1b[0m when ready.\n\n\n" "$SERVER_IP"
    for player in "$PLAYERS_DIR"/*;
    do
      local player_info="$(cat "$player/color" 2> /dev/null) $(basename "$player")"
      local input=$(cat "$player/input" 2> /dev/null)
      if [ "$input" == "r" ]
      then
        echo -e "  ✅ READY               $player_info"
      else
        echo -e "  ⌛ not ready yet       $player_info"
      fi
    done
  else
    printf '\033c'
    for y in {0..19};
    do
      # ${arr[@]:s:n} 	Retrieve n elements starting at index s
      printf "%s%s" "${canvas[@]:y*20:20}" "\n"
    done
    printf "\n"
  fi
}

client_server() {
  while true ; do printf 'HTTP/1.1 200 OK\r\n\r\ndraw() { while :; do printf "\\x1b[;H"; nc -dN %s 1338; sleep 1; done }\ninput() { while :; do read -sn1 c && printf "$(whoami) $c" | nc -N %s 1339; done }\ndraw & input\n' "$SERVER_IP" "$SERVER_IP" | nc -Nl 1337 >/dev/null; done
}

state_server() {
  while true ; do printf "$(game_state)\n" | nc -Nl 1338 > /dev/null; done
}

input_server() {
  while true
  do
    local input=$(nc -dl 1339)
    IFS=' ' read -a input_parts <<< "$input"
    local name=${input_parts[0]}
    local direction=${input_parts[-1]}
    if [[ "$direction" =~ ^(w|a|s|d|r)$ ]]
    then
      # Allow new players to join while in lobby:
      if [ -f "$GAME_DIR/lobby" ]; then
        if mkdir "$PLAYERS_DIR/$name" 2>/dev/null; then
          echo -n "$1" > "$PLAYERS_DIR/$name/color"
          shift  # pop arg1 ($1) = next color is now first
        fi
      fi

      # Ignore errors if dead people try moving (`$name/` doesn't exist when dead)
      2>/dev/null echo -n "$direction" > "$PLAYERS_DIR/$name/input"
    fi
  done
}

game() {
  rm $GAME_DIR/lobby
  # GAME LOOP: Keep running until a single player left
  while [ "$(ls $PLAYERS_DIR | wc -l)" -gt 1 ]
  do
    sleep 1
    # MOVE PLAYERS
    local playerstring=""
    for player in "$PLAYERS_DIR"/*;
      do
        local input=$(cat "$player/input" 2> /dev/null)
        local color=$(cat "$player/color" 2> /dev/null)
        local x=$(cat "$player/x" 2> /dev/null || printf "5")
        local y=$(cat "$player/y" 2> /dev/null || printf "5")

        case "$input" in
          "w")
            y=$((y - 1))
            ;;
          "a")
            x=$((x - 1))
            ;;
          "s" | "r")
            y=$((y + 1))
            ;;
          "d")
            x=$((x + 1))
            ;;
        esac
        # Allow 'border wrap', modern snake style
        # x=$((x < 0 ? 19 : x > 19 ? 0 : x))
        # y=$((y < 0 ? 19 : y > 19 ? 0 : y))

        # check if square is already colored
        local oob_x=$((x < 0 ? 1 : x > 19 ? 1 : 0))
        local oob_y=$((y < 0 ? 1 : y > 19 ? 1 : 0))
        if [ "$((oob_x+oob_y))" -gt 0 ] || [ "${canvas[$((y*20 + x))]}" != "⬜" ]
        then
          # kill thme player!
          rm -r "$player"
          canvas[$((y*20 + x))]="💀"
          continue
        fi
        # Save new state:
        canvas[$((y*20 + x))]="$color"
        printf "$x" > "$player/x"
        printf "$y" > "$player/y"
        playerstring="$playerstring$color $(basename "$player")\n"
      done

    # PRINT MAP
    printf "$(game_state)\n$playerstring\n"
  done
}

create_field() {
  canvas=( )
  for _ in {1..400}
  do
    canvas+=( "⬜" );
  done

  for player in "$PLAYERS_DIR"/*;
  do
    # assign random empty start location not too close to edge
    while true
    do
      local x=$((2 + RANDOM % 17))
      local y=$((2 + RANDOM % 17))

      if [ "${canvas[$((y*20 + x))]}" = "⬜" ]; then
        canvas[$((y*20 + x))]="$(cat $player/color)"
        echo -n "$x" > "$player/x"
        echo -n "$y" > "$player/y"
        break
      fi
    done
  done
}

lobby() {
  touch $GAME_DIR/lobby
  while true
  do
    printf "$(game_state)\n"
    local num_players=$(ls $PLAYERS_DIR | wc -l)
    local num_ready=$(grep -hr "r" $PLAYERS_DIR/ | wc -l)
    if [ "$num_players" -gt 1 ] && [ "$num_players" == "$num_ready" ]
    then
      break
    fi
    sleep 1
  done
}

win() {
  # TODO: Move this to game_state
  # clear
  for player in "$PLAYERS_DIR"/*;
  do
    local player_info="$(cat "$player/color" 2> /dev/null) $(basename "$player")"
    echo -e "\x1b[3;3H🏁 Congratulations \x1b[1m$player_info \x1b[5m🏆\x1b[0m You have won the game! 🏁"
  done
  sleep 8
}

while true
do
  rm -r $PLAYERS_DIR
  mkdir -p $PLAYERS_DIR
  client_server &
  state_server &
  input_server "🟩" "🟥" "🟦" "⬛" "🟪" "🟧" &
  lobby
  create_field
  game
  win
  kill $!
done
