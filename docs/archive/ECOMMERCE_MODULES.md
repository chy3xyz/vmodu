# VModulith 商城开发模块指南

**版本**: 3.3.0  
**日期**: 2026-03-10

---

## 概述

本文档列出了使用 VModulith Runtime 开发商城应用时需要的核心模块。所有模块尽可能复用 V 语言官方库。

---

## 模块清单

### ✅ 已完成模块

| 模块 | 路径 | 依赖的 V 标准库 | 功能 |
|------|------|-----------------|------|
| **数据库 ORM** | `infra/db/sql/` | `db.sqlite`, `db.mysql`, `db.pg` | 连接池、ORM、CRUD |
| **Redis 缓存** | `infra/cache/` | `net`, `encoding` | 缓存、分布式锁、限流 |
| **认证授权** | `infra/auth/` | `crypto.hmac`, `encoding.base64` | JWT、RBAC、Session |
| **对象存储** | `infra/storage/` | `net.http`, `crypto.hmac` | S3/OSS/MinIO 上传下载 |
| **支付网关** | `infra/payment/` | `net.http`, `crypto.hmac` | 支付宝/微信/Stripe/PayPal |
| **搜索引擎** | `infra/search/` | `net.http`, `json` | Elasticsearch/MeiliSearch |
| **消息队列** | `infra/mq/` | `net`, `sync` | RabbitMQ/Kafka/内存队列 |
| **任务调度** | `infra/scheduler/` | `time`, `sync` | Cron、延迟任务、订单超时 |
| **数据验证** | `infra/validator/` | `regex`, `strconv` | 输入校验、DTO 转换 |
| **模板引擎** | `infra/template/` | `strings` | 邮件、短信模板 |

---

## 使用示例

### 1. 数据库操作

```v
import vmodu.infra.db.sql

// 创建连接池
mut pool := sql.new_pool(sql.Config{
    db_type:  .postgresql
    host:     'localhost'
    port:     5432
    username: 'shop'
    password: 'secret'
    database: 'ecommerce'
})!

// 定义模型
pub struct Product {
    id          string
    name        string
    price       f64
    stock       int
}

pub fn (p Product) table_name() string { return 'products' }
pub fn (p Product) primary_key() string { return 'id' }

// CRUD 操作
mut repo := sql.new_repository<Product>(pool)

// 创建
repo.save(Product{
    id:    'P001'
    name:  'iPhone 15'
    price: 999.99
    stock: 100
})!

// 查询
product := repo.find_by_id('P001')!
products := repo.find_all()!
```

### 2. Redis 缓存

```v
import vmodu.infra.cache

// 创建客户端
mut redis := cache.new_redis_client(cache.RedisConfig{
    host: 'localhost'
    port: 6379
})!

// 基础操作
redis.set('product:1', json.encode(product), 3600)!  // 缓存1小时
cached := redis.get('product:1')!
redis.del('product:1')!

// 分布式锁
mut lock := cache.new_lock(redis, 'order_lock', 30)
if lock.acquire()! {
    defer { lock.release()! }
    // 处理订单
}

// 限流
mut limiter := cache.new_rate_limiter(redis, 'api', 100, 60)  // 100请求/分钟
if limiter.check('user_123')! {
    // 允许请求
} else {
    // 拒绝请求
}
```

### 3. 认证授权

```v
import vmodu.infra.auth

// JWT 管理
mut jwt := auth.new_jwt_manager(auth.JWTConfig{
    secret:     'your-secret-key'
    issuer:     'shop.example.com'
    access_ttl: 3600
})

// 生成令牌
token := jwt.generate('user_123', ['customer'], ['order:create'])!

// 验证令牌
payload := jwt.verify(token)!
println(payload.sub)      // user_123
println(payload.roles)    // ['customer']

// RBAC 权限检查
mut rbac := auth.setup_ecommerce_roles()
if rbac.check(['customer'], 'order:create') {
    // 允许创建订单
}
```

### 4. 对象存储

```v
import vmodu.infra.storage

// 创建客户端
mut oss := storage.new_client(storage.Config{
    storage_type: .minio
    endpoint:     'localhost:9000'
    access_key:   'minioadmin'
    secret_key:   'minioadmin'
    bucket:       'shop-images'
})

// 上传文件
result := oss.upload_file(
    key:       'products/iphone15.jpg'
    file_path: '/tmp/iphone15.jpg'
    options:   storage.UploadOptions{
        content_type: 'image/jpeg'
        acl:          'public-read'
    }
)!

// 生成访问 URL
url := oss.generate_presigned_url('products/iphone15.jpg', 3600)
```

