const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// Подключение к PostgreSQL (настройки берутся из переменных окружения AWS)
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    // Если RDS требует SSL (некоторые конфигурации), можно включить:
    // ssl: { rejectUnauthorized: false }
});

// Проверка подключения и создание таблицы при старте
pool.query(`CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)`, (err) => {
    if (err) {
        console.error('Ошибка при инициализации таблицы в PostgreSQL:', err.message);
    } else {
        console.log('Успешное подключение и проверка таблицы в PostgreSQL.');
    }
});

// Главная страница с формой
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html lang="ru">
        <head>
            <meta charset="UTF-8">
            <title>Форма регистрации</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 50px; background: #f4f4f9; }
                form { background: white; padding: 20px; border-radius: 8px; max-width: 400px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                input { width: 100%; padding: 8px; margin: 10px 0; box-sizing: border-box; border: 1px solid #ccc; border-radius: 4px; }
                button { background: #007bff; color: white; border: none; padding: 10px 15px; border-radius: 4px; cursor: pointer; }
                button:hover { background: #0056b3; }
                ul { margin-top: 20px; background: white; padding: 20px; border-radius: 8px; max-width: 400px; }
            </style>
        </head>
        <body>
            <h2>Форма обратной связи (AWS RDS)</h2>
            <form action="/submit" method="POST">
                <label>Имя:</label>
                <input type="text" name="name" required>
                <label>Email:</label>
                <input type="email" name="email" required>
                <button type="submit">Отправить</button>
            </form>
            <h3>Сохраненные записи:</h3>
            <ul id="list"></ul>
            <script>
                fetch('/messages')
                    .then(res => res.json())
                    .then(data => {
                        const list = document.getElementById('list');
                        data.forEach(item => {
                            const li = document.createElement('li');
                            li.textContent = \`\${item.name} (\${item.email})\`;
                            list.appendChild(li);
                        });
                    });
            </script>
        </body>
        </html>
    `);
});

// Обработка отправки
app.post('/submit', async (req, res) => {
    const { name, email } = req.body;
    try {
        await pool.query(
            `INSERT INTO messages (name, email) VALUES ($1, $2)`,
            [name, email]
        );
        res.redirect('/');
    } catch (err) {
        console.error('Ошибка сохранения:', err.message);
        res.status(500).send("Ошибка сохранения данных в базу.");
    }
});

// Получение списка записей
app.get('/messages', async (req, res) => {
    try {
        const result = await pool.query(`SELECT * FROM messages ORDER BY id DESC`);
        res.json(result.rows);
    } catch (err) {
        console.error('Ошибка чтения:', err.message);
        res.status(500).json({ error: err.message });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Сервер запущен на порту ${PORT}`);
});