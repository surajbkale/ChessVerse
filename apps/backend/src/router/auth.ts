import { Request, Response, Router } from 'express';
import passport from 'passport';
import jwt from 'jsonwebtoken';
import { db } from '../db';
import { v4 as uuidv4 } from 'uuid';
import { COOKIE_MAX_AGE } from '../consts';

const router = Router();

// Read env vars lazily so they are always resolved after dotenv.config() runs
function getConfig() {
  const isProduction = process.env.NODE_ENV === 'production';
  return {
    CLIENT_URL: process.env.AUTH_REDIRECT_URL ?? 'https://chessverse.lumenvault.live/game/random',
    FRONTEND_URL: process.env.FRONTEND_URL ?? 'https://chessverse.lumenvault.live',
    JWT_SECRET: process.env.JWT_SECRET || 'your_secret_key',
    cookieOptions: {
      maxAge: COOKIE_MAX_AGE,
      secure: isProduction,
      sameSite: (isProduction ? 'none' : 'lax') as 'none' | 'lax',
    },
  };
}


interface userJwtClaims {
  userId: string;
  name: string;
  isGuest?: boolean;
}

interface UserDetails {
  id: string;
  token?: string;
  name: string;
  isGuest?: boolean;
}

router.post('/guest', async (req: Request, res: Response) => {
  const { JWT_SECRET, cookieOptions } = getConfig();
  const bodyData = req.body;
  let guestUUID = 'guest-' + uuidv4();

  const user = await db.user.create({
    data: {
      username: guestUUID,
      email: guestUUID + '@chessverse.live',
      name: bodyData.name || guestUUID,
      provider: 'GUEST',
    },
  });

  const token = jwt.sign({ userId: user.id, name: user.name, isGuest: true }, JWT_SECRET);
  const UserDetails: UserDetails = {
    id: user.id,
    name: user.name!,
    token: token,
    isGuest: true,
  };

  res.cookie('guest', token, cookieOptions);
  res.json(UserDetails);
});

router.get('/refresh', async (req: Request, res: Response) => {
  const { JWT_SECRET, cookieOptions } = getConfig();
  if (req.user) {
    const user = req.user as UserDetails;

    const userDb = await db.user.findFirst({
      where: {
        id: user.id,
      },
    });

    const token = jwt.sign({ userId: user.id, name: userDb?.name }, JWT_SECRET);
    res.json({
      token,
      id: user.id,
      name: userDb?.name,
    });
  } else if (req.cookies && req.cookies.guest) {
    const decoded = jwt.verify(req.cookies.guest, JWT_SECRET) as userJwtClaims;
    const token = jwt.sign({ userId: decoded.userId, name: decoded.name, isGuest: true }, JWT_SECRET);
    let User: UserDetails = {
      id: decoded.userId,
      name: decoded.name,
      token: token,
      isGuest: true,
    };
    res.cookie('guest', token, cookieOptions);
    res.json(User);
  } else {
    res.status(401).json({ success: false, message: 'Unauthorized' });
  }
});

router.get('/login/failed', (req: Request, res: Response) => {
  res.status(401).json({ success: false, message: 'failure' });
});

router.get('/logout', (req: Request, res: Response) => {
  const { FRONTEND_URL } = getConfig();
  res.clearCookie('guest');
  res.clearCookie('connect.sid');

  req.logout((err) => {
    if (err) {
      console.error('Error logging out:', err);
      res.status(500).json({ error: 'Failed to log out' });
    } else {
      res.clearCookie('jwt');
      res.redirect(FRONTEND_URL);
    }
  });
});

router.get('/google', passport.authenticate('google', { scope: ['profile', 'email'] }));

router.get(
  '/google/callback',
  (req: Request, res: Response, next) => {
    const { CLIENT_URL } = getConfig();
    passport.authenticate('google', {
      successRedirect: CLIENT_URL,
      failureRedirect: '/auth/login/failed',
    })(req, res, next);
  }
);

router.get('/github', passport.authenticate('github', { scope: ['read:user', 'user:email'] }));

router.get(
  '/github/callback',
  (req: Request, res: Response, next) => {
    const { CLIENT_URL } = getConfig();
    passport.authenticate('github', {
      successRedirect: CLIENT_URL,
      failureRedirect: '/auth/login/failed',
    })(req, res, next);
  }
);

export default router;
