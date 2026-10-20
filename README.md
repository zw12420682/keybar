# 苹果笔画键盘布局实验 · 0.1

目标设备：iPhone 14 / iOS 16.0.3 / Dopamine 隐根版。

## 当前进度

这是第一阶段的诊断源码，不是已经完成布局修改的插件。尚未编译、安装或进行真机测试，没有提供 deb。当前 Windows 环境没有检测到可用的 Theos、make、clang 或已配置的 WSL Linux 开发环境。

`layout.json` 已记录用户确认的布局：右侧第二行是 ABC，左下角是地球键，第三行是数字。候选栏继续由系统提供。

`Diagnostic.m` 只在苹果备忘录中尝试挂钩键盘布局工厂。它不会改变键盘，不读取输入框内容或候选词；它会导出工厂返回的静态布局树中的名称、键帽、按键编码与几何信息。它通过运行时检查方法是否存在及签名是否匹配，找不到就退出，不尝试猜测替代方法。

该工厂接口是参考现有开源键盘插件选择的探测入口，未确认 iOS 16.0.3 上是否存在。如果日志提示 factory unavailable，下一步应检查该系统的运行时接口，而不是继续安装布局修改版。

## 编译条件与命令

### GitHub Actions

解压源码包，把本目录里的内容上传到仓库根目录，包括 `.github/workflows/build.yml`。不要只上传 ZIP，也不要在仓库根目录再套一层 StrokeLayoutDiagnostic 文件夹。

提交后打开仓库 Actions，选择 Build RootHide diagnostic。也可点击 Run workflow 手动运行。成功后在该次运行的 Artifacts 下载 StrokeLayoutDiagnostic-roothide，解压取得 deb。

该流程使用 GitHub 的 macOS runner、Xcode 自带 iPhoneOS SDK 和 RootHide Theos；SDK 可以高于目标系统，部署目标仍为 iOS 16.0。当前尚未在 GitHub 实际运行，不能保证首次编译成功。如失败，请提供失败步骤的日志或 build-log 附件。流程只生成诊断插件，不会实现布局修改，也不会自动发布 Release。

Theos 跟随上游当前版本，构建日志会输出其提交号，以便排查版本差异。

需要配置好 RootHide 分支 Theos、iPhoneOS SDK、编译器、签名与打包工具的 macOS/Linux/手机开发环境。不要使用普通 rootless 包冒充隐根包。

```sh
cd StrokeLayoutDiagnostic
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

产物通常在 `packages/`。此命令尚未在本任务中执行成功；依赖或架构若不匹配，应以设备上的 RootHide 软件包配置和实际编译日志为准。

## 真机验证顺序

1. 编译成功后安装诊断 deb，彻底关闭并重新打开苹果备忘录。
2. 打开空白笔记，切到苹果笔画键盘，随后切换一次英文和符号页，以便采集系统的原生功能键结构。
3. 查看设备日志，搜索 `[StrokeLayoutDiagnostic]`。可通过 Mac 的控制台选择已连接 iPhone 查看日志；手机日志工具是否可用取决于本机配置。
4. 日志会报告 JSON 的完整路径与写入状态。JSON 在对应进程的临时目录 `StrokeLayoutDiagnostic` 下，可用手机文件管理工具导出。不要硬编码应用容器 UUID。
5. 保留 JSON 和相关诊断日志，供下一步映射笔画、删除、分词、ABC 和地球键。若完全没有日志，也需要核实注入过滤器、备忘录进程和工厂是否已加载。
6. 如需撤回，在包管理器卸载 Stroke Layout Diagnostic，重新打开备忘录即可。临时 JSON 可以手动删除。

首次最多捕获 24 个不同布局，每个布局最多 2000 个节点、深度 24、单文件不超过 2 MiB。重启备忘录后计数重置，旧文件不会自动删除。

## 下一阶段

根据真机报告识别键盘页与按键行为，深复制原生布局后同步修改显示和触摸几何，保留系统按键编码与候选词逻辑；完成横屏、深色模式和 ABC 返回路径验证，再扩大到其他应用。当前代码没有实现这些功能。

参考资料：

- RootHide 开发说明：https://github.com/roothide/Developer
- 键盘布局树入口参考：https://github.com/U-rTrDD-fyi/TopRow

本目录诊断源码为独立编写，没有复制上述项目的实现。
