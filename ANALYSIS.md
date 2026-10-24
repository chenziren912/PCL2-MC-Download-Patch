# PCL 2.99.0.0 下载入口分析

## 样本

- 来源：[官方 Release 2.99.0.0](https://github.com/Meloong-Git/PCL/releases/tag/2.99.0.0)。该 Release 没有二进制附件；样本取自同一标签下的 `最新正式版.zip`。
- [标签源码](https://github.com/Meloong-Git/PCL/tree/2.99.0.0)，提交 `6b9a50df911c9d68b69b24c979efba477fb14b67`。
- 程序集：`Plain Craft Launcher 2`，版本 `2.99.0.0`，AnyCPU、CIL、目标 `.NET Framework 4.8`。
- MVID：`926d447e-daff-4169-8c64-adc3d37d5f78`。
- 样本 SHA-256：`6B6E1260CB5A1D6A303855F1C60CAB3D0BC1AEBBA7E40A964180188B271E7386`。

## REA 静态分析

使用 REA `inspect_managed_artifact` 与 `inspect_managed_members` 直接解析样本 PE/CLI 元数据、字段引用和 CIL，不执行样本代码。

- 程序集证据 ID：`ev_0e8df4709f70fef27c1edac108aad975f612987efa8ff536a5622f126b549772`。
- 成员证据 ID：`ev_9e2f6e5c7822b06312ab8e40d841054aa790668aa53a3b73bdecc29bc90997a0`。
- 成员结果超出 MCP 传输大小限制，完整结果通过 `export_evidence_bundle` 导出后在本地筛选；此处只发布与补丁相关的结论。

官方 `Modules/ModSecret.vb` 中的 `RestrictMcDownload` 为值为 True 的编译期常量。`Pages/PageDownload/PageDownloadInstall.xaml.vb` 的 `LoaderInit` 因此创建“关闭下载”的 LoaderTask，而非使用 `DlClientListLoader`。部分其他入口的正常分支被编译器删除，修改常量元数据无法恢复它们。

## 修改

| 定位项 | 值 |
| --- | --- |
| 方法 | `PCL.PageDownloadInstall.LoaderInit` |
| MethodDef token | `0x06000513` |
| RVA | `0x0002DEB4` |
| 方法头文件偏移 | `0x0002C0B4`（180404） |
| 方法头长度 | 12 |
| IL 长度 | 94 |
| 原始 IL SHA-256 | `a8767f3aa819d847fbbdddb7058bbd669d15d1059b27084cc2c7c0dd4db3e22d` |
| 修改 IL 区间 | `[26, 74)` |
| 修改文件区间 | `[180442, 180490)` |
| 替换字段 | `PCL.ModDownload.DlClientListLoader`，token `0x0400040F` |

把该区间中创建禁用任务的 48 字节替换为 `ldsfld 0x0400040F`（5 字节），其余位置填充 `nop`（43 字节）。这样继续向原有 `PageLoaderInit` 调用传入正确的加载器；方法长度、后续地址、回调、程序集资源及其他方法均保持不变。区间内原有的两个跳转也一并被替换，不留下指向旧代码内部的跳转。

脚本先检查整个原始文件的 SHA-256，再检查目标字节。识别已打补丁的文件时，将候选区间复原后校验整个原始文件 SHA-256，避免只凭局部字节误认其他文件。写入前创建并校验完整备份，同卷临时文件通过原子替换提交。

## 实际观测与边界

补丁后的独立测试副本可以启动。操作「下载」后，日志显示原有 `DlClientList Main` 加载器运行，向 `https://launchermeta.mojang.com/mc/game/version_manifest.json` 请求数据，Mojang 和 Main 加载器均进入 `Finished` 状态。该证据确认入口及版本列表加载链恢复，不等同于已完成完整游戏安装或游戏启动。

不会触碰账号登录、正版验证、赞助校验、网络地址或 TLS 校验。整合包及修改页的其他限制未修改。
