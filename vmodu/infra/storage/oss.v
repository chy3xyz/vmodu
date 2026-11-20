// oss.v - Object Storage (S3/OSS) for VModulith
// Reuses: net.http, crypto.hmac, crypto.sha256, encoding.base64 from V standard library

module storage

import net.http
import crypto.hmac
import crypto.sha256
import encoding.base64
import time
import os
import rand

// Storage types
pub enum StorageType {
	s3       // AWS S3
	oss      // Alibaba Cloud OSS
	cos      // Tencent Cloud COS
	minio    // MinIO
}

// Config for object storage
pub struct Config {
pub:
	storage_type   StorageType = .minio
	endpoint       string
	access_key     string
	secret_key     string
	bucket         string
	region         string = 'us-east-1'
	use_ssl        bool = true
}

// Client for object storage
@[heap]
pub struct Client {
pub:
	config Config
}

// new_client creates a new storage client
pub fn new_client(config Config) Client {
	return Client{config: config}
}

// UploadOptions for upload configuration
pub struct UploadOptions {
pub mut:
	content_type   string = 'application/octet-stream'
	acl            string = 'private'  // private, public-read
	metadata       map[string]string
	expires        ?i64  // Unix timestamp for pre-signed URL
}

// UploadResult contains upload information
pub struct UploadResult {
pub:
	url          string
	key          string
	etag         string
	size         i64
	content_type string
}

// upload uploads a file to object storage
pub fn (c &Client) upload(key string, data []u8, options UploadOptions) !UploadResult {
	// Build request URL
	url := c.build_url(key)
	
	// Build headers
	mut headers := http.new_header()
	headers.add(.content_type, options.content_type)
	
	// Calculate signature
	signature := c.calculate_signature('PUT', key, headers, data)
	
	// Add authorization header
	auth_header := c.build_auth_header(signature)
	headers.add_custom('Authorization', auth_header)!
	
	// Add metadata headers
	for meta_key, meta_value in options.metadata {
		headers.add_custom('x-amz-meta-${meta_key}', meta_value)!
	}
	
	// Create and send request
	mut req := http.new_request(.put, url, data.bytestr())
	req.header = headers
	
	resp := req.do()!
	
	if resp.status_code != 200 {
		return error('upload failed: ${resp.status_code} - ${resp.body}')
	}
	
	etag := resp.header.get(.etag) or { '' }
	
	return UploadResult{
		url:          url
		key:          key
		etag:         etag
		size:         data.len
		content_type: options.content_type
	}
}

// upload_file uploads a file from disk
pub fn (c &Client) upload_file(key string, file_path string, options UploadOptions) !UploadResult {
	data := os.read_bytes(file_path)!
	
	// Auto-detect content type from extension
	opts := if options.content_type == 'application/octet-stream' {
		UploadOptions{
			...options
			content_type: detect_content_type(file_path)
		}
	} else {
		options
	}
	return c.upload(key, data, opts)
}

// download downloads a file from object storage
pub fn (c &Client) download(key string) ![]u8 {
	url := c.build_url(key)
	
	// Build headers
	mut headers := http.new_header()
	signature := c.calculate_signature('GET', key, headers, [])
	auth_header := c.build_auth_header(signature)
	headers.add_custom('Authorization', auth_header)!
	
	// Create and send request
	mut req := http.new_request(.get, url, '')
	req.header = headers
	
	resp := req.do()!
	
	if resp.status_code != 200 {
		return error('download failed: ${resp.status_code}')
	}
	
	return resp.body.bytes()
}

// delete deletes a file from object storage
pub fn (c &Client) delete(key string) ! {
	url := c.build_url(key)
	
	// Build headers
	mut headers := http.new_header()
	signature := c.calculate_signature('DELETE', key, headers, [])
	auth_header := c.build_auth_header(signature)
	headers.add_custom('Authorization', auth_header)!
	
	// Create and send request
	mut req := http.new_request(.delete, url, '')
	req.header = headers
	
	resp := req.do()!
	
	if resp.status_code != 204 && resp.status_code != 200 {
		return error('delete failed: ${resp.status_code}')
	}
}

// exists checks if a file exists
pub fn (c &Client) exists(key string) !bool {
	url := c.build_url(key)
	
	// Build headers
	mut headers := http.new_header()
	signature := c.calculate_signature('HEAD', key, headers, [])
	auth_header := c.build_auth_header(signature)
	headers.add_custom('Authorization', auth_header)!
	
	// Create and send request
	mut req := http.new_request(.head, url, '')
	req.header = headers
	
	resp := req.do() or { return false }
	
	return resp.status_code == 200
}

// generate_presigned_url generates a pre-signed URL for temporary access
pub fn (c &Client) generate_presigned_url(key string, expire_seconds int) string {
	// Simplified pre-signed URL generation
	// In production, implement proper AWS signature V4
	
	now := time.now().unix()
	expires := now + expire_seconds
	
	// Build string to sign
	string_to_sign := 'GET\n\n\n${expires}\n/${c.config.bucket}/${key}'
	
	// Calculate signature
	signature := hmac.new(c.config.secret_key.bytes(), string_to_sign.bytes(), sha256.sum, sha256.block_size)
	signature_b64 := base64.url_encode(signature)
	
	// Build URL
	url := c.build_url(key)
	return '${url}?AWSAccessKeyId=${c.config.access_key}&Expires=${expires}&Signature=${signature_b64}'
}

