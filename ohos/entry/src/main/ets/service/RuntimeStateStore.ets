import common from '@ohos.app.ability.common';
import { fileIo } from '@kit.CoreFileKit';

const STATE_FILE = 'opl_runtime_state.json';

export enum AppColorMode {
  SYSTEM = 'system',
  DARK = 'dark',
  LIGHT = 'light'
}

interface RuntimeState {
  desiredRunning: boolean;
  shareBandwidth?: number;
  logLevel?: number;
  backgroundKeepAliveEnabled?: boolean;
  simulatedLocationEnabled?: boolean;
  pictureInPictureEnabled?: boolean;
  themeColor?: string;
  colorMode?: AppColorMode;
}

export class RuntimeStateStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  isDesiredRunning(): boolean {
    return this.readState().desiredRunning === true;
  }

  getShareBandwidth(): number { return this.readState().shareBandwidth ?? 10; }
  getLogLevel(): number { return this.readState().logLevel ?? 1; }
  setLaunchOptions(shareBandwidth: number, logLevel: number): void {
    const state = this.readState();
    state.shareBandwidth = shareBandwidth;
    state.logLevel = logLevel;
    this.writeState(state);
  }

  isBackgroundKeepAliveEnabled(): boolean {
    return this.readState().backgroundKeepAliveEnabled !== false;
  }

  isSimulatedLocationEnabled(): boolean {
    return this.readState().simulatedLocationEnabled === true;
  }

  isPictureInPictureEnabled(): boolean {
    return this.readState().pictureInPictureEnabled === true;
  }

  getThemeColor(): string {
    return this.readState().themeColor ?? '#0A59F7';
  }

  getColorMode(): AppColorMode {
    return this.readState().colorMode ?? AppColorMode.SYSTEM;
  }

  setDesiredRunning(desiredRunning: boolean): void {
    const state = this.readState();
    state.desiredRunning = desiredRunning;
    this.writeState(state);
  }

  setBackgroundKeepAliveEnabled(enabled: boolean): void {
    const state = this.readState();
    state.backgroundKeepAliveEnabled = enabled;
    this.writeState(state);
  }

  setSimulatedLocationEnabled(enabled: boolean): void {
    const state = this.readState();
    state.simulatedLocationEnabled = enabled;
    this.writeState(state);
  }

  setPictureInPictureEnabled(enabled: boolean): void {
    const state = this.readState();
    state.pictureInPictureEnabled = enabled;
    this.writeState(state);
  }

  setThemeColor(color: string): void {
    const state = this.readState();
    state.themeColor = color;
    this.writeState(state);
  }

  setColorMode(colorMode: AppColorMode): void {
    const state = this.readState();
    state.colorMode = colorMode;
    this.writeState(state);
  }

  private readState(): RuntimeState {
    try {
      const path = `${this.context.filesDir}/${STATE_FILE}`;
      if (!fileIo.accessSync(path)) {
        return this.defaultState();
      }
      const state = JSON.parse(fileIo.readTextSync(path)) as RuntimeState;
      return {
        desiredRunning: state.desiredRunning === true,
        shareBandwidth: state.shareBandwidth,
        logLevel: state.logLevel,
        backgroundKeepAliveEnabled: state.backgroundKeepAliveEnabled !== false,
        simulatedLocationEnabled: state.simulatedLocationEnabled === true,
        pictureInPictureEnabled: state.pictureInPictureEnabled === true,
        themeColor: state.themeColor ?? '#0A59F7',
        colorMode: state.colorMode === AppColorMode.DARK || state.colorMode === AppColorMode.LIGHT ?
          state.colorMode : AppColorMode.SYSTEM
      };
    } catch (_) {
      return this.defaultState();
    }
  }

  private defaultState(): RuntimeState {
    return {
      desiredRunning: false,
      backgroundKeepAliveEnabled: true,
      simulatedLocationEnabled: false,
      pictureInPictureEnabled: false,
      themeColor: '#0A59F7',
      colorMode: AppColorMode.SYSTEM
    };
  }

  private writeState(state: RuntimeState): void {
    const path = `${this.context.filesDir}/${STATE_FILE}`;
    const temporary = `${path}.tmp`;
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(temporary,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, JSON.stringify(state));
      fileIo.fsyncSync(file.fd);
    } catch (error) {
      throw new Error(`Unable to persist runtime state: ${String(error)}`);
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file.fd);
        } catch (_) {
        }
      }
    }
    fileIo.renameSync(temporary, path);
  }
}
