import jwt, { TokenExpiredError } from 'jsonwebtoken';
import { User } from '../SocketManager';
// import { Player } from '../Game';
import { WebSocket } from 'ws';
import dotenv from 'dotenv';

dotenv.config();

export interface userJwtClaims {
  userId: string;
  name: string;
  isGuest?: boolean;
}

export const extractAuthUser = (token: string, ws: WebSocket): User => {
  // Read lazily so dotenv has always loaded by call time
  const JWT_SECRET = process.env.JWT_SECRET || 'your_secret_key';
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as userJwtClaims;
    return new User(ws, decoded);
  } catch (err) {
    if (err instanceof TokenExpiredError) {
      ws.close(4401, 'Token expired. Please re-authenticate.');
    } else {
      ws.close(4401, 'Invalid token.');
    }
    throw err; // let index.ts skip addUser for this connection
  }
};
