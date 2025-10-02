# Use the official lightweight Node.js image.
FROM node:lts-bookworm-slim

# Create and change to the app directory.
WORKDIR /usr/src/app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY ./code/src ./code/src

# Keep container running for inspection
# CMD ["sleep", "infinity"]
CMD ["npm", "start"]