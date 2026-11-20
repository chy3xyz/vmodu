// search.v - Search Engine Integration for VModulith
// Supports: Elasticsearch, MeiliSearch, or in-memory search

module search

import net.http
import json2
import time

// Search engine types
pub enum EngineType {
	elasticsearch
	meilisearch
	memory // In-memory for testing/development
}

// Config for search engine
pub struct Config {
pub:
	engine_type  EngineType = .memory
	host         string     = 'localhost'
	port         int        = 9200
	api_key      string
	index_prefix string = 'vmodu'
}

// Client for search operations
pub struct Client {
pub:
	config Config
pub mut:
	memory_index map[string][]Document // For in-memory engine
}

// new_client creates a new search client
pub fn new_client(config Config) &Client {
	return &Client{
		config:       config
		memory_index: {}
	}
}

// Document represents a searchable document
pub struct Document {
pub:
	id       string
	index    string
	content  string
	title    string
	tags     []string
	metadata map[string]string
	score    f64
}

// SearchQuery represents a search query
pub struct SearchQuery {
pub:
	query     string
	index     string
	filters   []Filter
	sort      []Sort
	page      int  = 1
	per_page  int  = 20
	highlight bool = true
}

// Filter for search results
pub struct Filter {
pub:
	field    string
	operator string // eq, neq, gt, gte, lt, lte, in, contains
	value    string
}

// Sort configuration
pub struct Sort {
pub:
	field     string
	direction string = 'asc' // asc, desc
}

// SearchResult contains search results
pub struct SearchResult {
pub:
	total       int
	page        int
	per_page    int
	documents   []Document
	took_ms     int
	suggestions []string
}

// IndexRequest for bulk indexing
pub struct IndexRequest {
pub:
	index     string
	documents []Document
}

// create_index creates a search index
pub fn (c &Client) create_index(name string, schema IndexSchema) ! {
	full_name := '${c.config.index_prefix}_${name}'

	match c.config.engine_type {
		.elasticsearch {
			return c.create_es_index(full_name, schema)
		}
		.meilisearch {
			return c.create_meili_index(full_name, schema)
		}
		.memory {
			c.memory_index[full_name] = []
			return
		}
	}
}

// delete_index deletes a search index
pub fn (c &Client) delete_index(name string) ! {
	full_name := '${c.config.index_prefix}_${name}'

	match c.config.engine_type {
		.elasticsearch {
			url := c.build_url('/${full_name}')
			mut req := http.new_request(.delete, url, '')
			resp := req.do()!

			if resp.status_code != 200 {
				return error('failed to delete index: ${resp.body}')
			}
		}
		.meilisearch {
			// MeiliSearch implementation
		}
		.memory {
			c.memory_index.delete(full_name)
		}
	}
}

// index_document indexes a single document
pub fn (c &Client) index_document(doc Document) ! {
	full_index := '${c.config.index_prefix}_${doc.index}'

	match c.config.engine_type {
		.elasticsearch {
			url := c.build_url('/${full_index}/_doc/${doc.id}')
			body := json2.encode(doc, escape_unicode: true, time_as_unix: true)

			mut req := http.new_request(.put, url, body)
			req.add_header(.content_type, 'application/json')

			resp := req.do()!
			if resp.status_code != 200 && resp.status_code != 201 {
				return error('failed to index document: ${resp.body}')
			}
		}
		.meilisearch {
			// MeiliSearch implementation
		}
		.memory {
			if full_index !in c.memory_index {
				c.memory_index[full_index] = []
			}

			// Remove existing document with same ID
			mut docs := c.memory_index[full_index]
			mut i := 0
			for i < docs.len {
				if docs[i].id == doc.id {
					docs.delete(i)
					break
				}
				i++
			}

			docs << doc
			c.memory_index[full_index] = docs
		}
	}
}

// bulk_index indexes multiple documents
pub fn (c &Client) bulk_index(req IndexRequest) ! {
	for doc in req.documents {
		c.index_document(doc)!
	}
}

// search performs a search query
pub fn (c &Client) search(query SearchQuery) !SearchResult {
	match c.config.engine_type {
		.elasticsearch {
			return c.search_elasticsearch(query)
		}
		.meilisearch {
			return c.search_meilisearch(query)
		}
		.memory {
			return c.search_memory(query)
		}
	}
}

