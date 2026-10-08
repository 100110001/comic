# 实现记录

## U1

- 未使用两维 ResizeImage.exact：它会改变原比例；fit 再 cover 或单宽度方案会让部分封面裁切后放大模糊。公共 provider 在解码回调获取原图宽高后计算 cover/contain/fitWidth 的保比例目标。
- 缓存 key 使用 NetworkImage 原始 key、物理显示尺寸档位与 BoxFit，URL 来源和版本不变；超过 4096 档回退原图。组件取实际受约束尺寸，避免显式宽高超过父约束时过度解码。
- 自审：包装后的解码失败必须清包装 key，源 NetworkImage 自身错误清理只认识源 key；已经增加包装 key 清理。图片 provider 按源、尺寸与 fit 比较相等。
- 真实图片测试：800×400 封面在 128×128 cover 中解码为 256×128，contain 为 128×64；256×2560 长条页按宽 128 解码为 128×1280，32×16 小图不放大。
- flutter analyze 无问题，flutter test 56 项通过。封面入口均已替换，原比例、主题、错误占位及布局保留。
