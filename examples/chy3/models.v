// models/idea.v - Data Models

module main

// IdeaStatus 创意状态
pub enum IdeaStatus {
	pending
	processing
	completed
	failed
}

// Idea 创意结构
pub struct Idea {
pub mut:
	id               string
	title            string
	content          string
	author           string
	status           IdeaStatus
	created_at       i64
	score            f64
	tags             []string
	polished_content string
}

// IdeaStats 统计信息
pub struct IdeaStats {
pub:
	total     int
	completed int
	avg_score f64
}
