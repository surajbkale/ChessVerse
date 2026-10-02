import { WebSocket } from 'ws';
import {
  GAME_OVER,
  INIT_GAME,
  JOIN_GAME,
  MOVE,
  OPPONENT_DISCONNECTED,
  JOIN_ROOM,
  GAME_JOINED,
  GAME_NOT_FOUND,
  GAME_ALERT,
  GAME_ADDED,
  GAME_ENDED,
  EXIT_GAME,
} from './messages';
import { Game } from './Game';
import { db } from './db';
import { socketManager, User } from './SocketManager';
import { Square } from 'chess.js';
import { GameStatus } from '@prisma/client';
import { publisher, PENDING_GAME_KEY } from './redis';

export class GameManager {
  private games: Game[];
  private users: User[];

  constructor() {
    this.games = [];
    this.users = [];
  }

  addUser(user: User) {
    this.users.push(user);
    this.addHandler(user);
  }

  removeUser(socket: WebSocket) {
    const user = this.users.find((user) => user.socket === socket);
    if (!user) {
      console.error('User not found?');
      return;
    }
    this.users = this.users.filter((user) => user.socket !== socket);
    socketManager.removeUser(user);
  }

  removeGame(gameId: string) {
    this.games = this.games.filter((g) => g.gameId !== gameId);
  }

  /**
   * Atomically claim the pending game slot in Redis.
   * Returns the existing pendingGameId if one exists, or null if we claimed it.
   * Uses SET NX (set-if-not-exists) so only ONE instance wins the race.
   */
  private async claimOrGetPendingGame(newGameId: string): Promise<string | null> {
    // SET key value NX EX 30  →  sets only if key does not exist, with 30s TTL
    const result = await publisher.set(PENDING_GAME_KEY, newGameId, 'NX', 'EX', 30);
    if (result === 'OK') {
      // We claimed it — we are player 1
      return null;
    }
    // Another instance (or us) already set it — read the existing value
    return await publisher.get(PENDING_GAME_KEY);
  }

  private async clearPendingGame() {
    await publisher.del(PENDING_GAME_KEY);
  }

  private addHandler(user: User) {
    user.socket.on('message', async (data) => {
      let message: { type: string; payload?: any };
      try {
        message = JSON.parse(data.toString());
      } catch {
        // Malformed JSON — close gracefully rather than crashing the handler
        user.socket.close(1003, 'Invalid message format');
        return;
      }
      if (!message.type) return;

      if (message.type === INIT_GAME) {
        const game = new Game(user.userId, null);

        // Try to atomically claim the pending slot in Redis.
        // Returns null if we are player 1 (we claimed it),
        // or the existing pendingGameId if someone else is waiting.
        const existingPendingId = await this.claimOrGetPendingGame(game.gameId);

        if (existingPendingId) {
          // Someone is already waiting — we are player 2.
          // Find the game object on this instance (may have been created here).
          let pendingGame = this.games.find((x) => x.gameId === existingPendingId);

          if (!pendingGame) {
            // The pending game was created by a different WS instance.
            // Reconstruct it from the DB so we can call updateSecondPlayer.
            const dbGame = await db.game.findUnique({ where: { id: existingPendingId } });
            if (!dbGame) {
              console.error('Pending game not found in DB, clearing stale key');
              await this.clearPendingGame();
              return;
            }
            pendingGame = new Game(dbGame.whitePlayerId, null, dbGame.id, dbGame.startAt);
            this.games.push(pendingGame);
          }

          if (user.userId === pendingGame.player1UserId) {
            socketManager.broadcast(
              pendingGame.gameId,
              JSON.stringify({
                type: GAME_ALERT,
                payload: { message: 'Trying to Connect with yourself?' },
              }),
            );
            return;
          }

          socketManager.addUser(user, pendingGame.gameId);
          await pendingGame.updateSecondPlayer(user.userId);
          await this.clearPendingGame();
        } else {
          // We are player 1 — game slot claimed in Redis.
          this.games.push(game);
          socketManager.addUser(user, game.gameId);
          socketManager.broadcast(
            game.gameId,
            JSON.stringify({
              type: GAME_ADDED,
              gameId: game.gameId,
            }),
          );
        }
      }

      if (message.type === MOVE) {
        const gameId = message.payload.gameId;
        const game = this.games.find((game) => game.gameId === gameId);
        if (game) {
          game.makeMove(user, message.payload.move);
          if (game.result) {
            this.removeGame(game.gameId);
          }
        }
      }

      if (message.type === EXIT_GAME){
        const gameId = message.payload.gameId;
        const game = this.games.find((game) => game.gameId === gameId);

        if (game) {
          game.exitGame(user);
          this.removeGame(game.gameId)
        }
      }

      if (message.type === JOIN_ROOM) {
        const gameId = message.payload?.gameId;
        if (!gameId) {
          return;
        }

        let availableGame = this.games.find((game) => game.gameId === gameId);
        const gameFromDb = await db.game.findUnique({
          where: { id: gameId },
          include: {
            moves: {
              orderBy: {
                moveNumber: 'asc',
              },
            },
            blackPlayer: true,
            whitePlayer: true,
          },
        });

        // There is a game created but no second player available
        
        if (availableGame && !availableGame.player2UserId) {
          socketManager.addUser(user, availableGame.gameId);
          await availableGame.updateSecondPlayer(user.userId);
          return;
        }

        if (!gameFromDb) {
          user.socket.send(
            JSON.stringify({
              type: GAME_NOT_FOUND,
            }),
          );
          return;
        }

        if(gameFromDb.status !== GameStatus.IN_PROGRESS) {
          user.socket.send(JSON.stringify({
            type: GAME_ENDED,
            payload: {
              result: gameFromDb.result,
              status: gameFromDb.status,
              moves: gameFromDb.moves,
              blackPlayer: {
                id: gameFromDb.blackPlayer.id,
                name: gameFromDb.blackPlayer.name,
              },
              whitePlayer: {
                id: gameFromDb.whitePlayer.id,
                name: gameFromDb.whitePlayer.name,
              },
            }
          }));
          return;
        }

        if (!availableGame) {
          const game = new Game(
            gameFromDb?.whitePlayerId!,
            gameFromDb?.blackPlayerId!,
            gameFromDb.id,
            gameFromDb.startAt,
          );
          game.seedMoves(gameFromDb?.moves || []);
          this.games.push(game);
          availableGame = game;
        }


        user.socket.send(
          JSON.stringify({
            type: GAME_JOINED,
            payload: {
              gameId,
              moves: gameFromDb.moves,
              blackPlayer: {
                id: gameFromDb.blackPlayer.id,
                name: gameFromDb.blackPlayer.name,
              },
              whitePlayer: {
                id: gameFromDb.whitePlayer.id,
                name: gameFromDb.whitePlayer.name,
              },
              player1TimeConsumed: availableGame.getPlayer1TimeConsumed(),
              player2TimeConsumed: availableGame.getPlayer2TimeConsumed(),
            },
          }),
        );

        socketManager.addUser(user, gameId);
      }
    });
  }
}
