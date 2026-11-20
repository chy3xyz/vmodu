// main.v - Chy3 Multi-file Example

module main

import vmodu.core { new_container }
import time

fn main() {
	println('╔════════════════════════════════════════════════════════════╗')
	println('║      Chy3 - 创意分享与 AI 打磨系统                         ║')
	println('║      Multi-file Edition                                    ║')
	println('╚════════════════════════════════════════════════════════════╝')
	println('')
	
	// 创建容器
	mut container := new_container()
	
	// 创建服务
	mut service := new_idea_service()
	mut actor := new_polish_actor('ai-1', service)
	
	container.register('service', service)!
	
	// 启动
	container.start()!
	actor.start()
	
	println('[系统] 系统已启动')
	println('')
	
	// 提交创意
	idea1 := service.submit_idea('AI 智能园丁', '自动识别植物病害的AI应用', '张三')!
	idea2 := service.submit_idea('社区共享工具箱', '邻里共享工具的平台', '李四')!
	idea3 := service.submit_idea('老年人数字助手', '简化版智能手机界面', '王五')!
	
	// 发送给Actor处理
	actor.send(idea1.id, idea1.content)
	actor.send(idea2.id, idea2.content)
	actor.send(idea3.id, idea3.content)
	
	println('─────────────────────────────────────────────────────────────')
	println('[系统] 等待 AI 打磨完成...')
	println('')
	
	time.sleep(2 * time.second)
	
	// 显示结果
	print_results(service)
	
	println('═════════════════════════════════════════════════════════════')
	println('[系统] 演示结束')
	println('═════════════════════════════════════════════════════════════')
	
	container.stop()!
}

fn print_results(service &IdeaService) {
	ideas := service.get_all_ideas()
	stats := service.get_stats()
	
	println('═════════════════════════════════════════════════════════════')
	println('                        创意列表                             ')
	println('═════════════════════════════════════════════════════════════')
	
	for idea in ideas {
		println('')
		println('📌 ${idea.title} by ${idea.author}')
		println('   状态: ${idea.status}')
		if idea.status == .completed {
			println('   评分: ${idea.score} ⭐')
			println('   标签: ${idea.tags}')
		}
	}
	
	println('')
	println('═════════════════════════════════════════════════════════════')
	println('                        统计数据                             ')
	println('═════════════════════════════════════════════════════════════')
	println('总创意: ${stats.total}, 已完成: ${stats.completed}, 平均分: ${stats.avg_score}')
	println('')
}
