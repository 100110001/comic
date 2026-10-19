# 实现记录

- U1 已实现：Gradle 固定 release 签名，CI 校验 Secrets、恢复临时密钥、始终清理；debug 保留默认签名。
- 已生成唯一发布密钥并配置四个 GitHub Secrets。备份在忽略目录 .android-signing/，禁止提交或随工作区归档丢弃，须交由用户独立备份。
- 主目录已撤回本次修改；后续仅在独立工作区进行。
- 五项检查通过：格式、分析、Flutter 150 项、后端 lint、后端 37 项测试。
- 自审：无业务接口和应用标识变化，无旧包迁移；凭据仅由环境变量传递，构建输出不包含密码。README 只追加签名入口，未搬入其他分支内容。
- GitHub 登录在沙箱内显示失效，授权环境中确认有效，已可操作 Secrets。
- 安卓构建正在等待 SDK Platform 35 安装，尚未验证真实签名 APK。
- SDK 安装已完成；不提供签名变量时 assembleRelease 按预期失败，错误清晰，未生成调试签名发布包。配置固定密钥后的构建正在验证。
- 固定密钥构建 APK 成功（51.0 MB）；apksigner verify 通过，APK 证书 SHA-256 与从密钥库导出的证书一致。所有持久规则已写入 specs/project-layout.convention.md；配置说明位于 docs/android-signing.md，临时构建进度与审核过程不进入规范。
