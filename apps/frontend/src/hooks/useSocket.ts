import { useCallback, useEffect, useRef, useState } from 'react';
import { useUser } from '@repo/store/useUser';

const WS_URL = import.meta.env.VITE_APP_WS_URL ?? 'ws://localhost:8080';

const BASE_DELAY_MS = 3000;
const MAX_DELAY_MS = 30000;

// Close code used by the server when auth fails — no point retrying
const AUTH_FAILED_CODE = 4401;

export const useSocket = () => {
  const [socket, setSocket] = useState<WebSocket | null>(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const user = useUser();

  // Use refs so the reconnect closure always sees the latest values
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const attemptRef = useRef(0);
  const unmountedRef = useRef(false);

  const clearReconnectTimer = useCallback(() => {
    if (reconnectTimerRef.current !== null) {
      clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
  }, []);

  const connect = useCallback(() => {
    if (unmountedRef.current || !user?.token) return;

    setIsConnecting(true);

    const ws = new WebSocket(`${WS_URL}?token=${user.token}`);
    wsRef.current = ws;

    ws.onopen = () => {
      if (unmountedRef.current) {
        ws.close();
        return;
      }
      attemptRef.current = 0; // reset backoff on successful connect
      setSocket(ws);
      setIsConnecting(false);
    };

    ws.onclose = (event) => {
      setSocket(null);

      // Do not retry if the server explicitly rejected the token
      if (event.code === AUTH_FAILED_CODE || unmountedRef.current) return;

      // Exponential backoff: 3s, 6s, 12s, … capped at 30s
      const delay = Math.min(BASE_DELAY_MS * 2 ** attemptRef.current, MAX_DELAY_MS);
      attemptRef.current += 1;

      reconnectTimerRef.current = setTimeout(connect, delay);
    };

    ws.onerror = () => {
      // onerror is always followed by onclose — close explicitly to trigger backoff
      ws.close();
    };
  }, [user]);

  useEffect(() => {
    if (!user) return;

    unmountedRef.current = false;
    attemptRef.current = 0;
    connect();

    return () => {
      unmountedRef.current = true;
      clearReconnectTimer();
      wsRef.current?.close();
    };
  }, [user, connect]);

  return { socket, isConnecting };
};
