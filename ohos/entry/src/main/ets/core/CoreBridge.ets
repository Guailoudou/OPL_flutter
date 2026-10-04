import { fileIo, fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { systemShare } from '@kit.ShareKit';
import { bundleManager } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import { MethodCall, MethodResult } from '@ohos/flutter_ohos';
import { CoreService } from '../service/CoreService';

const DOMAIN = 0x0;
const TAG = 'OPL-Core';

/** The VPN extension owns the Go runtime and TUN workers, independently of Flutter. */
export class CoreBridge {
  readonly service: CoreService;
  private context: common.UIAbilityContext;
  private uiContext?: UIContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.service = new CoreService(context);
  }

  initializePictureInPicture(uiContext: UIContext): void {
    this.uiContext = uiContext;
    this.service.initializePictureInPicture(uiContext).catch((error: Object): void => {
      hilog.warn(DOMAIN, TAG, 'PiP initialization unavailable: %{public}s', JSON.stringify(error));
    });
  }

  handle(call: MethodCall, result: MethodResult): void {
    this.invoke(call, result).catch((error: Object): void => {
      hilog.error(DOMAIN, TAG, 'Core bridge request failed: %{public}s', JSON.stringify(error));
      result.error('OHOS_CORE_ERROR', String(error), null);
    });
  }

  private async invoke(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'getApplicationDocumentsDirectory':
        result.success(this.context.filesDir);
        break;
      case 'getTemporaryDirectory':
        result.success(this.context.cacheDir);
        break;
      case 'openExternalLink':
        const url = String(call.argument('url') ?? '');
        if (!/^https?:\/\//.test(url)) {
          result.success(false);
          break;
        }
        await this.context.startAbility({ action: 'ohos.want.action.viewData',
          entities: ['entity.system.browsable'], uri: url });
        result.success(true);
        break;
      case 'getAppVersion':
        const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
        result.success(info.versionName);
        break;
      case 'getCoreStatus':
        result.success(JSON.stringify(this.service.readStatus()));
        break;
      case 'shareFile':
        await this.shareFile(call, result);
        break;
      case 'startCore':
        const token = String(call.argument('token') ?? '');
        if (!/^[0-9]+$/.test(token) || token === '0') {
          result.error('INVALID_TOKEN', 'A valid unsigned token is required', null);
          break;
        }
        await this.service.start(token, Number(call.argument('shareBandwidth') ?? 10),
          Number(call.argument('logLevel') ?? 1));
        result.success(true);
        break;
      case 'startVpn':
        // CoreService.start already performs the reference core/TUN handshake.
        result.success(true);
        break;
      case 'stopCore':
        await this.service.stop();
        result.success(true);
        break;
      case 'getKeepAliveOptions':
        result.success(JSON.stringify({
          continuousTask: this.service.isBackgroundKeepAliveEnabled(),
          pictureInPicture: this.service.isPictureInPictureEnabled()
        }));
        break;
      case 'setBackgroundKeepAlive':
        result.success(await this.service.setBackgroundKeepAliveEnabled(call.argument('enabled') === true));
        break;
      case 'setPictureInPicture':
        if (this.uiContext === undefined) {
          result.success(false);
        } else {
          result.success(await this.service.setPictureInPictureEnabled(call.argument('enabled') === true, this.uiContext));
        }
        break;
      default:
        result.notImplemented();
    }
  }

  private async shareFile(call: MethodCall, result: MethodResult): Promise<void> {
    const path = String(call.argument('path') ?? '');
    try {
      if (path.length === 0 || !fileIo.accessSync(path)) {
        result.success(false);
        return;
      }
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.ZIP_ARCHIVE,
        uri: fileUri.getUriFromPath(path),
        title: 'OPL logs',
        description: 'OPL application logs'
      });
      const controller = new systemShare.ShareController(shareData);
      await controller.show(this.context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
      result.success(true);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'OHOS file share failed: %{public}s', JSON.stringify(error));
      result.success(false);
    }
  }

}
