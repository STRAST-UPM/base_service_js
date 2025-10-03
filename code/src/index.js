import http from 'http';

const PORT = process.env.PORT || 3000;
const REGION = process.env.REGION || 'unknown';

const server = http.createServer((req, res) => {
  console.info({ message: 'Request received', path: req.url, method: req.method });
  
  res.setHeader('Content-Type', 'application/json');
  
  if (req.method === 'GET' && req.url === '/') {
    res.writeHead(200);
    res.end(JSON.stringify({
      message: 'Hello World',
      region: REGION
    }));
  } else {
    res.writeHead(404);
    res.end(JSON.stringify({
      error: 'Not Found',
      region: REGION
    }));
  }
});

server.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}/`);
  console.log(`Server region: ${REGION}`);
});
