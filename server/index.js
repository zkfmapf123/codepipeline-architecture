import express from 'express'

const PORT = process.env.PORT
const VER = process.env.VERSION

const app = express()

app.get("/", (req, res) => res.status(200).send("hello world"))
    .get("/health", (req, res) => res.status(200))
    .get("/name", (req, res) => res.status(200).send(`hello version:2`))
    .listen(PORT || 3000, () => {
        console.log(`localhost:${PORT} is connect`)
    })

process.on('SIGINT', () => {
    console.log('Shutting down gracefully...');
    process.exit(0);
});