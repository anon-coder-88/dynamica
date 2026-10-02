import vinext from 'vinext';
import { defineConfig } from 'vite';

// Standalone GitHub build; the original application routes and assets are reused.
export default defineConfig({ plugins: [vinext()] });
