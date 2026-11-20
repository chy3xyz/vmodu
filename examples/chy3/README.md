# Chy3 - 多文件项目示例

展示 VModulith Runtime 的多文件项目结构和最佳实践。

## 项目结构

```
chy3/
├── main.v              # 主入口文件
├── v.mod               # V 模块定义
├── README.md           # 项目说明
├── models.v            # 数据模型
├── idea_service.v      # 创意服务
├── polish_actor.v      # AI 打磨 Actor
└── tests/              # 测试目录
```

## 特点

- **模块化设计**: 代码分散在多个文件中，每个文件职责单一
- **使用 module main**: 所有文件使用相同的模块名，便于链接
- **V 标准项目结构**: 符合 V 语言的多文件项目规范

## 编译运行

```bash
# 进入项目目录
cd docs/examples/chy2

# 编译
v -enable-globals .

# 运行
./chy2
```

或直接从项目根目录运行：

```bash
v -enable-globals docs/examples/chy2
```

## 与单文件版本对比

| 特点 | chy3.v (单文件) | chy3/ (多文件) |
|------|----------------|----------------|
| 代码组织 | 全部在一个文件 | 按功能分散在多个文件 |
| 维护性 | 适合小型示例 | 适合实际项目 |
| 可读性 | 一目了然 | 需要查看多个文件 |
| 编译 | 直接运行 | 需要链接多个文件 |

## 多文件项目注意事项

1. **所有文件必须使用相同的 module 名**
   ```v
   // models.v
   module main
   
   // idea_service.v
   module main
   
   // main.v
   module main
   ```

2. **文件放在项目根目录下**
   V 编译器会自动链接同一目录下的所有 .v 文件

3. **不需要手动 import 其他文件**
   只要 module 名相同，函数和类型自动可见

4. **子目录需要特殊处理**
   如果文件放在子目录中，需要作为子模块导入或使用特殊编译参数
