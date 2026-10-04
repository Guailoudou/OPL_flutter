import { FlutterAbility, FlutterEngine, MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CoreBridge } from '../core/CoreBridge';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

const CORE_CHANNEL = 'com.example.opl_config_manager/core';

export default class EntryAbility extends FlutterAbility {
  private bridge?: CoreBridge;
  private recoveryTimer: number = 0;
  private recovering: boolean = false;

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    const bridge = this.bridge ?? new CoreBridge(this.context);
    this.bridge = bridge;
    const channel = new MethodChannel(flutterEngine.getDartExecutor(), CORE_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        bridge.handle(call, result);
      }
    });
  }

  onWindowStageCreate(stage: window.WindowStage): void {
    super.onWindowStageCreate(stage);
    this.bridge?.initializePictureInPicture(stage.getMainWindowSync().getUIContext());
  }

  onForeground(): void {
    super.onForeground();
    this.stopRecoveryTimer();
    this.bridge?.service.onAppForeground().catch((error: Object): void => {
      hilog.warn(0, 'OPL-Core', 'Foreground recovery failed: %{public}s', JSON.stringify(error));
    });
  }

  onBackground(): void {
    super.onBackground();
    this.bridge?.service.onAppBackground().catch((error: Object): void => {
      hilog.warn(0, 'OPL-Core', 'Background strategies unavailable: %{public}s', JSON.stringify(error));
    });
    if (this.recoveryTimer === 0) {
      this.recoveryTimer = setInterval((): void => {
        if (this.recovering || this.bridge === undefined) return;
        this.recovering = true;
        this.bridge.service.recoverIfNeeded().catch((error: Object): void => {
          hilog.warn(0, 'OPL-Core', 'Background recovery failed: %{public}s', JSON.stringify(error));
        }).finally((): void => { this.recovering = false; });
      }, 10 * 1000);
    }
  }

  onDestroy(): void {
    this.stopRecoveryTimer();
    // Do not stop the VPN-owned runtime when Flutter's UI is destroyed.
    super.onDestroy();
  }

  private stopRecoveryTimer(): void {
    if (this.recoveryTimer !== 0) {
      clearInterval(this.recoveryTimer);
      this.recoveryTimer = 0;
    }
  }
}
