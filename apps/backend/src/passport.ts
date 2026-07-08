const GoogleStrategy = require('passport-google-oauth20').Strategy;
const GithubStrategy = require('passport-github2').Strategy;
import passport from 'passport';
import { db } from './db';

interface GithubEmailRes {
  email: string;
  primary: boolean;
  verified: boolean;
  visibility: 'private' | 'public';
}

export function initPassport() {
  const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
  const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
  const GITHUB_CLIENT_ID = process.env.GITHUB_CLIENT_ID;
  const GITHUB_CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET;

  if (
    !GOOGLE_CLIENT_ID ||
    !GOOGLE_CLIENT_SECRET ||
    !GITHUB_CLIENT_ID ||
    !GITHUB_CLIENT_SECRET
  ) {
    throw new Error(
      'Missing environment variables for authentication providers',
    );
  }


  passport.use(
    new GoogleStrategy(
      {
        clientID: GOOGLE_CLIENT_ID,
        clientSecret: GOOGLE_CLIENT_SECRET,
        callbackURL: '/auth/google/callback',
      },
      async function (
        accessToken: string,
        refreshToken: string,
        profile: any,
        done: (error: any, user?: any) => void,
      ) {
        const user = await db.user.upsert({
          create: {
            email: profile.emails[0].value,
            name: profile.displayName,
            provider: 'GOOGLE',
          },
          update: {
            name: profile.displayName,
          },
          where: {
            email: profile.emails[0].value,
          },
        });

        done(null, user);
      },
    ),
  );

  passport.use(
    new GithubStrategy(
      {
        clientID: GITHUB_CLIENT_ID,
        clientSecret: GITHUB_CLIENT_SECRET,
        callbackURL: '/auth/github/callback',
      },
      async function (
        accessToken: string,
        refreshToken: string,
        profile: any,
        done: (error: any, user?: any) => void,
      ) {
        const res = await fetch('https://api.github.com/user/emails', {
          headers: {
            Authorization: `token ${accessToken}`,
          },
        });
        const data: GithubEmailRes[] = await res.json();
        const primaryEmail = data.find((item) => item.primary === true);

        const user = await db.user.upsert({
          create: {
            email: primaryEmail!.email,
            name: profile.displayName,
            provider: 'GITHUB',
          },
          update: {
            name: profile.displayName,
          },
          where: {
            email: primaryEmail?.email,
          },
        });

        done(null, user);
      },
    ),
  );

  passport.serializeUser(function (user: any, cb) {
    process.nextTick(function () {
      return cb(null, {
        id: user.id,
        username: user.username,
        picture: user.picture,
      });
    });
  });

  passport.deserializeUser(function (user: any, cb) {
    process.nextTick(function () {
      return cb(null, user);
    });
  });
}
