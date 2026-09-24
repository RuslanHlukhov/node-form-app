const express = require('express');
const { Pool } = require('pg');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Настройка S3 клиента (подхватит IAM роль инстанса)
const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET_NAME = process.env.S3_BUCKET_NAME;

// Настройка Multer для сохранения файлов в память
const upload = multer({ storage: multer.memoryStorage() });

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// Раздача статических файлов из папки 'public' (где лежит index.html)
app.use(express.static(path.join(__dirname, 'public')));

// Подключение к PostgreSQL
const connectionString = process.env.DATABASE_URL || "postgres://dbadmin:teastdatabase1994!@node-app-postgres-db.cvygc8msofus.us-east-1.rds.amazonaws.com:5432/formapp";

console.log("DEBUG DATABASE_URL:", connectionString);
const pool = new Pool({
    connectionString: connectionString,
    ssl: {
        rejectUnauthorized: false
    }
});

// Инициализация таблицы
pool.query(`CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    photo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)`, (err) => {
    if (err) {
        console.error('Ошибка при инициализации таблицы:', err.message);
    } else {
        console.log('Таблица users успешно проверена/создана.');
    }
});

// Обработка регистрации с загрузкой фото в S3
app.post('/register', upload.single('photo'), async (req, res) => {
    const { username, email, password } = req.body;
    const file = req.file;

    try {
        let photoUrl = null;

        if (file) {
            const fileName = `photos/${Date.now()}-${file.originalname}`;
            
            await s3Client.send(new PutObjectCommand({
                Bucket: BUCKET_NAME,
                Key: fileName,
                Body: file.buffer,
                ContentType: file.mimetype,
            }));

            photoUrl = `https://${BUCKET_NAME}.s3.amazonaws.com/${fileName}`;
        }

        await pool.query(
            `INSERT INTO users (username, email, password, photo_url) VALUES ($1, $2, $3, $4)`,
            [username, email, password, photoUrl]
        );

        res.send(`<h2>Регистрация прошла успешно!</h2><p><a href="/">Назад</a></p>`);
    } catch (err) {
        console.error('Ошибка при регистрации:', err.message);
        res.status(500).send("Ошибка сервера при регистрации.");
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Сервер запущен на порту ${PORT}`);
});