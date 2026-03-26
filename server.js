// This is a test express app -
//
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import morgan from 'morgan';
import {
  createHtmlContent,
} from './utils.js';
import helloRoute from './routes/hello.js';

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(morgan('dev')); // HTTP request logger
app.use(express.json()); // Parse JSON request bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded request bodies

// Serve static files from the public directory
app.use(express.static(path.join(__dirname, 'public')));

// Root route
app.get('/', (req, res) => {
  res.send('<h1>Welcome to the Primer Express App</h1><ul><li><a href="/api?name=test">/api</a></li><li><a href="/api/health">/api/health</a></li><li><a href="/hello?name=world">/hello</a></li></ul>');
});

// API Routes
app.get('/api', (req, res) => {
  res.send(`API, ${req.query.name}!`);
});

// Health check route
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

app.post('/api/calculate', (req, res) => {
  const { expression } = req.body;

  if (!expression) {
    return res.status(400).json({ error: 'Expression is required' });
  }

  res.send(createHtmlContent(expression));

});

// Use hello route
app.use(helloRoute);

// Send index.html for all other routes (for client-side routing)
// app.get('*', (req, res) => {
//   res.sendFile(path.join(__dirname, 'public', 'index.html'));
// });

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
