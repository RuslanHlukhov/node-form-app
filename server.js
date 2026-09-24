const express = require('express');
const { Pool } = require('pg');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcrypt');

const app = express();
const PORT = process.env.PORT || 3000;

const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET_NAME = process.env.S3_BUCKET_NAME;

const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) cb(null, true);
        else cb(new Error('Only images allowed'));
    },
});

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

pool.on('error', (err) => console.error('Unexpected DB error:', err.message));

pool.query(`CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    photo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)`, (err) => {
    if (err) console.error('Ошибка при инициализации таблицы:', err.message);
    else console.log('Таблица users успешно проверена/создана.');
});

app.post('/register', upload.single('photo'), async (req, res) => {
    const { username, email, password } = req.body;
    const file = req.file;

    try {
        let photoUrl = null;

        if (file) {
            const ext = path.extname(file.originalname).toLowerCase();
            const fileName = `photos/${crypto.randomUUID()}${ext}`;

            await s3Client.send(new PutObjectCommand({
                Bucket: BUCKET_NAME,
                Key: fileName,
                Body: file.buffer,
                ContentType: file.mimetype,
            }));

            photoUrl = `https://${BUCKET_NAME}.s3.amazonaws.com/${fileName}`;
        }

        const passwordHash = await bcrypt.hash(password, 10);

        await pool.query(
            `INSERT INTO users (username, email, password, photo_url) VALUES ($1, $2, $3, $4)`,
            [username, email, passwordHash, photoUrl]
        );

        res.send(`<h2>Регистрация прошла успешно!</h2><p><a href="/">Назад</a></p>`);
    } catch (err) {
        console.error('Ошибка при регистрации:', err.message);
        res.status(500).send('Ошибка сервера при регистрации.');
    }
});

app.get('/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.status(200).send('ok');
    } catch (err) {
        res.status(503).send('db unavailable');
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Сервер запущен на порту ${PORT}`);
});