// delete_document deletes a document
pub fn (c &Client) delete_document(index string, id string) ! {
	full_index := '${c.config.index_prefix}_${index}'

	match c.config.engine_type {
		.elasticsearch {
			url := c.build_url('/${full_index}/_doc/${id}')
			mut req := http.new_request(.delete, url, '')
			req.do()!
		}
		.meilisearch {
			// MeiliSearch implementation
		}
		.memory {
			if full_index in c.memory_index {
				mut docs := c.memory_index[full_index]
				mut i := 0
				for i < docs.len {
					if docs[i].id == id {
						docs.delete(i)
						break
					}
					i++
				}
				c.memory_index[full_index] = docs
			}
		}
	}
}

// Elasticsearch implementation
fn (c &Client) create_es_index(name string, schema IndexSchema) ! {
	url := c.build_url('/${name}')
	body := json2.encode(schema, escape_unicode: true, time_as_unix: true)

	mut req := http.new_request(.put, url, body)
	req.add_header(.content_type, 'application/json')

	resp := req.do()!
	if resp.status_code != 200 {
		return error('failed to create index: ${resp.body}')
	}
}

fn (c &Client) search_elasticsearch(query SearchQuery) !SearchResult {
	full_index := '${c.config.index_prefix}_${query.index}'
	url := c.build_url('/${full_index}/_search')

	// Build ES query
	mut es_query := {
		'from':  (query.page - 1) * query.per_page
		'size':  query.per_page
		'query': {
			'multi_match': {
				'query':  query.query
				'fields': ['title^3', 'content', 'tags^2']
			}
		}
	}

	if query.highlight {
		es_query['highlight'] = {
			'fields': {
				'title':   {}
				'content': {
					'fragment_size': 150
				}
			}
		}
	}

	body := json2.encode(es_query, escape_unicode: true, time_as_unix: true)

	mut req := http.new_request(.post, url, body)
	req.add_header(.content_type, 'application/json')

	start := time.now()
	resp := req.do()!
	elapsed := time.now() - start

	if resp.status_code != 200 {
		return error('search failed: ${resp.body}')
	}

	// Parse response
	return c.parse_es_response(resp.body, query)
}

fn (c &Client) parse_es_response(body string, query SearchQuery) SearchResult {
	// Simplified parsing
	// In production, use proper JSON parsing
	return SearchResult{
		total:     0
		page:      query.page
		per_page:  query.per_page
		documents: []
		took_ms:   0
	}
}

// MeiliSearch implementation
fn (c &Client) create_meili_index(name string, schema IndexSchema) ! {
	url := 'http://${c.config.host}:${c.config.port}/indexes'
	body := json2.encode({
		'uid': name
	}, escape_unicode: true, time_as_unix: true)

	mut req := http.new_request(.post, url, body)
	req.add_header(.content_type, 'application/json')
	req.add_header(.authorization, 'Bearer ${c.config.api_key}')

	req.do()!
}

fn (c &Client) search_meilisearch(query SearchQuery) !SearchResult {
	full_index := '${c.config.index_prefix}_${query.index}'
	url := 'http://${c.config.host}:${c.config.port}/indexes/${full_index}/search'

	body := json2.encode({
		'q':                     query.query
		'offset':                (query.page - 1) * query.per_page
		'limit':                 query.per_page
		'attributesToHighlight': ['title', 'content']
	}, escape_unicode: true, time_as_unix: true)

	mut req := http.new_request(.post, url, body)
	req.add_header(.content_type, 'application/json')
	req.add_header(.authorization, 'Bearer ${c.config.api_key}')

	resp := req.do()!

	// Parse response
	return SearchResult{
		total:     0
		page:      query.page
		per_page:  query.per_page
		documents: []
		took_ms:   0
	}
}

