import {defineConfig, loadEnv} from 'vite';
import react from '@vitejs/plugin-react';
import {fileURLToPath, URL} from 'node:url';
export default defineConfig(({mode})=>{
 const env=loadEnv(mode, process.cwd(), 'NEXT_PUBLIC_');
 // Reuse the existing site's public contract-address configuration unchanged.
 return {plugins:[react()],resolve:{alias:{'@':fileURLToPath(new URL('.',import.meta.url))}},define:{
  'process.env.NEXT_PUBLIC_DYNAMICA_ASSET_ADDRESS':JSON.stringify(env.NEXT_PUBLIC_DYNAMICA_ASSET_ADDRESS||''),
  'process.env.NEXT_PUBLIC_DYNAMICA_VAULT_ADDRESS':JSON.stringify(env.NEXT_PUBLIC_DYNAMICA_VAULT_ADDRESS||'')
 }};
});