### 5. 支付集成

```v
import vmodu.infra.payment

// 支付宝
mut alipay := payment.new_client(payment.Config{
    provider:   .alipay
    app_id:     'your-app-id'
    app_secret: 'your-secret'
    notify_url: 'https://shop.com/notify'
    return_url: 'https://shop.com/return'
})

// 创建支付
result := alipay.create_payment(payment.Order{
    order_id: 'ORDER202403100001'
    amount:   999.99
    subject:  'iPhone 15'
    body:     'iPhone 15 128GB 黑色'
})!

// 跳转到支付页面
redirect(result.pay_url)

// 查询支付状态
status := alipay.query_payment('ORDER202403100001')!

// 退款
refund := alipay.refund('ORDER202403100001', 999.99, '用户申请退款')!
```

### 6. 商品搜索

```v
import vmodu.infra.search

// 创建搜索客户端
mut client := search.new_client(search.Config{
    engine_type: .memory  // 或 .elasticsearch
})

// 索引商品
doc := search.ProductDocument{
    id:          'P001'
    name:        'iPhone 15'
    description: '最新款 iPhone，搭载 A17 芯片'
    category:    '手机'
    tags:        ['苹果', 'iPhone', '5G']
    price:       999.99
    in_stock:    true
}
client.index_document(doc.to_document())!

// 搜索商品
mut service := search.ProductSearchService{client: client}
results := service.search_products(
    query:         'iPhone'
    category:      '手机'
    min_price:     500.0
    max_price:     1500.0
    in_stock_only: true
    page:          1
)!

for doc in results.documents {
    println('${doc.title}: $${doc.metadata['price']}')
}
```

### 7. 消息队列

```v
import vmodu.infra.mq

// 创建队列
mut queue := mq.new_in_memory_queue(1000)
queue.start()

// 发布消息
order_msg := mq.OrderCreatedMessage{
    order_id:    'ORDER001'
    customer_id: 'CUST001'
    amount:      999.99
    items:       [
        mq.OrderItem{product_id: 'P001', name: 'iPhone', quantity: 1, price: 999.99}
    ]
}
queue.publish('order.created', order_msg.to_message())!

// 订阅消息
mut processor := mq.new_processor(queue)
processor.register_handler('order.created', fn (msg mq.Message) ! {
    mut order := mq.OrderCreatedMessage{}
    json.decode(msg.payload, mut order)!
    
    println('新订单: ${order.order_id}, 金额: ${order.amount}')
    // 发送邮件、扣减库存...
})
processor.start()
```

### 8. 任务调度

```v
import vmodu.infra.scheduler

// 创建调度器
mut sched := scheduler.new_scheduler()

// 每小时同步库存
sched.add_job(scheduler.every_hour('库存同步', fn () ! {
    println('同步库存...')
    // 调用库存同步 API
}))

// 每天凌晨1点生成报表
sched.add_job(scheduler.every_day('日报生成', 1, 0, fn () ! {
    println('生成日报...')
}))

// 订单30分钟未支付自动取消
fn create_order_timeout_job(order_id string) {
    sched.add_job(scheduler.create_order_timeout(order_id, 30))
}

sched.start()
```

### 9. 数据验证

```v
import vmodu.infra.validator

// 验证商品信息
mut v := validator.ProductValidator{}
result := v.validate_product(
    name:  'iPhone 15'
    price: 999.99
    sku:   'IP15-128-BLK'
    stock: 100
)

if !result.valid {
    for field, errors in result.errors {
        println('${field}: ${errors}')
    }
}

// 验证邮箱
validator.email('user@example.com', 'email')!

// 验证手机号
validator.phone('13800138000', 'phone')!

// 验证价格
validator.price(999.99, 'price')!
```

### 10. 模板引擎

