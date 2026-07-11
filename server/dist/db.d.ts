export declare class JsonDB<T> {
    private filePath;
    constructor(filename: string);
    private ensureFile;
    read(): T;
    write(data: T): void;
}
//# sourceMappingURL=db.d.ts.map