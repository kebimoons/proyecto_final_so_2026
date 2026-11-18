# ==============================================================================
# Dockerfile - [Plantilla Base: Rol 2 - Desarrollador de App y Escalabilidad]
# ==============================================================================
FROM node:20-alpine

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./

# TODO [Rol 2]: Ajustar variables de entorno para procesos cluster y pool libuv
ENV NODE_ENV=production
ENV PORT=3000
ENV APP_WORKERS=2
ENV UV_THREADPOOL_SIZE=4

EXPOSE 3000

CMD ["node", "server.js"]
