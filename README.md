# ChessVerse

A real-time multiplayer chess platform built with React, Node.js, WebSockets, and PostgreSQL.

## Features

### 🎮 Core Gameplay

- **Real-time Multiplayer**: Play chess against other players with WebSocket-based real-time communication
- **Random Matchmaking**: Quick match with players of similar skill level
- **Game Modes**:
  - Play Online (Active)
  - More modes coming soon
- **Guest Play**: Jump into games without registration
- **Move History**: Track and review all moves made during the game
- **Time Controls**: 10-minute games with time tracking for each player

### 🎨 User Interface

- **Customizable Themes**:
  - Default (Green & Cream)
  - Bubblegum (Pink theme)
- **Interactive Board**:
  - Visual move indicators
  - Legal move highlighting
  - Drag-and-drop piece movement
  - Right-click to draw arrows and highlight squares
- **Move Navigation**: Review previous positions in the game
- **Board Flip**: View the board from either player's perspective

### 👤 User Features

- **Multiple Auth Options**:
  - Google OAuth
  - GitHub OAuth
  - Guest Mode
- **Session Management**: Automatic session refresh with secure cookies
- **User Profiles**: Track your games and statistics

### 🎯 Game Features

- **Game Sharing**: Share game links to play with friends
- **Exit Game**: Resign from ongoing games
- **Game Results**: Clear display of win/loss/draw outcomes
- **Opponent Tracking**: See opponent information and connection status
- **Reconnection**: Resume games after disconnection

## Tech Stack

### Frontend (`apps/frontend`)

- React with TypeScript
- Vite for build tooling
- TailwindCSS for styling
- Recoil for state management
- Chess.js for game logic
- Radix UI components

### Backend (`apps/backend`)

- Node.js with Express
- Passport.js for authentication
- PostgreSQL with Prisma ORM
- Session management with express-session

### WebSocket Server (`apps/ws`)

- WebSocket server for real-time gameplay
- JWT authentication
- Game state management
- PostgreSQL with Prisma ORM

### Packages

- `packages/db`: Shared Prisma schema and database client
- `packages/store`: Shared Recoil atoms and state management
- `packages/ui`: Shared UI components
- `packages/eslint-config`: Shared ESLint configurations
- `packages/typescript-config`: Shared TypeScript configurations

## Getting Started Locally

### Prerequisites

- Node.js 20+
- Yarn package manager
- PostgreSQL database
- Google OAuth credentials (optional)
- GitHub OAuth credentials (optional)

### Option 1: Quick Start with Yarn

1. **Clone the repository**

```sh
git clone <repository-url>
cd ChessVerse
```

2. **Install dependencies**

```sh
yarn install
```

3. **Set up environment variables**

Create `.env` files in the following locations:

**`apps/backend/.env`**:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/chessverse"
JWT_SECRET="your-jwt-secret-key"
COOKIE_SECRET="your-cookie-secret"
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GITHUB_CLIENT_ID="your-github-client-id"
GITHUB_CLIENT_SECRET="your-github-client-secret"
AUTH_REDIRECT_URL="http://localhost:5173/game/random"
FRONTEND_URL="http://localhost:5173"
ALLOWED_HOSTS="http://localhost:5173"
PORT=3000
```

**`apps/ws/.env`**:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/chessverse"
JWT_SECRET="your-jwt-secret-key"
```

**`apps/frontend/.env`**:

```env
VITE_APP_BACKEND_URL="http://localhost:3000"
VITE_APP_WS_URL="ws://localhost:8080"
```

4. **Set up the database**

```sh
# Generate Prisma client
npx prisma generate --schema=packages/db/prisma/schema.prisma

# Run migrations
npx prisma migrate dev --schema=packages/db/prisma/schema.prisma
```

5. **Start all services**

```sh
yarn dev
```

This will start:

- Frontend: http://localhost:5173
- Backend API: http://localhost:3000
- WebSocket Server: ws://localhost:8080

### Option 2: Docker Setup

1. **Clone the repository**

```sh
git clone <repository-url>
cd ChessVerse
```

2. **Set up environment variables**

Create a `.env` file in the root directory:

```env
# Database
DATABASE_URL="postgresql://postgres:password@postgres:5432/chessverse"

# Backend
JWT_SECRET="your-jwt-secret-key"
COOKIE_SECRET="your-cookie-secret"
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GITHUB_CLIENT_ID="your-github-client-id"
GITHUB_CLIENT_SECRET="your-github-client-secret"
AUTH_REDIRECT_URL="http://localhost/game/random"
FRONTEND_URL="http://localhost"
ALLOWED_HOSTS="http://localhost"
PORT=3000

# Frontend Build Args
VITE_APP_BACKEND_URL="http://localhost/api"
VITE_APP_WS_URL="ws://localhost/ws"
```

3. **Build and start with Docker Compose**

```sh
docker-compose -f docker-compose.prod.yml up --build
```

This will:

- Set up PostgreSQL database
- Build and run the backend service
- Build and run the WebSocket service
- Build and run the frontend with Nginx
- Configure networking between services

4. **Access the application**

- Frontend: http://localhost
- Backend API: http://localhost/api
- WebSocket: ws://localhost/ws

5. **Stop the services**

```sh
docker-compose -f docker-compose.prod.yml down
```

## Project Structure

```
ChessVerse/
├── apps/
│   ├── backend/          # Express API server
│   ├── frontend/         # React frontend
│   └── ws/              # WebSocket game server
├── packages/
│   ├── db/              # Prisma schema & client
│   ├── store/           # Recoil state management
│   ├── ui/              # Shared UI components
│   ├── eslint-config/   # ESLint configurations
│   └── typescript-config/ # TypeScript configurations
├── docker-compose.prod.yml
└── turbo.json          # Turborepo configuration
```

## Available Scripts

### Development

```sh
yarn dev              # Start all services in development mode
yarn build           # Build all packages and apps
yarn lint            # Run ESLint on all packages
```

### Individual Services

```sh
# Backend
cd apps/backend
yarn dev

# Frontend
cd apps/frontend
yarn dev

# WebSocket Server
cd apps/ws
yarn dev
```

### Database

```sh
# Generate Prisma client
npx prisma generate --schema=packages/db/prisma/schema.prisma

# Run migrations
npx prisma migrate dev --schema=packages/db/prisma/schema.prisma

# Open Prisma Studio
npx prisma studio --schema=packages/db/prisma/schema.prisma
```

## Authentication Setup

### Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URI: `http://localhost:3000/auth/google/callback`
6. Copy Client ID and Client Secret to `.env`

### GitHub OAuth

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Create a new OAuth App
3. Set Authorization callback URL: `http://localhost:3000/auth/github/callback`
4. Copy Client ID and Client Secret to `.env`

## Game Flow

1. **Login**: User authenticates via Google, GitHub, or plays as guest
2. **Matchmaking**: Click "Play Online" to join random matchmaking
3. **Game Start**: When matched, board initializes with pieces
4. **Gameplay**:
   - Make moves by dragging pieces
   - Time tracking for each player
   - Real-time updates via WebSocket
5. **Game End**: Results displayed with winner announcement
6. **Review**: Navigate through move history

## Contributing

This is a monorepo managed by Turborepo. When contributing:

1. Follow the existing code structure
2. Run `yarn lint` before committing
3. Update documentation as needed



## Support

For issues and questions, please open an issue on the GitHub repository.
