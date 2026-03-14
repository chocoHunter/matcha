# Matcha Open Source Readiness TODO

更新时间：2026-03-14

## P0 - 发布前必须完成

- [x] 修复“合盖不睡（电池）”导致系统休眠配置残留的问题（见下方专项方案）
- [x] 新增 `LICENSE` 文件（README 已声明 MIT，但仓库缺少正式许可证文件）
- [x] 明确危险能力说明：在 README/README-CN 加入“会修改系统电源策略（pmset）”的风险提示和恢复说明
- [x] 清理发布流程中的本地产物策略：确认 `Build/`、`*.dmg`、`Matcha.xcodeproj` 是否应提交；若不提交，完善 `.gitignore`（当前仅忽略 `build/`，未覆盖 `Build/`）
- [x] 增加最小可验证构建说明（本机若未安装完整 Xcode，会导致 `xcodebuild` 不可用）
- [x] 对齐版本与发布记录（`project.yml`、`Info.plist`、`CHANGELOG.md`）
- [ ] 仓库切换为 Public，并补充仓库描述与 Topics
- [ ] 完成 Developer ID 签名、公证、staple 与 `spctl` 校验后再发布二进制

## P1 - 建议在首次开源后尽快补齐

- [x] 增加 CI（至少包含：`xcodegen generate`、项目可生成检查、基础静态检查）
- [ ] 为关键行为补更多测试（已覆盖 `pmset` 解析与恢复命令；仍需补电池模式状态机与 UI 交互路径）
- [x] 增加 `CONTRIBUTING.md`（开发流程、分支规范、提交流程）
- [x] 增加 `SECURITY.md`（漏洞报告渠道、处理 SLA）
- [x] 增加 Issue / PR Template，减少社区沟通成本
- [x] 增加发布文档：签名、公证、DMG 产物生成与校验步骤
- [x] 增加 `CODE_OF_CONDUCT.md`，补齐社区协作规范

## P2 - 体验与可维护性优化

- [x] 中英文术语统一（如 Resume Sleep/恢复休眠、Lid Closed/合盖不睡）
- [x] 补“故障恢复”菜单项（例如“一键恢复系统休眠设置”）
- [ ] 对管理员授权流程增加更清晰的前置说明与失败提示
- [ ] 把核心电源策略逻辑从 UI 控制器中解耦为独立组件，降低后续维护风险

---

## 电池模式恢复问题（严重）专项方案

### 当前高风险现象（代码层面）

- `enableBatterySleep()` 直接执行 `pmset -b sleep 0; pmset -b disablesleep 1`，是**持久系统配置**，不仅对当前进程生效
- `restoreBatterySleep()` 固定恢复为 `sleep 5; disablesleep 0`，会覆盖用户原本自定义电源设置
- 多条路径会停掉 `caffeinate` 但不会恢复 `pmset`：
  - 电量阈值触发自动停止（`updateBatteryDisplay` 里直接 `MatchaManager.stop()`）
  - 进程自然结束/定时结束（`handleProcessTermination`）
- 退出时恢复是异步 AppleScript 调用，应用终止与授权失败会导致恢复不可靠
- `batterySleepEnabled` 偏好状态可能与真实系统状态不一致（先改本地标志，再尝试恢复）

### 推荐修复设计（按优先级）

1. **引入“覆盖快照”机制（必须）**
- 启用前先读取当前 `pmset -b` 的关键值（至少 `sleep`、`disablesleep`）
- 成功启用后保存快照到本地（带时间戳）
- 禁用时按快照恢复，不再写死 `sleep 5`

2. **统一恢复入口（必须）**
- 所有停止路径都走同一个 `disableBatterySleepModeAndRestore()`：
  - 手动停止
  - 电量阈值自动停止
  - 定时结束/进程退出
  - 应用退出

3. **启动自愈（必须）**
- 应用启动时检测“上次是否有未清理覆盖”
- 若发现残留，优先提示并执行恢复；至少提供一键修复按钮

4. **恢复结果必须可见（必须）**
- 恢复失败时弹窗提示，不允许静默失败
- 菜单显示当前真实系统状态（而不是只看本地偏好）

5. **安全降级（建议）**
- 若不需要“电池合盖不睡”，可临时默认关闭该功能（标记为实验性）
- 或将其放入“高级设置”，减少误触

### 建议验收标准

- 连续执行以下场景后，`pmset -g custom` 中 `Battery Power` 的 `disablesleep` 与启用前一致：
  - 启用后手动停止
  - 启用后低电量自动停止
  - 启用后定时结束
  - 启用后强制退出并重启应用再恢复
- 恢复失败时用户可在 UI 看到明确失败提示与修复入口
- README 中提供“故障快速恢复命令”
