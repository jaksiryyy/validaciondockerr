# Multi-stage Dockerfile para aplicaciones Node.js

# ================================
# Etapa base común
# ================================
FROM node:18-alpine AS base
WORKDIR /app

# Instalar dependencias del sistema si es necesario
RUN apk add --no-cache \
    dumb-init \
    && addgroup -g 1001 -S nodejs \
    && adduser -S nextjs -u 1001

# ================================
# Etapa de dependencias
# ================================
FROM base AS deps
# Copiar archivos de dependencias
COPY package.json package-lock.json* ./
COPY yarn.lock* ./

# Instalar dependencias basado en el gestor de paquetes disponible
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then npm install -g pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# ================================
# Etapa de construcción (para apps que necesitan build)
# ================================
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Variables de entorno para build
ENV NEXT_TELEMETRY_DISABLED 1
ENV NODE_ENV production

# Ejecutar build (ajusta según tu framework)
RUN \
  if [ -f "next.config.js" ]; then npm run build; \
  elif [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then npm run build; \
  elif [ -f "vue.config.js" ]; then npm run build; \
  elif [ -f "angular.json" ]; then npm run build; \
  else echo "No build configuration found, skipping build step"; \
  fi

# ================================
# Etapa de desarrollo
# ================================
FROM base AS development
WORKDIR /app

# Instalar todas las dependencias (incluyendo devDependencies)
COPY package.json package-lock.json* ./
RUN npm ci

# Copiar código fuente
COPY . .

# Crear usuario no-root
USER nextjs

# Exponer puerto
EXPOSE 3000

# Variables de entorno
ENV NODE_ENV development
ENV PORT 3000

# Comando por defecto para desarrollo
CMD ["dumb-init", "npm", "run", "dev"]

# ================================
# Etapa de producción
# ================================
FROM base AS production
WORKDIR /app

# Variables de entorno
ENV NODE_ENV production
ENV PORT 3000
ENV NEXT_TELEMETRY_DISABLED 1

# Copiar solo dependencias de producción
COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

# Copiar código fuente
COPY --chown=nextjs:nodejs . .

# Si hay build, copiar los archivos construidos
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next 2>/dev/null || :
COPY --from=builder --chown=nextjs:nodejs /app/dist ./dist 2>/dev/null || :
COPY --from=builder --chown=nextjs:nodejs /app/build ./build 2>/dev/null || :

# Cambiar a usuario no-root
USER nextjs

# Exponer puerto
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js || exit 1

# Comando por defecto
CMD ["dumb-init", "npm", "start"]

# ================================
# Etapa por defecto (producción)
# ================================
FROM production AS default
