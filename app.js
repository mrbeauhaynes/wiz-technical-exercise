const express = require('express');
const mongoose = require('mongoose');

const app = express();
const port = process.env.PORT || 80;
const mongoUri = process.env.MONGO_URI || 'mongodb://appuser:apppassword@127.0.0.1:27017/tododb?authSource=tododb';

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connect to MongoDB
mongoose.connect(mongoUri, {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => {
  console.log('Successfully connected to MongoDB');
}).catch(err => {
  console.error('Database connection error:', err);
});

// Task Schema
const TaskSchema = new mongoose.Schema({
  title: String,
  createdAt: { type: Date, default: Date.now }
});

const Task = mongoose.model('Task', TaskSchema);

// Web UI Route
app.get('/', async (req, res) => {
  try {
    const tasks = await Task.find().sort({ createdAt: -1 });
    let taskListHtml = tasks.map(t => `<li>${t.title} <small>(${t.createdAt.toISOString()})</small></li>`).join('');
    
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Wiz Assessment - Tasks</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; background: #f8fafc; color: #1e293b; }
          .container { max-width: 600px; margin: 0 auto; background: white; padding: 24px; border-radius: 8px; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); }
          input[type="text"] { width: 70%; padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; }
          button { padding: 8px 16px; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer; }
          ul { margin-top: 20px; padding-left: 20px; }
          li { margin-bottom: 8px; }
        </style>
      </head>
      <body>
        <div class="container">
          <h2>Wiz Technical Assessment: Task Board</h2>
          <form method="POST" action="/task">
            <input type="text" name="title" placeholder="Enter new task..." required />
            <button type="submit">Add Task</button>
          </form>
          <ul>${taskListHtml}</ul>
        </div>
      </body>
      </html>
    `);
  } catch (err) {
    res.status(500).send('Error loading tasks: ' + err.message);
  }
});

// Create Task Route
app.post('/task', async (req, res) => {
  try {
    await Task.create({ title: req.body.title });
    res.redirect('/');
  } catch (err) {
    res.status(500).send('Error saving task: ' + err.message);
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});