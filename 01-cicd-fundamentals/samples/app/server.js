const express = require('express');
const os = require('os');

const app = express();
const port = process.env.PORT || 3000;

app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));

app.get('/', (_req, res) => {
  res.json({
    service: 'aws-devops-platform sample',
    version: process.env.APP_VERSION || 'dev',
    host: os.hostname(),
  });
});

app.listen(port, () => console.log(`listening on :${port}`));