// In-memory implementation
fn (c &Client) search_memory(query SearchQuery) !SearchResult {
	full_index := '${c.config.index_prefix}_${query.index}'

	docs := c.memory_index[full_index] or { return SearchResult{} }

	// Simple text search
	mut results := []Document{}
	search_terms := query.query.to_lower().split(' ')

	for doc in docs {
		mut score := 0.0
		content_lower := doc.content.to_lower()
		title_lower := doc.title.to_lower()

		for term in search_terms {
			if title_lower.contains(term) {
				score += 3.0 // Title match is more valuable
			}
			if content_lower.contains(term) {
				score += 1.0
			}
		}

		if score > 0 {
			mut scored_doc := doc
			scored_doc.score = score
			results << scored_doc
		}
	}

	// Sort by score
	results.sort(a.score > b.score)

	// Pagination
	total := results.len
	start := (query.page - 1) * query.per_page
	end := start + query.per_page

	if start >= total {
		return SearchResult{
			total:     total
			page:      query.page
			per_page:  query.per_page
			documents: []
			took_ms:   0
		}
	}

	if end > total {
		end = total
	}

	return SearchResult{
		total:     total
		page:      query.page
		per_page:  query.per_page
		documents: results[start..end]
		took_ms:   0
	}
}

// Helper functions

fn (c &Client) build_url(path string) string {
	return 'http://${c.config.host}:${c.config.port}${path}'
}

// IndexSchema defines index structure
pub struct IndexSchema {
pub:
	settings map[string]FieldMapping
}

// FieldMapping defines field type
pub struct FieldMapping {
pub:
	field_type string // text, keyword, integer, float, date, boolean
	analyzer   string
	index      bool = true
	store      bool = true
}

// E-commerce product search helpers

// ProductDocument for product indexing
pub struct ProductDocument {
pub:
	id          string
	name        string
	description string
	category    string
	tags        []string
	price       f64
	currency    string
	in_stock    bool
	images      []string
	attributes  map[string]string
}

// to_document converts ProductDocument to Document
pub fn (p &ProductDocument) to_document() Document {
	return Document{
		id:       p.id
		index:    'products'
		content:  p.description
		title:    p.name
		tags:     p.tags
		metadata: {
			'category': p.category
			'price':    '${p.price}'
			'currency': p.currency
			'in_stock': if p.in_stock { 'true' } else { 'false' }
		}
	}
}

// SearchBuilder helps build complex queries
pub struct SearchBuilder {
pub mut:
	query SearchQuery
}

// new_search creates a search builder
pub fn new_search(index string) SearchBuilder {
	return SearchBuilder{
		query: SearchQuery{
			index:    index
			page:     1
			per_page: 20
		}
	}
}

// with_query sets the search query
pub fn (mut b SearchBuilder) with_query(q string) SearchBuilder {
	b.query.query = q
	return b
}

// with_filter adds a filter
pub fn (mut b SearchBuilder) with_filter(field string, operator string, value string) SearchBuilder {
	b.query.filters << Filter{
		field:    field
		operator: operator
		value:    value
	}
	return b
}

// with_sort adds sort
pub fn (mut b SearchBuilder) with_sort(field string, direction string) SearchBuilder {
	b.query.sort << Sort{
		field:     field
		direction: direction
	}
	return b
}

// with_pagination sets pagination
pub fn (mut b SearchBuilder) with_pagination(page int, per_page int) SearchBuilder {
	b.query.page = page
	b.query.per_page = per_page
	return b
}

// build returns the search query
pub fn (b &SearchBuilder) build() SearchQuery {
	return b.query
}

// Faceted search for e-commerce
pub struct FacetResult {
pub:
	field   string
	buckets []FacetBucket
}

pub struct FacetBucket {
pub:
	value string
	count int
}

// ProductSearchService provides product search
pub struct ProductSearchService {
pub:
	client &Client
}

// search_products searches products with filters
pub fn (s &ProductSearchService) search_products(
	query string,
	category string,
	min_price f64,
	max_price f64,
	in_stock_only bool,
	page int
) !SearchResult {
	mut builder := new_search('products').with_query(query)

	if category != '' {
		builder = builder.with_filter('category', 'eq', category)
	}

	if min_price > 0 {
		builder = builder.with_filter('price', 'gte', '${min_price}')
	}

	if max_price > 0 {
		builder = builder.with_filter('price', 'lte', '${max_price}')
	}

	if in_stock_only {
		builder = builder.with_filter('in_stock', 'eq', 'true')
	}

	builder = builder.with_pagination(page, 20)

	return s.client.search(builder.build())
}

// get_suggestions gets search suggestions
pub fn (s &ProductSearchService) get_suggestions(prefix string) []string {
	// Simplified implementation
	return []
}
