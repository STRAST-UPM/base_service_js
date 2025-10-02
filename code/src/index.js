import http from 'http';

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  console.info({ message: 'Hello World Worker received a request!' });
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('hello world!');
});

server.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}/`);
});