// build_url builds the request URL
fn (c &Client) build_url(key string) string {
	protocol := if c.config.use_ssl { 'https' } else { 'http' }
	
	match c.config.storage_type {
		.s3 {
			return '${protocol}://${c.config.bucket}.s3.${c.config.region}.amazonaws.com/${key}'
		}
		.oss {
			return '${protocol}://${c.config.bucket}.${c.config.endpoint}/${key}'
		}
		.cos {
			return '${protocol}://${c.config.bucket}.cos.${c.config.region}.myqcloud.com/${key}'
		}
		.minio {
			return '${protocol}://${c.config.endpoint}/${c.config.bucket}/${key}'
		}
	}
	
	return '${protocol}://${c.config.endpoint}/${c.config.bucket}/${key}'
}

// calculate_signature calculates AWS Signature V4
fn (c &Client) calculate_signature(method string, key string, headers http.Header, data []u8) string {
	// Simplified signature calculation
	// In production, implement full AWS Signature V4
	
	now := time.now()
	date_stamp := now.custom_format('YYYYMMdd')
	timestamp := now.custom_format('YYYYMMdd') + 'T' + now.custom_format('HHmmss') + 'Z'
	
	// Create canonical request
	canonical_request := '${method}\n/${key}\n\nhost:${c.config.endpoint}\n\nhost\n${sha256.hexhash(data.bytestr())}'
	
	// Create string to sign
	scope := '${date_stamp}/${c.config.region}/s3/aws4_request'
	string_to_sign := 'AWS4-HMAC-SHA256\n${timestamp}\n${scope}\n${sha256.hexhash(canonical_request)}'
	
	// Calculate signing key
	k_date := hmac.new('AWS4${c.config.secret_key}'.bytes(), date_stamp.bytes(), sha256.sum, sha256.block_size)
	k_region := hmac.new(k_date, c.config.region.bytes(), sha256.sum, sha256.block_size)
	k_service := hmac.new(k_region, 's3'.bytes(), sha256.sum, sha256.block_size)
	k_signing := hmac.new(k_service, 'aws4_request'.bytes(), sha256.sum, sha256.block_size)
	
	// Calculate signature
	signature := hmac.new(k_signing, string_to_sign.bytes(), sha256.sum, sha256.block_size)
	
	return signature.hex()
}

// build_auth_header builds the authorization header
fn (c &Client) build_auth_header(signature string) string {
	return 'AWS ${c.config.access_key}:${signature}'
}

// detect_content_type detects MIME type from file extension
fn detect_content_type(file_path string) string {
	if file_path.ends_with('.jpg') || file_path.ends_with('.jpeg') {
		return 'image/jpeg'
	}
	if file_path.ends_with('.png') {
		return 'image/png'
	}
	if file_path.ends_with('.gif') {
		return 'image/gif'
	}
	if file_path.ends_with('.pdf') {
		return 'application/pdf'
	}
	if file_path.ends_with('.json') {
		return 'application/json'
	}
	if file_path.ends_with('.txt') {
		return 'text/plain'
	}
	if file_path.ends_with('.html') || file_path.ends_with('.htm') {
		return 'text/html'
	}
	if file_path.ends_with('.css') {
		return 'text/css'
	}
	if file_path.ends_with('.js') {
		return 'application/javascript'
	}
	return 'application/octet-stream'
}

// UploadManager manages chunked uploads
pub struct UploadManager {
pub mut:
	client      &Client
	chunk_size  i64 = 5 * 1024 * 1024  // 5MB chunks
}

// new_upload_manager creates an upload manager
pub fn new_upload_manager(client &Client) &UploadManager {
	return &UploadManager{
		client: client
	}
}

// upload_large_file uploads a large file in chunks
pub fn (mut u UploadManager) upload_large_file(key string, file_path string, options UploadOptions) !UploadResult {
	file_size := os.file_size(file_path)
	
	// If file is small, upload directly
	if file_size <= u.chunk_size {
		return u.client.upload_file(key, file_path, options)
	}
	
	// For large files, implement multipart upload
	// This is a simplified version
	data := os.read_bytes(file_path)!
	return u.client.upload(key, data, options)
}

// Image processing helpers

// ImageProcessor provides image manipulation
pub struct ImageProcessor {}

// resize_image resizes an image (placeholder)
pub fn (p &ImageProcessor) resize_image(data []u8, width int, height int) ![]u8 {
	// In production, use an image processing library
	// For now, return original
	return data
}

// generate_thumbnail generates a thumbnail (placeholder)
pub fn (p &ImageProcessor) generate_thumbnail(data []u8) ![]u8 {
	return p.resize_image(data, 200, 200)
}

// Storage utilities

// generate_key generates a unique storage key
pub fn generate_key(prefix string, filename string) string {
	timestamp := time.now().unix()
	random := rand.intn(1000000) or { 0 }
	mut extension := ''
	if dot_idx := filename.last_index('.') {
		extension = filename[dot_idx..]
	}
	
	return '${prefix}/${timestamp}_${random}${extension}'
}

// sanitize_filename sanitizes a filename for safe storage
pub fn sanitize_filename(filename string) string {
	// Remove path components
	name := filename.all_after_last('/')
	
	// Replace unsafe characters
	mut safe := name.replace('..', '_')
	safe = safe.replace('\\', '_')
	safe = safe.replace('<', '_')
	safe = safe.replace('>', '_')
	safe = safe.replace(':', '_')
	safe = safe.replace('|', '_')
	
	return safe
}
