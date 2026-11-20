// polish_actor.v

module main

import vmodu.runtime
import time

// PolishMsg 打磨消息结构
pub struct PolishMsg {
	runtime.BaseMessage
	idea_id string
	content string
}

// PolishActor AI打磨Actor
@[heap]
pub struct PolishActor {
pub:
	id string
mut:
	actor     &runtime.Actor
	service   &IdeaService
}

pub fn new_polish_actor(id string, service &IdeaService) &PolishActor {
	mut actor := runtime.new_actor(runtime.ActorConfig{
		id:           id
		mailbox_size: 50
	})
	
	return &PolishActor{
		id:      id
		actor:   actor
		service: service
	}
}

pub fn (mut p PolishActor) start() {
	p.actor.start(fn [mut p] (msg runtime.Message) {
		// 使用类型断言
		polish_msg := msg as PolishMsg
		p.process_idea(polish_msg.idea_id, polish_msg.content)
	})
	println('[AI打磨] Actor ${p.id} 已启动')
}

fn (mut p PolishActor) process_idea(idea_id string, content string) {
	println('[AI打磨] 处理: ${idea_id}')
	time.sleep(500 * time.millisecond)
	
	p.service.update_polish_result(idea_id, 85.5, ['创新', 'AI'], '【优化版】${content}') or {
		eprintln('[AI打磨] 失败: ${err}')
		return
	}
	println('[AI打磨] 完成: ${idea_id}')
}

pub fn (mut p PolishActor) send(idea_id string, content string) {
	msg := PolishMsg{
		BaseMessage: runtime.BaseMessage{typ: 'polish'}
		idea_id:     idea_id
		content:     content
	}
	p.actor.send(msg)
}
