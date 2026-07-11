import fs from 'fs';
import path from 'path';
import { config } from './config';

export class JsonDB<T> {
  private filePath: string;

  constructor(filename: string) {
    this.filePath = path.join(config.dataDir, filename);
    this.ensureFile();
  }

  private ensureFile(): void {
    if (!fs.existsSync(config.dataDir)) {
      fs.mkdirSync(config.dataDir, { recursive: true });
    }
    if (!fs.existsSync(this.filePath)) {
      fs.writeFileSync(this.filePath, '{}', 'utf-8');
    }
  }

  read(): T {
    const content = fs.readFileSync(this.filePath, 'utf-8');
    return JSON.parse(content) as T;
  }

  write(data: T): void {
    fs.writeFileSync(this.filePath, JSON.stringify(data, null, 2), 'utf-8');
  }
}
