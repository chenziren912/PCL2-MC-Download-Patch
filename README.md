# Plain Craft Launcher (PCL) 第三方 MC 下载补丁

针对 **官方 PCL 2.99.0.0 正式版**的独立第三方补丁。恢复 Minecraft 下载页使用原有版本列表加载器的行为。

PCL 作者为 **龙腾猫跃**，项目与作者及官方团队无隶属关系。[官方源码](https://github.com/Meloong-Git/PCL) · [作者赞助](https://meloong.com/afd/a/LTCat)。

## 一行运行

先关闭目标 PCL，在 Windows PowerShell 5.1 或 PowerShell 7 中运行：

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/chenziren912/PCL2-MC-Download-Patch/main/patch.ps1')))
```

出现 `PCL executable file path` 后输入 **exe 文件的完整路径**，例如：

```text
D:\Minecraft\Plain Craft Launcher 2.exe
```

路径包含中文、空格或外围引号均可。完成后重新打开启动器，进入「下载」。脚本要求目标文件所在目录可写；不需要 Python、.NET SDK 或重新编译启动器。

备份保存在原 exe 旁，名称为 `<原文件名>.pcl-download-patch.bak`。重复执行不会反复修改。脚本只接受下表中原始文件或本脚本生成的补丁文件，其他版本、其他构建和自行修改的文件均会拒绝处理。

## 检查与恢复

仅检查兼容性（同样会提示输入路径）：

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/chenziren912/PCL2-MC-Download-Patch/main/patch.ps1'))) -Check
```

从已校验的旁置备份恢复：

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/chenziren912/PCL2-MC-Download-Patch/main/patch.ps1'))) -Restore
```

也可以先下载并阅读 `patch.ps1`，然后在本地运行 `& .\patch.ps1 -Path 'D:\Minecraft\Plain Craft Launcher 2.exe'`。

## 支持范围

| 项目 | 值 |
| --- | --- |
| 官方版本 | 2.99.0.0 正式版 |
| exe 长度 | 5,980,160 字节 |
| 原始 SHA-256 | `6B6E1260CB5A1D6A303855F1C60CAB3D0BC1AEBBA7E40A964180188B271E7386` |
| 补丁后 SHA-256 | `BA7585206D97D63AD6F48CDF5FE3F79757B405990D85D1009E1EE19EDF4272A9` |

只恢复 Minecraft 下载页的版本列表加载入口。整合包安装入口和已有实例的修改页限制不在本补丁范围内；不会解除账号、正版验证或赞助功能限制。更新启动器后需要重新检查兼容性。

## 分析与验证

[分析记录](ANALYSIS.md)包含 REA 证据标识、官方源码位置和修改范围。

已验证补丁应用、重复执行、恢复原始 SHA-256、中文与空格路径，以及补丁后启动器调用 Mojang 版本列表并完成 `DlClientList Main` 加载。完整游戏安装和进入游戏尚未验证。

本地集成测试：

```powershell
& .\tests\Test-Patch.ps1 -FixturePath 'D:\Minecraft\未修改的 PCL.exe'
```

本仓库不分发 PCL 本体或 Minecraft 文件。自编脚本与说明采用 [MIT 许可](LICENSE)，PCL 本体及上游内容适用其[原许可及使用指南](UPSTREAM-LICENCE.txt)。
