# achtungdiebash  🐍

Multiplayer actung die curve written in bash!

![picture of game](https://github.com/kofoednielsen/achtungdiebash/blob/main/achtungdiebash.png)

# how to play

Grab your best friend/s and make sure you are on the same wifi (or no firewall/NAT)

Run `server.sh` on your laptop

After running the client, press any `wasd` key to join the lobby, and press `r` to ready up

The game only supports up to 6 players, if you play more than 6 anything could happen

# If you can't join the lobby

Try these steps to debug
* Make sure you can reach eachother; Try to ping yourself from your friends laptop
* Try to run `nc -l 1337` on your laptop, and then run `echo "test!" | nc <your_ip> 1337` from your frined laptop
* Some netcat's dont support the -N option. If this is the case, try without -N or sometimes with -c in the client bash oneliner.
