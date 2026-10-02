import dotenv from 'dotenv';
dotenv.config(); // Must run FIRST — before any module reads process.env at init time

import express from 'express';
import v1Router from './router/v1';
import cors from 'cors';
import { initPassport } from './passport';
import authRoute from './router/auth';
import session from 'express-session';
import passport from 'passport';
import cookieParser from 'cookie-parser';
import { COOKIE_MAX_AGE } from './consts';
import { RedisStore } from 'connect-redis';
import Redis from 'ioredis';

// ─── Redis session store ──────────────────────────────────────────────────────
// All backend instances share session state through the same Redis cluster.
// This is required for OAuth to work correctly in a multi-instance ASG setup.
if (!process.env.REDIS_URL) {
  console.warn(
    '[Session] REDIS_URL is not set — falling back to in-memory MemoryStore. ' +
    'This is only safe for local development with a single backend instance.',
  );
}

const redisClient = process.env.REDIS_URL
  ? new Redis(process.env.REDIS_URL, { lazyConnect: true, maxRetriesPerRequest: 3 })
  : null;

redisClient?.on('error', (err) => console.error('[Session Redis] Error:', err));

const sessionStore = redisClient
  ? new RedisStore({ client: redisClient, prefix: 'chessverse:sess:' })
  : undefined; // express-session falls back to MemoryStore when store is undefined

// ─── App setup ───────────────────────────────────────────────────────────────
const app = express();

app.enable('trust proxy');
app.use(express.json());
app.use(cookieParser());
app.use(
  session({
    store: sessionStore,
    secret: process.env.COOKIE_SECRET || 'keyboard cat',
    resave: false,
    saveUninitialized: false,
    cookie: {
      secure: process.env.NODE_ENV === 'production',
      sameSite: process.env.NODE_ENV === 'production' ? 'none' : 'lax',
      maxAge: COOKIE_MAX_AGE,
    },
  })
);

initPassport();
app.use(passport.initialize());
app.use(passport.authenticate('session'));

const allowedHosts = process.env.ALLOWED_HOSTS ? process.env.ALLOWED_HOSTS.split(',') : [];

app.use(
  cors({
    origin: allowedHosts,
    methods: 'GET,POST,PUT,DELETE',
    credentials: true,
  })
);

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/auth', authRoute);
app.use('/v1', v1Router);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}...`);
});
