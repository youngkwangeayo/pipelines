import { defineConfig, Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'
import { visualizer } from 'rollup-plugin-visualizer'

// 환경별 CSP 정책
const CSP_POLICIES = {
  // 개발 환경: http 허용 (localhost API)
  development: `
    default-src 'self';
    script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:;
    style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
    font-src 'self' https://fonts.gstatic.com data:;
    img-src 'self' data: blob: https: http:;
    connect-src 'self' https: http: wss: ws:;
    frame-src 'self';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
  `.replace(/\s+/g, ' ').trim(),

  // 프로덕션 환경: https만 허용
  production: `
    default-src 'self';
    script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:;
    style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
    font-src 'self' https://fonts.gstatic.com data:;
    img-src 'self' data: blob: https:;
    connect-src 'self' https: wss:;
    frame-src 'self';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    upgrade-insecure-requests;
  `.replace(/\s+/g, ' ').trim(),
}

// CSP 주입 플러그인
function cspPlugin(): Plugin {
  return {
    name: 'csp-plugin',
    transformIndexHtml(html, ctx) {
      const isDev = ctx.server !== undefined
      const csp = isDev ? CSP_POLICIES.development : CSP_POLICIES.production
      const cspMeta = `<meta http-equiv="Content-Security-Policy" content="${csp}" />`
      return html.replace('<!-- CSP는 vite.config.ts에서 환경별로 주입 -->', cspMeta)
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    cspPlugin(),
    visualizer({
      open: true,
      filename: 'dist/stats.html',
      gzipSize: true,
      brotliSize: true,
    })
  ],
  envDir: './env',  // env 폴더에서 환경변수 파일 읽기
  server: {
    port: 5173,
    allowedHosts: true
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
    extensions: ['.mjs', '.js', '.jsx', '.ts', '.tsx', '.json']
  },
  optimizeDeps: {
    esbuildOptions: {
      loader: {
        '.js': 'jsx',
      },
    },
  },
  esbuild: {
    // 프로덕션 빌드에서 console.log, debugger 제거
    drop: process.env.NODE_ENV === 'production' ? ['console', 'debugger'] : [],
  },
  build: {
    minify: 'esbuild',
    rollupOptions: {
      output: {
        manualChunks: {
          // React 코어
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],

          // Radix UI 컴포넌트 (사용 중인 것만)
          'radix-ui': [
            '@radix-ui/react-alert-dialog',
            '@radix-ui/react-dialog',
            '@radix-ui/react-dropdown-menu',
            '@radix-ui/react-label',
            '@radix-ui/react-popover',
            '@radix-ui/react-select',
            '@radix-ui/react-separator',
            '@radix-ui/react-switch',
            '@radix-ui/react-tabs',
            '@radix-ui/react-tooltip',
          ],

          // 차트 라이브러리
          'charts': ['recharts'],

          // 서버 상태 관리
          'react-query': ['@tanstack/react-query'],

          // 다국어
          'i18n': ['i18next', 'react-i18next'],

          // 애니메이션
          'animation': ['framer-motion'],

          // 3D 그래픽 (AIOntology 전용)
          'three': ['three'],

          // 유틸리티
          'utils': [
            'date-fns',
            'clsx',
            'tailwind-merge',
            'class-variance-authority',
          ],
        },
      },
    },
    chunkSizeWarningLimit: 1000, // 1MB로 경고 제한 상향 (더 관대하게)
  },
}) 