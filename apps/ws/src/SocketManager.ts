import { randomUUID } from 'crypto';
import { WebSocket } from 'ws';
import { userJwtClaims } from './auth';
import { publisher, subscriber, gameChannel } from './redis';

export class User {
  public socket: WebSocket;
  public id: string;
  public userId: string;
  public name: string;
  public isGuest?: boolean;

  constructor(socket: WebSocket, userJwtClaims: userJwtClaims) {
    this.socket = socket;
    this.userId = userJwtClaims.userId;
    this.id = randomUUID();
    this.name = userJwtClaims.name;
    this.isGuest = userJwtClaims.isGuest;
  }
}

class SocketManager {
  private static instance: SocketManager;

  /**
   * Local sockets only — the users physically connected to THIS instance.
   * Other instances have their own copy of this map for their own sockets.
   */
  private interestedSockets: Map<string, User[]>;
  private userRoomMapping: Map<string, string>;

  /** Track which Redis channels this instance is already subscribed to. */
  private subscribedChannels: Set<string>;

  private constructor() {
    this.interestedSockets = new Map<string, User[]>();
    this.userRoomMapping = new Map<string, string>();
    this.subscribedChannels = new Set<string>();

    /**
     * Central Redis message handler.
     * When any instance publishes to a game channel, ALL instances receive it
     * here and deliver it to whichever local sockets belong to that game room.
     */
    subscriber.on('message', (channel: string, message: string) => {
      // channel format: "game:{gameId}"
      const roomId = channel.replace(/^game:/, '');
      const localUsers = this.interestedSockets.get(roomId);
      if (!localUsers) return; // no local sockets for this room — nothing to do

      localUsers.forEach((user) => {
        if (user.socket.readyState === WebSocket.OPEN) {
          user.socket.send(message);
        }
      });
    });
  }

  static getInstance() {
    if (SocketManager.instance) {
      return SocketManager.instance;
    }
    SocketManager.instance = new SocketManager();
    return SocketManager.instance;
  }

  addUser(user: User, roomId: string) {
    const existing = this.interestedSockets.get(roomId) || [];
    // Evict any stale entry for the same userId (e.g. after reconnect)
    this.interestedSockets.set(roomId, [
      ...existing.filter((u) => u.userId !== user.userId),
      user,
    ]);
    this.userRoomMapping.set(user.userId, roomId);

    // Subscribe to this room's Redis channel if not already subscribed.
    const channel = gameChannel(roomId);
    if (!this.subscribedChannels.has(channel)) {
      subscriber.subscribe(channel, (err) => {
        if (err) {
          console.error(`[SocketManager] Failed to subscribe to ${channel}:`, err);
        } else {
          this.subscribedChannels.add(channel);
        }
      });
    }
  }

  /**
   * Publish a message to Redis.
   * Every WS instance (including this one) will receive it via the subscriber
   * and deliver it to their local sockets in this room.
   */
  broadcast(roomId: string, message: string) {
    publisher.publish(gameChannel(roomId), message).catch((err) => {
      console.error(`[SocketManager] Redis publish failed for room ${roomId}:`, err);
    });
  }

  removeUser(user: User) {
    const roomId = this.userRoomMapping.get(user.userId);
    if (!roomId) {
      console.error('User was not interested in any room?');
      return;
    }
    const room = this.interestedSockets.get(roomId) || [];
    const remainingUsers = room.filter((u) => u.userId !== user.userId);
    this.interestedSockets.set(roomId, remainingUsers);

    if (remainingUsers.length === 0) {
      this.interestedSockets.delete(roomId);

      // Unsubscribe from Redis channel when no local sockets remain in the room.
      const channel = gameChannel(roomId);
      subscriber.unsubscribe(channel, (err) => {
        if (err) {
          console.error(`[SocketManager] Failed to unsubscribe from ${channel}:`, err);
        } else {
          this.subscribedChannels.delete(channel);
        }
      });
    }
    this.userRoomMapping.delete(user.userId);
  }
}

export const socketManager = SocketManager.getInstance();
