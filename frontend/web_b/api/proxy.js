const https = require('https');

module.exports = function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const { targetUrl, query, variables } = req.body || {};
  if (!targetUrl) return res.status(400).json({ error: 'targetUrl required' });

  const parsed = new URL(targetUrl);
  const ALLOWED_HOSTS = [
    'localhost', '127.0.0.1',
    'conway1.linera.blockhunters.services',
    'faucet.testnet-conway.linera.net',
    'api.testnet-conway.linera.net',
  ];
  if (!ALLOWED_HOSTS.includes(parsed.hostname)) {
    return res.status(403).json({ error: 'Target host not allowed' });
  }

  const postData = JSON.stringify({ query, variables });

  const options = {
    hostname: parsed.hostname,
    port: parsed.port || 443,
    path: parsed.pathname + parsed.search,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData),
    },
  };

  const proxyReq = https.request(options, (proxyRes) => {
    let data = '';
    proxyRes.on('data', (chunk) => { data += chunk; });
    proxyRes.on('end', () => {
      try {
        res.status(proxyRes.statusCode).json(JSON.parse(data));
      } catch (e) {
        res.status(proxyRes.statusCode).send(data);
      }
    });
  });

  proxyReq.on('error', (error) => {
    res.status(502).json({ error: 'Proxy failed', message: error.message });
  });

  proxyReq.write(postData);
  proxyReq.end();
};
