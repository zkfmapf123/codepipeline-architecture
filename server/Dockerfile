ARG NODE_VERSION=18.19.0

FROM node:${NODE_VERSION}-alpine

ENV NODE_ENV production


WORKDIR /usr/src/app
COPY package*.json .

RUN npm install
COPY . .        

EXPOSE 3000

ENV PORT=3000
ENV VER=1

CMD ["node index.js"]
