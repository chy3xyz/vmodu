module main
import vmodu.infra.db.sql as dbsql
fn main() {
	_ = dbsql.Config{}
	println('sql ok')
}
