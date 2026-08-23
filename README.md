
<div align="center">
<a href="https://techpie.geekpie.club">
<img src="./assets/logo/Logo-1.png" alt="TechPie logo" style="border-radius:50%"/>
</a>

# TechPie

**🥧 **TechPie** 是一个由 GeekPie 开发的 **开源、轻量、美观** 的 ShanghaiTech 第三方校园服务平台！ 🚀**

</div>

> [!WARNING]
>
> 注意，由于 HarmonyOS 支持的破坏性加入，上游 Dart/flutter 版本需要回退，部分特性无法使用。相关 SDK 需要降级。

## Support Platform

仓库保留以下平台宿主；其中 Web 目前仅保留 Flutter 脚手架，尚未纳入正式支持与验证范围：

- [x] Linux
- [x] Windows
- [x] macOS
- [x] Android
- [ ] Web（脚手架）
- [x] HarmonyOS NEXT

## Roadmap

- UI
  - [x] Schedule
  - [x] Login
  - [ ] Assignment
  - [ ] Homepage
  - [ ] HarmonyOS NEXT
    - [ ] Native Card
    - [ ] Realtime Window
  - [ ] Android (Including other customized OS)
    - [ ] Soooo many...
- API
  - [x] GeekPie SSO (Casdoor) login + token refresh
  - [x] eGate binding / CpDaily keep-alive (via /api/auth/renew)
  - [ ] Schedule
  - [ ] Homework / Resources
    - [ ] GradeScope
    - [ ] elearning
    - [ ] Piazza
    - [ ] ACM OJ
- Feature
  - [x] Auto renew token
  - [x] Auto refresh schedule
  - [ ] Auto deadline fetch / jump
  - [ ] Piazza Forum
  - [ ] CourseBench Integration

## Development

Android、Linux、macOS、Windows 和 Web 使用上游 Flutter SDK；HarmonyOS NEXT 使用 OHOS Flutter fork。以下环境变量用于国内镜像与 HarmonyOS 工具链：

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export FLUTTER_OHOS_STORAGE_BASE_URL=https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export HOS_SDK_HOME="$HOME/dev/command-line-tools/sdk"
```

### Android

- Aliyun mirror
- JDK 17
- Android NDK 28
- Android SDK 35

### HarmonyOS

- Flutter (OHOS patch) 3.27.5-ohos-1.0.5
- [Huawei Command Tools  6.1.1 Beta1](https://developer.huawei.com/consumer/cn/download/command-line-tools-for-hmos)

## License

MIT
