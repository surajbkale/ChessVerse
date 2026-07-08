import { WebSocketServer } from 'ws';
import { GameManager } from './GameManager';
import url from 'url';
import { extractAuthUser } from './auth';
import http from 'http';

const PORT = parseInt(process.env.PORT || '8080', 10);

// Minimal HTTP server so Render can perform health checks
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
  } else {
    res.writeHead(404);
    res.end();
  }
});

const wss = new WebSocketServer({ server });

const gameManager = new GameManager();

wss.on('connection', function connection(ws, req) {
  //@ts-ignore
  const token: string = url.parse(req.url, true).query.token;
  let user;
  try {
    user = extractAuthUser(token, ws);
  } catch (err) {
    // extractAuthUser already closed the socket; just bail out
    console.error('WS auth failed:', (err as Error).message);
    return;
  }
  gameManager.addUser(user);

  ws.on('close', () => {
    gameManager.removeUser(ws);
  });
});

server.listen(PORT, () => {
  console.log(`WS server listening on port ${PORT}`);
});
