# base node image
FROM alpine as base

# set for base and all layer that inherit from it
ENV NODE_ENV production
ENV PNPM_HOME=/root/.local/share/pnpm
ENV PATH=$PATH:$PNPM_HOME

# Install openssl for Prisma
RUN apt-get update && apt-get install -y openssl

RUN apk add --no-cache curl && \
  curl -fsSL "https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}/pnpm-linuxstatic-x64" -o /bin/pnpm && chmod +x /bin/pnpm && \
  apk del curl

# Install all node_modules, including dev dependencies
FROM base as deps

WORKDIR /myapp

ADD package.json .npmrc ./
RUN pnpm install --production=false

# Setup production node_modules
FROM base as production-deps

WORKDIR /myapp

COPY --from=deps /myapp/node_modules /myapp/node_modules
ADD package.json .npmrc ./
RUN pnpm prune --production

# Build the app
FROM base as build

WORKDIR /myapp

COPY --from=deps /myapp/node_modules /myapp/node_modules

ADD prisma .
RUN pnpm dlx prisma generate

ADD . .
RUN pnpm run build

# Finally, build the production image with minimal footprint
FROM base

WORKDIR /myapp

COPY --from=production-deps /myapp/node_modules /myapp/node_modules
COPY --from=build /myapp/node_modules/.prisma /myapp/node_modules/.prisma

COPY --from=build /myapp/build /myapp/build
COPY --from=build /myapp/public /myapp/public
ADD . .

CMD ["pnpm", "start"]
