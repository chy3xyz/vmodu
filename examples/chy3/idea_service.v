// services/idea_service.v

module main

import vmodu.event.bus
import time

// IdeaService 创意服务
@[heap]
pub struct IdeaService {
pub mut:
	ideas     map[string]Idea
	event_bus &bus.EventBus
}

pub fn new_idea_service() &IdeaService {
	return &IdeaService{
		ideas:     {}
		event_bus: bus.default()
	}
}

pub fn (mut s IdeaService) init(event_bus &bus.EventBus) ! {
	s.event_bus = event_bus
	println('[IdeaService] 初始化完成')
}

pub fn (mut s IdeaService) start() ! {
	println('[IdeaService] 已启动')
}

pub fn (mut s IdeaService) stop() ! {
	println('[IdeaService] 已停止')
}

pub fn (mut s IdeaService) submit_idea(title string, content string, author string) !Idea {
	idea := Idea{
		id:         'idea_${time.now().unix_milli()}'
		title:      title
		content:    content
		author:     author
		status:     .pending
		created_at: time.now().unix_milli()
	}
	s.ideas[idea.id] = idea
	
	event_data := '${idea.id}|${title}'
	s.event_bus.publish('idea.created', event_data.bytes())!
	
	println('[创意提交] ${title}')
	return idea
}

pub fn (mut s IdeaService) update_polish_result(idea_id string, score f64, tags []string, polished string) ! {
	if idea_id !in s.ideas {
		return error('创意不存在')
	}
	mut idea := s.ideas[idea_id]
	idea.status = .completed
	idea.score = score
	idea.tags = tags.clone()
	idea.polished_content = polished
	s.ideas[idea_id] = idea
}

pub fn (s &IdeaService) get_all_ideas() []Idea {
	mut list := []Idea{cap: s.ideas.len}
	for _, idea in s.ideas {
		list << idea
	}
	return list
}

pub fn (s &IdeaService) get_stats() IdeaStats {
	mut completed := 0
	mut total_score := f64(0)
	
	for _, idea in s.ideas {
		if idea.status == .completed {
			completed++
			total_score += idea.score
		}
	}
	
	avg := if completed > 0 { total_score / completed } else { f64(0) }
	
	return IdeaStats{
		total:     s.ideas.len
		completed: completed
		avg_score: avg
	}
}
