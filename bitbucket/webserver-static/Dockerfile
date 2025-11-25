FROM node:22

WORKDIR /usr/src/server_app

COPY ./server.js package.json ./

RUN mkdir build
RUN npm install


CMD ["node", "server.js"]