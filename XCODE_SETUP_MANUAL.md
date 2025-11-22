# Liuli-Server Xcode 手动配置操作手册

**目标用户**: 开发者
**预计时间**: 30-45 分钟
**前提条件**:
- Xcode 15.0+ 已安装
- macOS 14.0+ 开发环境
- 已安装 Git

---

## 📋 目录

1. [Xcode 项目配置](#1-xcode-项目配置)
2. [添加 SwiftNIO 依赖](#2-添加-swiftnio-依赖)
3. [添加源文件到项目](#3-添加源文件到项目)
4. [配置 Build Settings](#4-配置-build-settings)
5. [配置 Info.plist 和 Entitlements](#5-配置-infoplist-和-entitlements)
6. [SwiftNIO SOCKS5 服务器实现](#6-swiftnio-socks5-服务器实现)
7. [添加应用图标](#7-添加应用图标)
8. [构建和运行](#8-构建和运行)
9. [常见问题排查](#9-常见问题排查)

---

## 1. Xcode 项目配置

### 1.1 打开项目

```bash
cd /Users/fanyuandong/Developer/GitHub/Liuli-Server
open Liuli-Server.xcodeproj
```

### 1.2 配置 Swift 版本和并发模式

1. 选择项目根节点 `Liuli-Server`
2. 选择 Target `Liuli-Server`
3. 进入 **Build Settings** 标签页
4. 搜索 `Swift Language Version`
   - 设置为 **Swift 6**
5. 搜索 `Swift Compiler - Custom Flags`
   - 在 `Other Swift Flags` 中添加: `-strict-concurrency=complete`

**验证配置**:
```
Swift Language Version: Swift 6
Other Swift Flags: -strict-concurrency=complete
```

---

## 2. 添加 SwiftNIO 依赖

### 2.1 添加 Swift Package Dependencies

1. 在 Xcode 中，选择菜单 **File → Add Package Dependencies...**
2. 在搜索栏输入: `https://github.com/apple/swift-nio.git`
3. 选择 **Dependency Rule**: `Up to Next Major Version` → `2.0.0`
4. 点击 **Add Package**
5. 在弹出的产品选择窗口中，勾选以下产品:
   - ✅ **NIO**
   - ✅ **NIOCore**
   - ✅ **NIOPosix**
   - ✅ **NIOHTTP1** (用于 HTTP 转发)
6. Target 选择 `Liuli-Server`
7. 点击 **Add Package**

### 2.2 验证依赖添加成功

1. 在项目导航器中，展开 `Package Dependencies` 节点
2. 应该能看到 `swift-nio` 包及其子模块
3. 如果没有看到，尝试 **File → Packages → Resolve Package Versions**

---

## 3. 添加源文件到项目

### 3.1 删除默认文件 (可选)

以下文件是 Xcode 模板生成的，可以删除:
- `ContentView.swift`
- `Item.swift`
- 旧的 `Liuli_ServerApp.swift` (如果与新文件冲突)

**删除步骤**:
1. 在项目导航器中选择文件
2. 右键 → **Delete**
3. 选择 **Move to Trash**

### 3.2 添加新创建的源文件

**自动添加方法** (推荐):

1. 在项目导航器中，右键点击 `Liuli-Server` 文件夹
2. 选择 **Add Files to "Liuli-Server"...**
3. 导航到 `/Users/fanyuandong/Developer/GitHub/Liuli-Server/Liuli-Server`
4. 选中以下文件夹:
   - `App/`
   - `Domain/`
   - `Data/`
   - `Presentation/`
   - `Shared/`
   - `Resources/`
5. 确保勾选:
   - ✅ **Copy items if needed** (不要勾选，因为文件已在项目目录中)
   - ✅ **Create groups** (创建文件夹结构)
   - ✅ **Add to targets: Liuli-Server**
6. 点击 **Add**

**验证文件结构**:

项目导航器应该显示以下结构:

```
Liuli-Server/
├── App/
│   ├── Liuli_ServerApp.swift
│   ├── AppDependencyContainer.swift
│   ├── MenuBarCoordinator.swift
│   ├── StatisticsWindowCoordinator.swift
│   └── PreferencesWindowCoordinator.swift
├── Domain/
│   ├── Entities/
│   │   ├── BridgeService.swift
│   │   ├── SOCKS5Connection.swift
│   │   ├── ConnectedDevice.swift
│   │   ├── ProxyConfiguration.swift
│   │   └── ConnectionStatistics.swift
│   ├── ValueObjects/
│   │   ├── ServiceState.swift
│   │   ├── ConnectionState.swift
│   │   ├── SOCKS5Error.swift
│   │   ├── CharlesProxyStatus.swift
│   │   └── BridgeServiceError.swift
│   ├── Protocols/
│   │   ├── SOCKS5ServerRepository.swift
│   │   ├── BonjourServiceRepository.swift
│   │   ├── CharlesProxyRepository.swift
│   │   ├── ConnectionRepository.swift
│   │   └── ConfigurationRepository.swift
│   └── UseCases/
│       ├── StartServiceUseCase.swift
│       ├── StopServiceUseCase.swift
│       ├── DetectCharlesUseCase.swift
│       ├── TrackStatisticsUseCase.swift
│       ├── ManageConfigurationUseCase.swift
│       └── ForwardConnectionUseCase.swift
├── Data/
│   └── Repositories/
│       ├── NIOSwiftSOCKS5ServerRepository.swift
│       ├── NetServiceBonjourRepository.swift
│       ├── ProcessCharlesRepository.swift
│       ├── InMemoryConnectionRepository.swift
│       └── UserDefaultsConfigRepository.swift
├── Presentation/
│   ├── State/
│   │   ├── MenuBarViewState.swift
│   │   ├── MenuBarViewAction.swift
│   │   ├── StatisticsViewState.swift
│   │   └── PreferencesViewState.swift
│   ├── ViewModels/
│   │   ├── MenuBarViewModel.swift
│   │   ├── StatisticsViewModel.swift
│   │   └── PreferencesViewModel.swift
│   └── Views/
│       ├── MenuBarView.swift
│       ├── StatisticsView.swift
│       ├── PreferencesView.swift
│       └── ErrorAlertView.swift
├── Shared/
│   ├── Extensions/
│   │   ├── IPAddress+Validation.swift
│   │   ├── Data+HexString.swift
│   │   └── String+Localized.swift
│   ├── Utilities/
│   │   ├── Logger.swift
│   │   └── ExponentialBackoff.swift
│   ├── Services/
│   │   └── NotificationService.swift
│   └── Views/
│       └── ViewExtensions.swift
└── Resources/
    ├── Info.plist
    ├── Liuli-Server.entitlements
    ├── Assets.xcassets/
    └── Localizations/
        ├── en.lproj/
        │   └── Localizable.strings
        └── zh-Hans.lproj/
            └── Localizable.strings
```

---

## 4. 配置 Build Settings

### 4.1 配置 Product Bundle Identifier

1. 选择 Target `Liuli-Server`
2. 进入 **Signing & Capabilities** 标签页
3. 设置 **Bundle Identifier**: `com.liuli.server` (或你的团队标识符)
4. 选择 **Team**: 你的 Apple Developer Team

### 4.2 配置 Minimum Deployment Target

1. 在 **General** 标签页
2. 设置 **Minimum Deployments**: **macOS 14.0**

### 4.3 配置 Build Settings

在 **Build Settings** 中验证以下配置:

| Setting | Value |
|---------|-------|
| Swift Language Version | Swift 6 |
| Other Swift Flags | `-strict-concurrency=complete` |
| Enable Testability (Debug) | Yes |
| Optimization Level (Debug) | `-Onone` |
| Optimization Level (Release) | `-O` |

---

## 5. 配置 Info.plist 和 Entitlements

### 5.1 配置 Info.plist

文件已创建在 `Liuli-Server/Resources/Info.plist`。

**验证以下关键配置**:

1. 在项目导航器中打开 `Resources/Info.plist`
2. 确认包含以下键值:

```xml
<key>LSUIElement</key>
<true/>
<key>NSUserNotificationsUsageDescription</key>
<string>Liuli-Server needs to send notifications about service status and device connections.</string>
```

3. 在 Target 设置中，进入 **Build Settings**
4. 搜索 `Info.plist File`
5. 设置路径为: `Liuli-Server/Resources/Info.plist`

### 5.2 配置 Entitlements

文件已创建在 `Liuli-Server.entitlements`。

**添加到项目**:

1. 在 **Signing & Capabilities** 标签页
2. 点击 **+ Capability**
3. 添加以下 Capabilities:
   - ✅ **App Sandbox**
   - ✅ **Network** → **Incoming Connections (Server)** 和 **Outgoing Connections (Client)**
   - ✅ **Service Management**

**验证 Entitlements 文件**:

打开 `Liuli-Server.entitlements`，确认包含:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.application-groups</key>
<array>
    <string>group.com.liuli.server</string>
</array>
<key>com.apple.developer.system-extension.install</key>
<true/>
```

---

## 6. SwiftNIO SOCKS5 服务器实现

### 6.1 当前状态

文件 `Data/Repositories/NIOSwiftSOCKS5ServerRepository.swift` 包含占位符实现。

### 6.2 完整实现指南

**需要实现的核心组件**:

1. **SOCKS5Handler**: 处理 SOCKS5 协议握手和命令
2. **CharlesForwardingHandler**: 转发流量到 Charles Proxy
3. **ConnectionTracker**: 跟踪活动连接

**实现步骤**:

#### 6.2.1 创建 SOCKS5Handler

在 `Data/Repositories/` 目录创建新文件 `SOCKS5Handler.swift`:

```swift
import Foundation
import NIO
import NIOCore

/// SOCKS5 protocol handler (RFC 1928)
final class SOCKS5Handler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    enum State {
        case waitingForGreeting
        case waitingForRequest
        case forwarding
        case closed
    }

    private var state: State = .waitingForGreeting
    private let charlesHost: String
    private let charlesPort: Int
    private let onConnection: (SOCKS5Connection) -> Void

    init(
        charlesHost: String,
        charlesPort: Int,
        onConnection: @escaping (SOCKS5Connection) -> Void
    ) {
        self.charlesHost = charlesHost
        self.charlesPort = charlesPort
        self.onConnection = onConnection
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)

        switch state {
        case .waitingForGreeting:
            handleGreeting(context: context, buffer: &buffer)
        case .waitingForRequest:
            handleRequest(context: context, buffer: &buffer)
        case .forwarding:
            // 转发到 Charles
            forwardToCharles(context: context, buffer: buffer)
        case .closed:
            break
        }
    }

    private func handleGreeting(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        // SOCKS5 Greeting: [VER, NMETHODS, METHODS...]
        guard let version = buffer.readInteger(as: UInt8.self), version == 0x05 else {
            context.close(promise: nil)
            return
        }

        guard let nmethods = buffer.readInteger(as: UInt8.self) else {
            context.close(promise: nil)
            return
        }

        // Skip methods (we only support NO AUTH: 0x00)
        buffer.moveReaderIndex(forwardBy: Int(nmethods))

        // Send greeting response: [VER, METHOD]
        var response = context.channel.allocator.buffer(capacity: 2)
        response.writeInteger(UInt8(0x05)) // SOCKS version 5
        response.writeInteger(UInt8(0x00)) // NO AUTHENTICATION REQUIRED

        context.writeAndFlush(wrapOutboundOut(response), promise: nil)

        state = .waitingForRequest
    }

    private func handleRequest(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        // SOCKS5 Request: [VER, CMD, RSV, ATYP, DST.ADDR, DST.PORT]
        guard let version = buffer.readInteger(as: UInt8.self), version == 0x05 else {
            sendError(context: context, error: 0x01) // General failure
            return
        }

        guard let command = buffer.readInteger(as: UInt8.self) else {
            sendError(context: context, error: 0x01)
            return
        }

        // Only support CONNECT (0x01)
        guard command == 0x01 else {
            sendError(context: context, error: 0x07) // Command not supported
            return
        }

        buffer.moveReaderIndex(forwardBy: 1) // Skip RSV

        guard let addressType = buffer.readInteger(as: UInt8.self) else {
            sendError(context: context, error: 0x01)
            return
        }

        let destinationAddress: String
        switch addressType {
        case 0x01: // IPv4
            guard let ipv4Bytes = buffer.readBytes(length: 4) else {
                sendError(context: context, error: 0x01)
                return
            }
            destinationAddress = ipv4Bytes.map { String($0) }.joined(separator: ".")

        case 0x03: // Domain name
            guard let length = buffer.readInteger(as: UInt8.self),
                  let domainBytes = buffer.readBytes(length: Int(length)),
                  let domain = String(bytes: domainBytes, encoding: .utf8) else {
                sendError(context: context, error: 0x01)
                return
            }
            destinationAddress = domain

        case 0x04: // IPv6
            guard let ipv6Bytes = buffer.readBytes(length: 16) else {
                sendError(context: context, error: 0x01)
                return
            }
            // Format IPv6
            destinationAddress = formatIPv6(ipv6Bytes)

        default:
            sendError(context: context, error: 0x08) // Address type not supported
            return
        }

        guard let port = buffer.readInteger(as: UInt16.self) else {
            sendError(context: context, error: 0x01)
            return
        }

        // Track connection
        let connection = SOCKS5Connection(
            id: UUID(),
            sourceAddress: context.remoteAddress?.description ?? "unknown",
            destinationAddress: "\\(destinationAddress):\\(port)",
            state: .connected,
            connectedAt: Date(),
            bytesSent: 0,
            bytesReceived: 0
        )
        onConnection(connection)

        // Send success response
        sendSuccessResponse(context: context)

        // Transition to forwarding state
        state = .forwarding

        // TODO: Connect to Charles and setup bidirectional forwarding
        setupCharlesConnection(context: context, destination: destinationAddress, port: Int(port))
    }

    private func sendSuccessResponse(context: ChannelHandlerContext) {
        var response = context.channel.allocator.buffer(capacity: 10)
        response.writeInteger(UInt8(0x05)) // VER
        response.writeInteger(UInt8(0x00)) // SUCCESS
        response.writeInteger(UInt8(0x00)) // RSV
        response.writeInteger(UInt8(0x01)) // ATYP: IPv4
        response.writeInteger(UInt32(0))   // BND.ADDR: 0.0.0.0
        response.writeInteger(UInt16(0))   // BND.PORT: 0

        context.writeAndFlush(wrapOutboundOut(response), promise: nil)
    }

    private func sendError(context: ChannelHandlerContext, error: UInt8) {
        var response = context.channel.allocator.buffer(capacity: 10)
        response.writeInteger(UInt8(0x05)) // VER
        response.writeInteger(error)        // REP
        response.writeInteger(UInt8(0x00)) // RSV
        response.writeInteger(UInt8(0x01)) // ATYP
        response.writeInteger(UInt32(0))   // BND.ADDR
        response.writeInteger(UInt16(0))   // BND.PORT

        context.writeAndFlush(wrapOutboundOut(response)).whenComplete { _ in
            context.close(promise: nil)
        }
    }

    private func setupCharlesConnection(
        context: ChannelHandlerContext,
        destination: String,
        port: Int
    ) {
        // TODO: Implement connection to Charles proxy
        // Use HTTP CONNECT tunnel for HTTPS traffic
        // Direct proxy for HTTP traffic
        Logger.socks5.info("Setting up Charles connection to \\(destination):\\(port)")
    }

    private func forwardToCharles(context: ChannelHandlerContext, buffer: ByteBuffer) {
        // TODO: Forward data to Charles
        Logger.socks5.debug("Forwarding \\(buffer.readableBytes) bytes to Charles")
    }

    private func formatIPv6(_ bytes: [UInt8]) -> String {
        var components: [String] = []
        for i in stride(from: 0, to: 16, by: 2) {
            let value = (UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1])
            components.append(String(format: "%x", value))
        }
        return components.joined(separator: ":")
    }
}
```

#### 6.2.2 更新 NIOSwiftSOCKS5ServerRepository.swift

替换占位符实现:

```swift
import Foundation
import NIO
import NIOCore
import NIOPosix

actor NIOSwiftSOCKS5ServerRepository: SOCKS5ServerRepository {
    private var serverChannel: Channel?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private let charlesHost: String
    private let charlesPort: Int
    private var connectionHandler: ((SOCKS5Connection) -> Void)?

    init(
        charlesHost: String = "127.0.0.1",
        charlesPort: Int = 8888
    ) {
        self.charlesHost = charlesHost
        self.charlesPort = charlesPort
    }

    func start(port: Int) async throws {
        guard serverChannel == nil else {
            throw SOCKS5Error.alreadyRunning
        }

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.eventLoopGroup = group

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(
                    SOCKS5Handler(
                        charlesHost: self.charlesHost,
                        charlesPort: self.charlesPort,
                        onConnection: { [weak self] connection in
                            Task {
                                await self?.connectionHandler?(connection)
                            }
                        }
                    )
                )
            }

        do {
            let channel = try await bootstrap.bind(host: "0.0.0.0", port: port).get()
            self.serverChannel = channel

            Logger.socks5.info("SOCKS5 server started on port \\(port)")
        } catch {
            try? await group.shutdownGracefully()
            self.eventLoopGroup = nil
            throw SOCKS5Error.bindFailed(port: port)
        }
    }

    func stop() async throws {
        guard let channel = serverChannel else {
            throw SOCKS5Error.notRunning
        }

        try await channel.close()
        try await eventLoopGroup?.shutdownGracefully()

        serverChannel = nil
        eventLoopGroup = nil

        Logger.socks5.info("SOCKS5 server stopped")
    }

    func setConnectionHandler(_ handler: @escaping @Sendable (SOCKS5Connection) -> Void) {
        self.connectionHandler = handler
    }
}
```

#### 6.2.3 验证实现

完成实现后:

1. 编译项目: `⌘ + B`
2. 解决所有编译错误
3. 确保 Swift 6 strict concurrency 检查通过

**注意**: 完整的 SwiftNIO 实现需要深入理解以下概念:
- NIO Channel Pipeline
- HTTP CONNECT tunneling (用于 HTTPS)
- 双向数据转发
- 背压管理 (backpressure)

推荐资源:
- [SwiftNIO Documentation](https://apple.github.io/swift-nio/docs/current/NIO/index.html)
- [RFC 1928 - SOCKS Protocol Version 5](https://www.rfc-editor.org/rfc/rfc1928)

---

## 7. 添加应用图标

### 7.1 准备图标资源

应用图标已放置在 `Liuli-Server/Assets.xcassets/AppIcon.appiconset/` 中。

**验证图标**:

1. 在项目导航器中打开 `Assets.xcassets`
2. 选择 `AppIcon`
3. 确认所有尺寸的图标都已正确放置:
   - 16x16
   - 32x32
   - 64x64
   - 128x128
   - 256x256
   - 512x512
   - 1024x1024

### 7.2 配置应用图标

1. 选择 Target `Liuli-Server`
2. 进入 **General** 标签页
3. 在 **App Icons and Launch Screen** 部分
4. 选择 **App Icon**: `AppIcon`

---

## 8. 构建和运行

### 8.1 首次构建

1. 选择 Scheme: `Liuli-Server`
2. 选择目标设备: **My Mac**
3. 点击 **Product → Build** (⌘ + B)

**预期结果**:
- ✅ 零编译错误
- ✅ 零警告 (目标)
- ✅ Swift 6 strict concurrency 检查通过

### 8.2 运行应用

1. 点击 **Product → Run** (⌘ + R)
2. 应用应该会:
   - 在菜单栏显示图标 (⚪️ 或你的自定义图标)
   - 不在 Dock 中显示图标 (因为 `LSUIElement=YES`)
3. 点击菜单栏图标，应该显示下拉菜单

### 8.3 测试功能

**基础功能测试**:

1. 点击 **启动服务**
   - 应该看到通知: "服务运行中"
   - 菜单栏图标变为 🟢 (或绿色图标)
2. 点击 **查看统计**
   - 应该打开统计窗口
3. 点击 **偏好设置**
   - 应该打开偏好设置窗口
4. 点击 **停止服务**
   - 应该看到通知: "服务已停止"

**Charles 集成测试** (需要 Charles 已安装):

1. 启动 Charles Proxy
2. 在 Liuli-Server 中点击 **启动服务**
3. 如果 Charles 运行正常，不应该看到警告通知

---

## 9. 常见问题排查

### 9.1 编译错误

#### 错误: "Module 'NIO' not found"

**原因**: SwiftNIO 依赖未正确添加

**解决方案**:
1. 选择菜单 **File → Packages → Resolve Package Versions**
2. 如果仍然失败，删除派生数据:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Liuli-Server-*
   ```
3. 重新打开项目并构建

#### 错误: "Data race detected"

**原因**: Swift 6 strict concurrency 检查发现数据竞争

**解决方案**:
1. 检查错误消息中的文件和行号
2. 确保:
   - ViewModels 标记为 `@MainActor`
   - Repositories 实现为 `actor`
   - 所有跨 actor 传递的类型遵循 `Sendable`

#### 错误: "Cannot find 'Logger' in scope"

**原因**: Logger 工具类未正确导入

**解决方案**:
1. 确认 `Shared/Utilities/Logger.swift` 已添加到项目
2. 确认文件的 **Target Membership** 包含 `Liuli-Server`

### 9.2 运行时错误

#### 应用启动后闪退

**原因**: Info.plist 配置错误

**解决方案**:
1. 检查 `Info.plist` 路径配置
2. 验证 `LSUIElement` 键存在且为 `true`
3. 检查 Console.app 中的崩溃日志

#### 菜单栏不显示图标

**原因**: `LSUIElement` 配置或 MenuBarCoordinator 初始化问题

**解决方案**:
1. 确认 `Info.plist` 中 `LSUIElement` 为 `true`
2. 在 `AppDelegate.applicationDidFinishLaunching` 中设置断点
3. 验证 `MenuBarCoordinator.setup()` 被调用

#### 通知不显示

**原因**: 通知权限未授权

**解决方案**:
1. 打开 **系统设置 → 通知**
2. 找到 `Liuli-Server`
3. 启用通知
4. 或在应用中重新请求权限

### 9.3 Charles 连接问题

#### 警告: "未检测到 Charles"

**解决方案**:
1. 确认 Charles 正在运行
2. 检查 Charles 监听端口: **Proxy → Proxy Settings**
3. 默认应该是 `8888` (HTTP) 和 `8889` (HTTPS)
4. 在 Liuli-Server 偏好设置中确认端口配置

#### 流量未转发到 Charles

**可能原因**:
- SwiftNIO SOCKS5Handler 未完全实现
- Charles 未配置为接受外部代理请求

**解决方案**:
1. 在 Charles 中启用: **Proxy → External Proxy Settings**
2. 添加 SOCKS5 代理白名单
3. 检查 Console.app 日志输出

---

## 10. 下一步

完成配置后:

1. **实现完整的 SwiftNIO SOCKS5Handler** (参考第 6 节)
2. **编写单元测试** (Phase 10 tasks)
3. **优化图标资源** (替换 emoji 占位符)
4. **配置 CI/CD** (可选)

---

## 📞 支持

如遇到问题:

1. 查看 Console.app 日志 (过滤 `subsystem:com.liuli.server`)
2. 检查 Xcode 构建日志
3. 参考 `CLAUDE.md` 中的架构指南
4. 查看 `specs/001-ios-vpn-bridge/` 中的规格说明

---

**文档版本**: v1.0
**最后更新**: 2025-11-22
**适用于**: Xcode 15.0+, macOS 14.0+, Swift 6.0
