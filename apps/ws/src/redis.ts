import Redis from 'ioredis';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

/**
 * Retry strategy: exponential backoff capped at 5 seconds.
 * Keeps the app alive during ElastiCache maintenance or brief failovers.
 * After ~33 attempts (≈5 minutes total), ioredis will stop retrying.
 */
function retryStrategy(times: number): number | null {
  if (times > 33) {
    // Give up after ~5 minutes of retrying
    return null;
  }
  return Math.min(times * 150, 5000);
}

const REDIS_OPTS = {
  lazyConnect: true,
  retryStrategy,
  // null means ioredis uses retryStrategy instead of failing after N attempts
  maxRetriesPerRequest: null as unknown as number,
  enableReadyCheck: true,
};

/**
 * Publisher client — used to PUBLISH game events to Redis channels.
 * Normal ioredis connection; can issue any Redis command.
 */
export const publisher = new Redis(REDIS_URL, REDIS_OPTS);

/**
 * Subscriber client — dedicated connection for SUBSCRIBE / PSUBSCRIBE.
 * A Redis client in subscribe mode cannot issue other commands,
 * so we keep this separate from the publisher.
 */
export const subscriber = new Redis(REDIS_URL, REDIS_OPTS);

publisher.on('error', (err) => console.error('[Redis Publisher] Error:', err));
publisher.on('reconnecting', (ms: number) => console.warn(`[Redis Publisher] Reconnecting in ${ms}ms`));

subscriber.on('error', (err) => console.error('[Redis Subscriber] Error:', err));
subscriber.on('reconnecting', (ms: number) => console.warn(`[Redis Subscriber] Reconnecting in ${ms}ms`));

/** Channel name convention for a game room. */
export const gameChannel = (gameId: string) => `game:${gameId}`;

/** Key used for atomic matchmaking — stores the pending game ID. */
export const PENDING_GAME_KEY = 'chessverse:pendingGameId';
