const express = require('express');
const app = express();
const PORT = 3000;

app.use(express.json());

let statsDatabase = {}; // Example structure: { "PlayerName": { Donated: 100, Raised: 200 } }

app.get('/checkstats', (req, res) => {
  const { player, stat } = req.query;

  if (!player || !stat) return res.json({ success: false, message: 'Missing player or stat' });

  const playerStats = statsDatabase[player];
  if (!playerStats || playerStats[stat] == null) return res.json({ success: false });

  res.json({ success: true, value: playerStats[stat] });
});

// Roblox server would POST updates to this API
app.post('/updatestats', (req, res) => {
  const { player, stat, value } = req.body;

  if (!player || !stat || value == null) return res.status(400).send('Invalid data');

  if (!statsDatabase[player]) statsDatabase[player] = {};
  statsDatabase[player][stat] = value;

  res.send('Stat updated');
});

app.listen(PORT, () => console.log(`API server running on port ${PORT}`));
