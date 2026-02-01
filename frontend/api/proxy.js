// Vercel Serverless Function - Proxy to Conway Testnet
// This bypasses CORS by proxying requests server-side

export default async function handler(req, res) {
  // Enable CORS for all origins
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST requests for GraphQL
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Get the target URL from query parameter or use default Conway endpoint
    const targetUrl = req.query.url || 'https://conway1.linera.blockhunters.services';
    const path = req.query.path || '';

    const fullUrl = `${targetUrl}${path}`;

    // Forward the GraphQL request to Conway Testnet
    const response = await fetch(fullUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...req.headers,
      },
      body: JSON.stringify(req.body),
    });

    const data = await response.json();

    // Return the response from Conway
    res.status(response.status).json(data);
  } catch (error) {
    console.error('Proxy error:', error);
    res.status(500).json({
      error: 'Proxy request failed',
      message: error.message
    });
  }
}
