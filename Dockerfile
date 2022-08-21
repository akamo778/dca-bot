# syntax=docker/dockerfile:1
FROM node:16 AS builder
ENV NODE_ENV=development
WORKDIR /app
COPY package.json ./
COPY yarn.lock ./
RUN yarn install
COPY . .
RUN yarn build

FROM node:16 AS runner
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./
COPY yarn.lock ./
COPY start.sh ./
RUN yarn install
COPY --from=builder /app/dist ./dist
RUN chmod +x ./start.sh
CMD ["./start.sh"]