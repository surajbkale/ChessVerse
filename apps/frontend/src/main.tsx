import ReactDOM from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import { setBackendUrl } from '@repo/store/userAtom';

// Must run before React renders so Recoil's userAtom default selector
// uses the correct backend URL instead of a relative path (which breaks on Vercel).
setBackendUrl(import.meta.env.VITE_APP_BACKEND_URL ?? '');

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);

