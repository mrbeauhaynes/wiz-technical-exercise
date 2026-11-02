FROM node:18-alpine

WORKDIR /app

# Dependency installation
COPY package*.json ./
RUN npm install --production

# Application code
COPY app.js ./

# Requirement: Inject wizexercise.txt containing your full name into the container image
RUN echo "Candidate Name: Beau Haynes Sr." > /app/wizexercise.txt

EXPOSE 80

CMD ["node", "app.js"]