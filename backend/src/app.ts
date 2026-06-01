import express from 'express';
import path from 'path';
import cors from 'cors';
import morgan from 'morgan';
import { router } from './routes/index';

const app = express();

app.use(cors());
app.use(morgan('[:date[iso]] :method :url :status :response-time ms'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (_req, res) => {
  res.sendFile(path.join(process.cwd(), 'public', 'index.html'));
});

app.use(express.static(path.join(process.cwd(), 'public')));
app.use('/static', express.static('E:\\comic'));
app.use('/api', router);

export default app;
