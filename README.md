# PXLcade
PXLcade is a 48x64 game pack made with the love game framework, each game trying to make the most of this super low resolution. This project is mainly just something I'm using to learn love.

## Games
+ Snake -- A snake game slightly inspired my slither.io, the fanciest of the bunch.

   You are competing against a number of ai snakes, you win by eating more then the avarage number of pellets they eat, or by killing them. You lose by dying or not eating more than they eat before the map runs out of pellets. You can adjust the number of AI, map size, player and ai speed, and a few of the ai behaviour settings. 

+ Pong -- The classic hello world game
   Single and 2 player modes!
+ Breakout -- Break them blocks!

## Controls

* Menu/Global
  * `return` select/start
  * `q` exit to menu/close game
  * `1/2/3` toggle fx
* Pong 
  * `up/down` and `mouse` player 1 paddle
  * `a/z` player 2 paddle
* Breakout
  * `right/left` move paddle

## Dev info
See the code in the subgames for examples on the structure, which is almost the same as a normal love game. PXLcade live reloads any of the subgame main/lua files if they are modified. 