```v
import vmodu.infra.template

// 创建邮件模板
mut emails := template.new_email_templates()
emails.load_default_templates()

// 设置全局变量
emails.engine.set_global('shop_name', '我的商城')
emails.engine.set_global('shop_url', 'https://shop.example.com')

// 渲染订单确认邮件
html := emails.engine.render('order_confirmation', {
    'customer_name':  '张三'
    'order_number':   'ORDER001'
    'order_total':    '999.99'
    'order_status':   '已支付'
    'tracking_url':   'https://...'
})!

// 发送短信
mut sms := template.new_sms_templates()
message := sms.render('order_confirmation', {
    'customer_name': '张三'
    'order_number':  'ORDER001'
    'order_total':   '999.99'
    'tracking_url':  'https://...'
})!
```

---

## 商城业务模块建议

基于上述基础设施，建议实现以下业务模块：

### 核心模块

```
modules/
├── user/           # 用户管理
├── product/        # 商品管理
├── cart/           # 购物车
├── order/          # 订单系统
├── payment/        # 支付处理
├── inventory/      # 库存管理
├── shipping/       # 物流管理
├── coupon/         # 优惠券
├── review/         # 评价系统
└── notification/   # 消息通知
```

### 数据流示例

```
用户下单流程:
1. CartModule.submit() 
   → validator.validate_order()
   → cache.lock() 分布式锁
   
2. OrderModule.create()
   → db.transaction() 开启事务
   → inventory.check() 检查库存
   → order.save() 保存订单
   → mq.publish('order.created')
   → cache.unlock()
   
3. PaymentModule.create()
   → payment.create_payment() 调用支付网关
   → scheduler.once() 30分钟超时任务
   
4. Payment Callback
   → payment.verify() 验签
   → order.update_status('paid')
   → inventory.deduct() 扣减库存
   → mq.publish('payment.completed')
   → scheduler.cancel() 取消超时任务
   
5. NotificationModule
   → mq.subscribe('payment.completed')
   → template.render('order_confirmation')
   → email.send() / sms.send()
```

---

## 性能优化建议

### 1. 缓存策略

| 数据类型 | 缓存时长 | 更新策略 |
|---------|---------|---------|
| 商品详情 | 1小时 | 写后删除 |
| 商品列表 | 10分钟 | 定时刷新 |
| 用户信息 | 30分钟 | 更新时失效 |
| 购物车 | 永久 | 实时同步 |
| 订单状态 | 5分钟 | 主动更新 |

### 2. 数据库优化

```sql
-- 商品表索引
CREATE INDEX idx_product_category ON products(category);
CREATE INDEX idx_product_price ON products(price);
CREATE INDEX idx_product_status ON products(status);

-- 订单表索引
CREATE INDEX idx_order_user ON orders(user_id, created_at);
CREATE INDEX idx_order_status ON orders(status, created_at);
```

### 3. 限流配置

```v
// API 限流
mut api_limiter := cache.new_rate_limiter(redis, 'api', 1000, 60)

// 登录限流
mut login_limiter := cache.new_rate_limiter(redis, 'login', 5, 60)

// 支付限流
mut pay_limiter := cache.new_rate_limiter(redis, 'pay', 10, 60)
```

---

## 部署架构

```
┌─────────────────────────────────────────────┐
│                 Load Balancer               │
└──────────────────┬──────────────────────────┘
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ VModulith    │ │ VModulith    │ │ VModulith    │
│ Node 1   │ │ Node 2   │ │ Node 3   │
│          │ │          │ │          │
│ HTTP:8080│ │ HTTP:8080│ │ HTTP:8080│
└────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │
     └────────────┼────────────┘
                  │
       ┌──────────┼──────────┐
       ▼          ▼          ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│PostgreSQL│ │  Redis   │ │Elasticsearch│
│  Primary │ │ Cluster  │ │   Node   │
└──────────┘ └──────────┘ └──────────┘
```

---

## 总结

VModulith Runtime 提供了完整的基础设施支持商城开发：

- ✅ 数据库 ORM 支持 SQLite/MySQL/PostgreSQL
- ✅ Redis 缓存支持分布式锁和限流
- ✅ JWT + RBAC 认证授权
- ✅ 多支付渠道支持（支付宝/微信/Stripe/PayPal）
- ✅ 对象存储支持（S3/OSS/MinIO）
- ✅ 搜索引擎支持（Elasticsearch/MeiliSearch）
- ✅ 消息队列支持（RabbitMQ/Kafka/内存）
- ✅ 任务调度支持 Cron 和延迟任务
- ✅ 数据验证和模板引擎

所有模块均复用 V 语言标准库，无需额外依赖！
